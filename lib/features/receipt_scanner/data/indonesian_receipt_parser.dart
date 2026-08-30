import '../domain/receipt_data.dart';
import '../domain/receipt_ocr.dart';

class IndonesianReceiptParser implements ReceiptParser {
  static final _amountPattern = RegExp(
    r'(?:Rp\.?\s*|IDR\s*)?\d+(?:[.,]\d+)*',
    caseSensitive: false,
  );
  static final _numericDatePattern = RegExp(
    r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b',
  );
  static final _isoDatePattern = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
  static final _namedDatePattern = RegExp(
    r'\b(\d{1,2})\s+(januari|jan|februari|feb|maret|mar|march|april|apr|mei|may|juni|jun|june|juli|jul|july|agustus|agu|august|aug|september|sep|oktober|okt|october|oct|november|nov|desember|des|december|dec)\s+(\d{4})\b',
    caseSensitive: false,
  );

  @override
  ReceiptData parse(ReceiptOcrResult result) => parseText(result.rawText);

  ReceiptData parseText(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return ReceiptData(
      merchant: _findMerchant(lines),
      transactionDate: _findDate(lines),
      subtotal: _findLabeledAmount(lines, RegExp(r'\bsub\s*total\b')),
      tax: _findLabeledAmount(lines, RegExp(r'\b(?:pajak|tax|ppn)\b')),
      discount: _findLabeledAmount(
        lines,
        RegExp(r'\b(?:diskon|discount|disc)\b'),
      ),
      total: _findTotal(lines),
      receiptNumber: _findReceiptNumber(lines),
      items: _findItems(lines),
      rawText: rawText,
    );
  }

