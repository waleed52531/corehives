import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../../shared/models/money.dart';
import 'payroll_providers.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'Paid':
      return Colors.green;
    case 'Partial':
      return Colors.orange;
    case 'Skipped':
      return Colors.grey;
    default:
      return Colors.red;
  }
}

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = ref.watch(selectedMonthKeyProvider);
    final entriesAsync = ref.watch(payrollEntriesForMonthProvider(monthKey));
    final user = ref.watch(currentAppUserProvider).value;
    final canManage = user != null && user.can((p) => p.managePayroll);

    return Scaffold(
      appBar: AppBar(title: Text('Payroll — $monthKey')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                try {
                  final count = await ref.read(payrollRepositoryProvider).generatePayroll(monthKey);
                  if (context.mounted) {
                    final msg = count > 0
                        ? 'Generated payroll entries for $count active employee(s).'
                        : 'Payroll is already up to date for all active employees.';
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Could not generate: $e')));
                  }
                }
              },
              icon: const Icon(Icons.playlist_add),
              label: const Text('Generate'),
            )
          : null,
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load payroll: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No payroll generated for this month yet.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final totalExpected = entries.fold<int>(0, (s, e) => s + e.expectedAmountPaisa);
          final totalPaid = entries.fold<int>(0, (s, e) => s + e.totalPaidAmountPaisa);
          final totalRemaining = totalExpected - totalPaid;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expected', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 4),
                            MoneyText(paisa: totalExpected, isCashIn: false, fontSize: 14, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Paid', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 4),
                            MoneyText(paisa: totalPaid, isCashIn: true, fontSize: 14, color: Colors.green.shade700),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Remaining', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 4),
                            MoneyText(
                              paisa: totalRemaining,
                              isCashIn: false,
                              fontSize: 14,
                              color: totalRemaining < 0 ? Colors.orange.shade800 : Colors.red.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SectionHeader('Employees'),
              ...entries.map((e) => Card(
                    child: ListTile(
                      title: Text(e.employeeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.compensationType, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                Text(
                                  'Paid: ${Money(e.totalPaidAmountPaisa).format()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'Remaining: ${Money(e.remainingAmountPaisa).format()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: e.remainingAmountPaisa < 0 ? Colors.orange.shade800 : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: Chip(
                        label: Text(e.status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        backgroundColor: _statusColor(e.status),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () => context.push('/payroll/${e.id}'),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
