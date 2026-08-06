import 'package:intl/intl.dart';

class Formatters {
  static final _date = DateFormat('dd/MM/yyyy');
  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  static String date(DateTime value) => _date.format(value);

  static String currency(num value) => _currency.format(value);
}
