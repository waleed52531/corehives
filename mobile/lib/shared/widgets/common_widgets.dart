import 'package:flutter/material.dart';
import '../models/money.dart';
import '../../app/theme.dart';

class MoneyText extends StatelessWidget {
  final int paisa;
  final bool isCashIn;
  final double fontSize;
  const MoneyText({super.key, required this.paisa, this.isCashIn = true, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final color = isCashIn ? CoreHivesTheme.cashInColor : CoreHivesTheme.cashOutColor;
    return Text(
      Money(paisa).format(),
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: fontSize),
    );
  }
}

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  const AmountField({super.key, required this.controller, this.label = 'Amount (PKR)', this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      decoration: InputDecoration(labelText: label, prefixText: 'PKR ', border: const OutlineInputBorder()),
      validator: validator ??
          (v) {
            final n = num.tryParse(v ?? '');
            if (n == null || n <= 0) return 'Enter a valid amount';
            return null;
          },
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey)),
    );
  }
}
