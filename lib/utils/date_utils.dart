import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  return DateFormat('dd.MM.yyyy - HH:mm - EEEE', 'en_US').format(date);
}
