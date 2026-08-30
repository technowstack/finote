import 'package:finote/features/receipt_scanner/data/indonesian_receipt_parser.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/receipt_samples.dart';

void main() {
  final parser = IndonesianReceiptParser();

  group('Indonesian amounts and total ranking', () {
    for (final entry in {
      'TOTAL 25.000': 25000,
      'TOTAL 25,000': 25000,
      'TOTAL 25.000,00': 25000,
      'TOTAL 25,000.00': 25000,
      'TOTAL Rp25.000': 25000,
      'TOTAL Rp 25.000': 25000,
      'TOTAL IDR 25.000': 25000,
    }.entries) {
      test('parses ${entry.key}', () {
        expect(parser.parseText(entry.key).total, entry.value);
      });
    }

    test('recognizes GRAND TOTAL above TOTAL and payment noise', () {
      final result = parser.parseText('''
TOTAL 20.000
GRAND TOTAL 22.000
CASH 50.000
KEMBALIAN 28.000
''');

      expect(result.total, 22000);
    });

    test('does not confuse subtotal with final total', () {
      final result = parser.parseText('''
SUBTOTAL 20.000
Pajak 2.000
TOTAL BAYAR 22.000
''');

      expect(result.subtotal, 20000);
      expect(result.tax, 2000);
      expect(result.total, 22000);
    });

    test('returns null for conflicting equally ranked totals', () {
      expect(parser.parseText('TOTAL 20.000\nTOTAL 30.000').total, isNull);
    });

    test('returns null when no labeled total exists', () {
      expect(parser.parseText('Roti 15.000\nCASH 50.000').total, isNull);
    });

    test('handles lowercase and mixed case labels', () {
      expect(parser.parseText('gRaNd ToTaL rp 42.000').total, 42000);
      expect(parser.parseText('total belanja Rp25.000').total, 25000);
    });

    test('recognizes supported total labels', () {
      for (final label in [
        'TOTAL',
        'GRAND TOTAL',
        'TOTAL BAYAR',
        'JUMLAH',
        'AMOUNT',
        'TOTAL PAYMENT',
        'TOTAL BELANJA',
      ]) {
        expect(parser.parseText('$label 25.000').total, 25000);
      }
    });

    test('does not treat payment amount as final total', () {
      expect(parser.parseText('PAYMENT AMOUNT 50.000').total, isNull);
    });
  });

  group('dates', () {
    for (final value in [
      '30/08/2026',
      '30-08-2026',
      '30.08.2026',
      '30 Aug 2026',
      '30 Agustus 2026',
      '2026-08-30',
    ]) {
      test('parses $value', () {
        expect(parser.parseText(value).transactionDate, DateTime(2026, 8, 30));
      });
    }

    test('rejects invalid and missing dates', () {
      expect(parser.parseText('31/02/2026').transactionDate, isNull);
      expect(parser.parseText('TOTAL 25.000').transactionDate, isNull);
    });
  });

  group('merchant and synthetic receipts', () {
    test('extracts priority fields from minimarket receipt', () {
      final result = parser.parseText(minimarketReceipt);

      expect(result.merchant, 'MINIMART SEJAHTERA');
      expect(result.transactionDate, DateTime(2026, 8, 30));
      expect(result.total, 22000);
      expect(result.receiptNumber, 'MM-260830-01');
    });

    test('extracts restaurant receipt', () {
      final result = parser.parseText(restaurantReceipt);

      expect(result.merchant, 'RESTORAN RASA');
      expect(result.total, 27500);
      expect(result.tax, 2500);
    });

    test('extracts SPBU receipt through generic first-line heuristic', () {
      final result = parser.parseText(fuelReceipt);

      expect(result.merchant, 'SPBU 34.123.45');
      expect(result.transactionDate, DateTime(2026, 8, 30));
      expect(result.total, 150000);
    });

    test('normalizes noisy pharmacy heading and parses discount', () {
      final result = parser.parseText(pharmacyReceipt);

      expect(result.merchant, 'APOTEK SEHAT');
      expect(result.total, 25000);
      expect(result.discount, 5000);
    });

    test('returns null when merchant is missing', () {
      final result = parser.parseText('''
Jl. Contoh 10
30/08/2026
TOTAL Rp25.000
''');

      expect(result.merchant, isNull);
    });

    test('parses noisy OCR through ReceiptOcrResult contract', () {
      const ocr = ReceiptOcrResult(
        rawText: '''
### TOKO SERBAGUNA ###
Telp: 021 123456
NO. TRANSAKSI: TRX-99-A
30-08-2026 12:00
sub total .... Rp 24.000
TOTAL\nRp 25.000
''',
      );

      final result = parser.parse(ocr);
      expect(result.merchant, 'TOKO SERBAGUNA');
      expect(result.total, 25000);
      expect(result.transactionDate, DateTime(2026, 8, 30));
      expect(result.receiptNumber, 'TRX-99-A');
      expect(result.rawText, ocr.rawText);
      expect(result.items, isEmpty);
    });

    test('extracts multiple item lines and excludes summary/payment lines', () {
      final result = parser.parseText('''
TOKO CONTOH
ROTI TAWAR        15.000
SUSU UHT          18.000
SABUN             12.500
AIR MINERAL        5.000
SUBTOTAL          50.500
PAJAK              0
TOTAL             50.500
CASH              60.000
KEMBALIAN          9.500
''');

      expect(result.items.map((item) => (item.name, item.lineTotal)).toList(), [
        ('ROTI TAWAR', 15000),
        ('SUSU UHT', 18000),
        ('SABUN', 12500),
        ('AIR MINERAL', 5000),
      ]);
      expect(result.items.fold(0, (sum, item) => sum + item.lineTotal!), 50500);
    });
  });
}
