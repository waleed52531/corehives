import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/month_key.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../payroll/presentation/payroll_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = ref.watch(selectedMonthKeyProvider);
    final txAsync = ref.watch(transactionsForMonthProvider);
    final payrollAsync = ref.watch(payrollEntriesForMonthProvider(monthKey));
    final unreadCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;
    final pendingReimbursementsAsync = ref.watch(pendingReimbursementsProvider);
    final pendingReimbursementsCount = pendingReimbursementsAsync.value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CoreHives'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.credit_card_outlined),
                tooltip: 'Pending Reimbursements',
                onPressed: () => context.push('/pending-reimbursements'),
              ),
              if (pendingReimbursementsCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingReimbursementsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Platform IDs',
            onPressed: () => context.push('/platform-ids'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Employees',
            onPressed: () => context.push('/employees'),
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

          final balancesAsync = ref.watch(monthlyBalancesProvider(monthKey));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsForMonthProvider);
              ref.invalidate(allTransactionsSinceBackupProvider);
              ref.invalidate(pendingUserWithdrawalsProvider);
              ref.invalidate(pendingReimbursementsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const PendingWithdrawalsSection(),
                balancesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load balances: $e'),
                  data: (bal) => Card(
                    color: Colors.green.shade50,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('CUMULATIVE LEDGER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getCycleDateRangeString(monthKey),
                                    style: TextStyle(fontSize: 9, color: Colors.green.shade700.withOpacity(0.8), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => _pickMonth(context, ref),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        monthKey.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.arrow_drop_down, size: 16, color: Colors.green.shade800),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Opening Balance:', style: TextStyle(color: Colors.grey)),
                              MoneyText(paisa: bal.openingBalancePaisa, isCashIn: true, fontSize: 15),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Monthly Net Flow:', style: TextStyle(color: Colors.grey)),
                              MoneyText(paisa: net, isCashIn: net >= 0, fontSize: 15),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Closing Balance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              MoneyText(paisa: bal.closingBalancePaisa, isCashIn: bal.closingBalancePaisa >= 0, fontSize: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                ...bySource.entries.map((e) => _BreakdownRow(label: _capitalizeWords(e.key), paisa: e.value, isCashIn: true)),
                const SectionHeader('Expenses Paid By'),
                if (byPerson.isEmpty) const Text('No expenses recorded this month.', style: TextStyle(color: Colors.grey)),
                ...byPerson.entries.map((e) => _BreakdownRow(label: _capitalizeWords(e.key), paisa: e.value, isCashIn: false)),
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

  String _capitalizeWords(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _getCycleDateRangeString(String monthKey) {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final start = DateTime(year, month - 1, 11);
      final end = DateTime(year, month, 10);
      final startFmt = DateFormat('MMM d, yyyy').format(start);
      final endFmt = DateFormat('MMM d, yyyy').format(end);
      return '$startFmt to $endFmt';
    } catch (_) {
      return '';
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

class PendingWithdrawalsSection extends ConsumerWidget {
  const PendingWithdrawalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingUserWithdrawalsProvider);

    return pendingAsync.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();

        final totalAmountPaisa = list.fold<int>(0, (sum, t) => sum + t.amountPaisa);

        return Card(
          color: Colors.amber.shade50,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    const Text(
                      'ACTION REQUIRED',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You have ${list.length} pending withdrawals to resolve.',
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text('Total Amount: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              MoneyText(paisa: totalAmountPaisa, isCashIn: true, fontSize: 13),
                            ],
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

