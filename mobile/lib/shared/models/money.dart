import 'package:intl/intl.dart';

/// PKR amount stored as integer paisa (1 PKR = 100 paisa).
/// Never use double for stored/ledger amounts — only for display formatting.
class Money {
  final int paisa;
  const Money(this.paisa);

  factory Money.fromRupees(num rupees) => Money((rupees * 100).round());

  double get rupees => paisa / 100;

  String format({String locale = 'en_PK'}) {
    final f = NumberFormat.currency(locale: locale, symbol: 'PKR ', decimalDigits: 0);
    return f.format(rupees);
  }

  Money operator +(Money other) => Money(paisa + other.paisa);
  Money operator -(Money other) => Money(paisa - other.paisa);

  @override
  String toString() => format();
}
