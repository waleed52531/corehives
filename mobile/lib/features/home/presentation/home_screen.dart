import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/models/month_key.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../payroll/presentation/payroll_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = ref.watch(selectedMonthKeyProvider);
    final txAsync = ref.watch(transactionsForMonthProvider);
    final user = ref.watch(currentAppUserProvider).value;
    final payrollAsync = ref.watch(payrollEntriesForMonthProvider(monthKey));

    return Scaffold(
      appBar: AppBar(
        title: Text('CoreHives — $monthKey'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Employees',
            onPressed: () => context.push('/employees'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _pickMonth(context, ref),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load dashboard: $e')),
        data: (transactions) {
          final cashIn = transactions.where((t) => t.type == TxType.cashIn && t.status == 'completed');
          final expenses = transactions.where((t) => t.type == TxType.expense);

          final totalCashIn = cashIn.fold<int>(0, (s, t) => s + t.amountPaisa);
          final totalExpense = expenses.fold<int>(0, (s, t) => s + t.amountPaisa);
          final payrollPaid = payrollAsync.value?.fold<int>(0, (s, e) => s + e.totalPaidAmountPaisa) ?? 0;
          final totalCashOut = totalExpense; // payroll expenses already land in `expenses` via linked transactions
          final net = totalCashIn - totalCashOut;

          final byPerson = <String, int>{};
          for (final t in expenses) {
            byPerson[t.paidByUserName] = (byPerson[t.paidByUserName] ?? 0) + t.amountPaisa;
          }

          final bySource = <String, int>{};
          for (final t in cashIn) {
            final key = t.sourceType ?? 'Other';
            bySource[key] = (bySource[key] ?? 0) + t.amountPaisa;
          }

          final recent = transactions.take(8).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(transactionsForMonthProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: _SummaryCard(label: 'Cash In', paisa: totalCashIn, isCashIn: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryCard(label: 'Cash Out', paisa: totalCashOut, isCashIn: false)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _SummaryCard(label: 'Payroll Paid', paisa: payrollPaid, isCashIn: false)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryCard(label: 'Net Cash Flow', paisa: net, isCashIn: net >= 0)),
                  ],
                ),
                const SectionHeader('Cash In Breakdown'),
                if (bySource.isEmpty) const Text('No cash in recorded this month.', style: TextStyle(color: Colors.grey)),
                ...bySource.entries.map((e) => _BreakdownRow(label: e.key, paisa: e.value, isCashIn: true)),
                const SectionHeader('Expenses Paid By'),
                if (byPerson.isEmpty) const Text('No expenses recorded this month.', style: TextStyle(color: Colors.grey)),
                ...byPerson.entries.map((e) => _BreakdownRow(label: e.key, paisa: e.value, isCashIn: false)),
                const SectionHeader('Recent Transactions'),
                if (recent.isEmpty) const Text('No transactions yet.', style: TextStyle(color: Colors.grey)),
                ...recent.map((t) => _RecentTxTile(tx: t)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year + 1),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      ref.read(selectedMonthKeyProvider.notifier).state = MonthKey.fromDate(picked);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int paisa;
  final bool isCashIn;
  const _SummaryCard({required this.label, required this.paisa, required this.isCashIn});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            MoneyText(paisa: paisa, isCashIn: isCashIn, fontSize: 18),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int paisa;
  final bool isCashIn;
  const _BreakdownRow({required this.label, required this.paisa, required this.isCashIn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), MoneyText(paisa: paisa, isCashIn: isCashIn, fontSize: 14)],
      ),
    );
  }
}

class _RecentTxTile extends StatelessWidget {
  final Transaction tx;
  const _RecentTxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCashIn = tx.type == TxType.cashIn;
    final title = isCashIn ? (tx.sourceType ?? 'Cash In') : (tx.categoryName ?? 'Expense');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isCashIn ? Icons.arrow_downward : Icons.arrow_upward,
          color: isCashIn ? Colors.green : Colors.red),
      title: Text(title),
      subtitle: Text('${tx.transactionDateKey} · ${tx.paidByUserName}'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MoneyText(paisa: tx.amountPaisa, isCashIn: isCashIn, fontSize: 14),
          if (tx.attachmentStatus.name == 'uploaded') const Icon(Icons.attachment, size: 14, color: Colors.grey),
        ],
      ),
      onTap: () => context.push('/transactions/${tx.id}'),
    );
  }
}
