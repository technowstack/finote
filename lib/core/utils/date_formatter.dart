import 'package:intl/intl.dart';

final _indonesianDateFormatter = DateFormat('d MMMM y', 'id_ID');

String formatDate(DateTime date) => _indonesianDateFormatter.format(date);

final _shortDayFormatter = DateFormat('EEE, d MMM', 'id_ID');
final _shortDayYearFormatter = DateFormat('EEE, d MMM y', 'id_ID');

/// Group header label: "Hari ini · Min, 2 Nov", "Kemarin · Sab, 1 Nov", or
/// "Jum, 31 Okt" (with the year when it is not the current year).
String formatActivityDateLabel(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final short =
      (day.year == today.year ? _shortDayFormatter : _shortDayYearFormatter)
          .format(day);
  return switch (today.difference(day).inDays) {
    0 => 'Hari ini · $short',
    1 => 'Kemarin · $short',
    _ => short,
  };
}

/// "09.05" — 24-hour clock with the Indonesian dot separator.
String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';
