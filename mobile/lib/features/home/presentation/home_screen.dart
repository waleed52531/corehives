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
    final pendingAllCashInsAsync = ref.watch(pendingAllCashInsProvider);
    final pendingAllCashInsCount = pendingAllCashInsAsync.value?.length ?? 0;

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
                icon: const Icon(Icons.account_balance_wallet_outlined),
                tooltip: 'Pending Withdrawals',
                onPressed: () => context.push('/pending-cash-ins'),
              ),
              if (pendingAllCashInsCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingAllCashInsCount.toString(),
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
                      color: Colors.red,
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
              ref.invalidate(pendingAllCashInsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const PendingWithdrawalsSection(),
                balancesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load balances: $e'),
                  data: (bal) => Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F5A47), Color(0xFF083C2F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CUMULATIVE LEDGER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade200,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getCycleDateRangeString(monthKey.toString()),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              Material(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () => _pickMonth(context, ref),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          monthKey.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Closing Balance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal.shade100,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          MoneyText(
                            paisa: bal.closingBalancePaisa,
                            isCashIn: bal.closingBalancePaisa >= 0,
                            fontSize: 30,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Opening Balance',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.teal.shade200,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    MoneyText(
                                      paisa: bal.openingBalancePaisa,
                                      isCashIn: bal.openingBalancePaisa >= 0,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Monthly Net Flow',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.teal.shade200,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    MoneyText(
                                      paisa: net,
                                      isCashIn: net >= 0,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SectionHeader('Operational Metrics'),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Cash In',
                        paisa: totalCashIn,
                        isCashIn: true,
                        onTap: () => context.go('/transactions?filter=cashIn'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Cash Out',
                        paisa: totalCashOut,
                        isCashIn: false,
                        onTap: () => context.go('/transactions?filter=expense'),
                      ),
                    ),
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
                const SectionHeader('Actions Pending'),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pending Cash In',
                        paisa: pendingAllCashInsAsync.value?.fold<int>(0, (sum, t) => sum + t.amountPaisa) ?? 0,
                        isCashIn: true,
                        onTap: () => context.push('/pending-cash-ins'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Pending Reimburse.',
                        paisa: pendingReimbursementsAsync.value?.fold<int>(0, (sum, t) => sum + t.amountPaisa) ?? 0,
                        isCashIn: false,
                        onTap: () => context.push('/pending-reimbursements'),
                      ),
                    ),
                  ],
                ),
                const SectionHeader('Cash In Breakdown'),
                if (bySource.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No cash in recorded this month.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                else
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(top: 4, bottom: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bySource.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, idx) {
                        final entry = bySource.entries.elementAt(idx);
                        final sourceName = _capitalizeWords(entry.key);
                        IconData sourceIcon = Icons.account_balance_outlined;
                        Color iconColor = Colors.teal;
                        if (sourceName.toLowerCase().contains('upwork')) {
                          sourceIcon = Icons.work_outline;
                          iconColor = Colors.green;
                        } else if (sourceName.toLowerCase().contains('fiverr')) {
                          sourceIcon = Icons.work_history_outlined;
                          iconColor = Colors.green.shade700;
                        } else if (sourceName.toLowerCase().contains('jazzcash') || sourceName.toLowerCase().contains('easypaisa')) {
                          sourceIcon = Icons.mobile_friendly;
                          iconColor = Colors.purple;
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: iconColor.withOpacity(0.1),
                            radius: 16,
                            child: Icon(sourceIcon, size: 16, color: iconColor),
                          ),
                          title: Text(
                            sourceName,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                          trailing: MoneyText(paisa: entry.value, isCashIn: true, fontSize: 14),
                        );
                      },
                    ),
                  ),
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
  final VoidCallback? onTap;
  const _SummaryCard({
    required this.label,
    required this.paisa,
    required this.isCashIn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null;

    Color iconColor;
    Color circleBg;
    IconData iconData;
    Color moneyTextColor;

    if (label == 'Cash In') {
      iconColor = Colors.green.shade700;
      circleBg = Colors.green.shade50;
      iconData = Icons.arrow_upward;
      moneyTextColor = Colors.green.shade800;
    } else if (label == 'Cash Out') {
      iconColor = Colors.red.shade700;
      circleBg = Colors.red.shade50;
      iconData = Icons.arrow_downward;
      moneyTextColor = Colors.red.shade800;
    } else if (label == 'Payroll Paid') {
      iconColor = Colors.red.shade700;
      circleBg = Colors.red.shade50;
      iconData = Icons.people_outline;
      moneyTextColor = Colors.red.shade800;
    } else if (label == 'Net Cash Flow') {
      final isPositive = paisa >= 0;
      iconColor = isPositive ? Colors.teal.shade700 : Colors.red.shade700;
      circleBg = isPositive ? Colors.teal.shade50 : Colors.red.shade50;
      iconData = isPositive ? Icons.trending_up : Icons.trending_down;
      moneyTextColor = isPositive ? Colors.teal.shade800 : Colors.red.shade800;
    } else if (label == 'Pending Cash In') {
      iconColor = Colors.orange.shade700;
      circleBg = Colors.orange.shade50;
      iconData = Icons.hourglass_top_outlined;
      moneyTextColor = Colors.orange.shade800;
    } else if (label == 'Pending Reimburse.') {
      iconColor = Colors.red.shade700;
      circleBg = Colors.red.shade50;
      iconData = Icons.history_edu_outlined;
      moneyTextColor = Colors.red.shade800;
    } else {
      iconColor = Colors.grey;
      circleBg = Colors.grey.shade100;
      iconData = Icons.info_outline;
      moneyTextColor = Colors.black87;
    }

    final cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: circleBg,
                child: Icon(iconData, size: 13, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isClickable) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 9, color: Colors.grey.shade300),
              ],
            ],
          ),
          const SizedBox(height: 10),
          MoneyText(
            paisa: paisa,
            isCashIn: isCashIn,
            fontSize: 17,
            color: moneyTextColor,
          ),
          if (isClickable) ...[
            const SizedBox(height: 4),
            Text(
              'Tap to view',
              style: TextStyle(
                color: iconColor.withValues(alpha: 0.8),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (isClickable) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: cardContent,
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

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: Colors.orange.shade600, width: 4),
              top: BorderSide(color: Colors.amber.shade100),
              right: BorderSide(color: Colors.amber.shade100),
              bottom: BorderSide(color: Colors.amber.shade100),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTION REQUIRED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Resolve ${list.length} pending client payments',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text('Total Outstanding: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          MoneyText(paisa: totalAmountPaisa, isCashIn: true, fontSize: 12),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: Row(
                    children: [
                      Text('View', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                      Icon(Icons.chevron_right, size: 16, color: Colors.orange.shade800),
                    ],
                  ),
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