  List<ReceiptItem> _findItems(List<String> lines) {
    final items = <ReceiptItem>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_containsDate(line) ||
          RegExp(
            r'\b(?:total|sub\s*total|grand|pajak|tax|ppn|diskon|discount|tunai|cash|kembalian|change|payment|bayar|jumlah|amount|receipt|nota|invoice|no(?:mor)?|telp|telepon|phone|alamat|jalan|jl)\b',
          ).hasMatch(lower)) {
        continue;
      }
      final matches = _amountPattern.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final last = matches.last;
      final name = line
          .substring(0, last.start)
          .replaceAll(RegExp(r'[.*:=-]+\s*$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (name.length < 2 ||
          !RegExp(r'[A-Za-z]{2}').hasMatch(name) ||
          RegExp(
            r'^(?:rp|idr|qty|x|pcs|liter|l|kg|/)+$',
            caseSensitive: false,
          ).hasMatch(name)) {
        continue;
      }
      final amount = _parseAmount(last.group(0)!);
      if (amount == null || amount <= 0) continue;
      items.add(
        ReceiptItem(
          name: name,
          lineTotal: amount,
          rawLine: line,
          source: ReceiptItemSource.ocr,
        ),
      );
    }
    return items;
  }

  int? _findTotal(List<String> lines) {
    final candidates = <_AmountCandidate>[];
    for (var i = 0; i < lines.length; i++) {
      final score = _totalLabelScore(lines[i]);
      if (score == null) continue;
      final sameLine = _amounts(lines[i]);
      final amounts = sameLine.isNotEmpty
          ? sameLine
          : i + 1 < lines.length
          ? _amounts(lines[i + 1])
          : const <int>[];
      for (final amount in amounts) {
        candidates.add(
          _AmountCandidate(amount, score + (sameLine.isNotEmpty ? 1 : 0)),
        );
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    if (candidates.any(
      (candidate) =>
          candidate.score == best.score && candidate.amount != best.amount,
    )) {
      return null;
    }
    return best.amount;
  }

  int? _totalLabelScore(String line) {
    final value = line.toLowerCase();
    if (RegExp(r'\bsub\s*total\b').hasMatch(value) ||
        RegExp(r'\b(?:cash|tunai|kembalian|change)\b').hasMatch(value)) {
      return null;
    }
    if (RegExp(r'\bgrand\s+total\b').hasMatch(value)) return 100;
    if (RegExp(r'\b(?:total\s+(?:bayar|payment|belanja))\b').hasMatch(value)) {
      return 95;
    }
    if (RegExp(r'\b(?:payment|bayar|dibayar|qty|item|barang)\b')
        .hasMatch(value)) {
      return null;
    }
    if (RegExp(r'\btotal\b').hasMatch(value)) return 90;
    if (RegExp(r'\b(?:jumlah|amount)\b').hasMatch(value)) return 80;
    return null;
  }

  int? _findLabeledAmount(List<String> lines, RegExp label) {
    for (var i = 0; i < lines.length; i++) {
      if (!label.hasMatch(lines[i].toLowerCase())) continue;
      final sameLine = _amounts(lines[i]);
      if (sameLine.isNotEmpty) return sameLine.last;
      if (i + 1 < lines.length) {
        final nextLine = _amounts(lines[i + 1]);
        if (nextLine.isNotEmpty) return nextLine.first;
      }
    }
    return null;
  }

  List<int> _amounts(String line) => _amountPattern
      .allMatches(line)
      .map((match) => _parseAmount(match.group(0)!))
      .whereType<int>()
      .toList(growable: false);

  int? _parseAmount(String value) {
    var amount = value
        .toUpperCase()
        .replaceFirst(RegExp(r'^(?:RP\.?|IDR)\s*'), '')
        .replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d+(?:[.,]\d+)*$').hasMatch(amount)) return null;

    final dot = amount.lastIndexOf('.');
    final comma = amount.lastIndexOf(',');
    if (dot >= 0 && comma >= 0) {
      final decimal = dot > comma ? '.' : ',';
      if (amount.length - amount.lastIndexOf(decimal) - 1 != 2) return null;
      amount = amount.substring(0, amount.lastIndexOf(decimal));
      amount = amount.replaceAll(RegExp(r'[.,]'), '');
    } else if (dot >= 0 || comma >= 0) {
      final separator = dot >= 0 ? '.' : ',';
      final parts = amount.split(separator);
      if (parts.length == 2 && parts.last.length == 2) {
        amount = parts.first;
      } else if (parts.skip(1).every((part) => part.length == 3)) {
        amount = parts.join();
      } else {
        return null;
      }
    }
    return int.tryParse(amount);
  }

  DateTime? _findDate(List<String> lines) {
    for (final line in lines) {
      final iso = _isoDatePattern.firstMatch(line);
      if (iso != null) {
        final date = _validDate(
          int.parse(iso.group(1)!),
          int.parse(iso.group(2)!),
          int.parse(iso.group(3)!),
        );
        if (date != null) return date;
      }

      final numeric = _numericDatePattern.firstMatch(line);
      if (numeric != null) {
        final date = _validDate(
          int.parse(numeric.group(3)!),
          int.parse(numeric.group(2)!),
          int.parse(numeric.group(1)!),
        );
        if (date != null) return date;
      }

      final named = _namedDatePattern.firstMatch(line);
      if (named != null) {
        final date = _validDate(
          int.parse(named.group(3)!),
          _months[named.group(2)!.toLowerCase()]!,
          int.parse(named.group(1)!),
        );
        if (date != null) return date;
      }
    }
    return null;
  }

  DateTime? _validDate(int year, int month, int day) {
    if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  String? _findMerchant(List<String> lines) {
    for (final line in lines.take(8)) {
      final normalized = line
          .replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'), '')
          .trim();
      final lower = normalized.toLowerCase();
      if (normalized.length < 3 ||
          !RegExp(r'[a-zA-Z]{2}').hasMatch(normalized) ||
          _containsDate(normalized) ||
          _amounts(normalized).isNotEmpty &&
              !RegExp(r'[a-zA-Z]')
                  .hasMatch(normalized.replaceAll(_amountPattern, '')) ||
          RegExp(
            r'\b(?:alamat|jalan|jl\.?|telp|telepon|phone|whatsapp|www\.|@|kasir|cashier|tanggal|date|waktu|time|struk|receipt|nota|invoice|transaksi|subtotal|total|jumlah|amount|pajak|tax|ppn|diskon|discount|tunai|cash|kembalian|change|terima kasih|thank you|welcome|selamat datang)\b',
          ).hasMatch(lower)) {
        continue;
      }
      return normalized;
    }
    return null;
  }

  bool _containsDate(String value) =>
      _isoDatePattern.hasMatch(value) ||
      _numericDatePattern.hasMatch(value) ||
      _namedDatePattern.hasMatch(value);

  String? _findReceiptNumber(List<String> lines) {
    final pattern = RegExp(
      r'\b(?:no(?:mor)?\.?\s*(?:struk|nota|transaksi)|receipt\s*(?:no|number|#)|invoice\s*(?:no|number|#)?|trx\s*(?:no|id))\s*[:#-]?\s*([A-Z0-9][A-Z0-9./-]{2,})',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static const _months = {
    'januari': 1,
    'jan': 1,
    'februari': 2,
    'feb': 2,
    'maret': 3,
    'mar': 3,
    'march': 3,
    'april': 4,
    'apr': 4,
    'mei': 5,
    'may': 5,
    'juni': 6,
    'jun': 6,
    'june': 6,
    'juli': 7,
    'jul': 7,
    'july': 7,
    'agustus': 8,
    'agu': 8,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sep': 9,
    'oktober': 10,
    'okt': 10,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'desember': 12,
    'des': 12,
    'december': 12,
    'dec': 12,
  };
}

class _AmountCandidate {
  const _AmountCandidate(this.amount, this.score);

  final int amount;
  final int score;
}
