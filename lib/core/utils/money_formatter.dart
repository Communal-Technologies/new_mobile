import 'package:intl/intl.dart';

String formatMoney(double amount) {
  // Using NumberFormat from intl package for formatting
  final format = NumberFormat("#,##0.00", "en_US");
  
  return format.format(amount);
}
