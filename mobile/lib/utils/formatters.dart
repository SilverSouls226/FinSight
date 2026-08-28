import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _currencyFormatPrecise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFormat = DateFormat('MMM d, yyyy');
final _dateTimeFormat = DateFormat('MMM d, h:mm a');

String formatCurrency(double amount, {bool precise = false}) {
  return precise ? _currencyFormatPrecise.format(amount) : _currencyFormat.format(amount);
}

String formatDate(DateTime date) => _dateFormat.format(date);

String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

String formatPercent(double fraction) => '${(fraction * 100).round()}%';

String daysUntil(DateTime date) {
  final now = DateTime.now();
  final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff < 0) return 'Overdue';
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  return 'Due in $diff days';
}
