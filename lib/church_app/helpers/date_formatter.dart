import 'package:intl/intl.dart';

String humanFormatDate(DateTime date) {
  final datePart = DateFormat('MMM d').format(date);
  final timePart = DateFormat('h:mm a').format(date);
  return "$datePart at $timePart";
}