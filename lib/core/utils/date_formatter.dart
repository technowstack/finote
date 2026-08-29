import 'package:intl/intl.dart';

final _indonesianDateFormatter = DateFormat('d MMMM y', 'id_ID');

String formatDate(DateTime date) => _indonesianDateFormatter.format(date);
