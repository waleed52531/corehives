import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/models/month_key.dart';
import 'package:intl/intl.dart';
import '../../employees/presentation/employee_providers.dart';
import '../domain/payroll_models.dart';
import 'payroll_providers.dart';

class PayrollEntryDetailScreen extends ConsumerWidget {
  final String entryId;
  const PayrollEntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = entryId.split('_').first;
    final entriesAsync = ref.watch(payrollEntriesForMonthProvider(monthKey));
    final paymentsAsync = ref.watch(payrollPaymentsForEntryProvider(entryId));
    final user = ref.watch(currentAppUserProvider).value;
    final canManage = user != null && user.can((p) => p.managePayroll);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Entry'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Edit Expected Amount',
              onPressed: () {
                final entry = entriesAsync.value?.where((e) => e.id == entryId).firstOrNull;
                if (entry != null) {
                  _showEditExpectedDialog(context, ref, entry);
                }
              },
            ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showRecordPaymentSheet(context, ref, entryId),
              icon: const Icon(Icons.add),
              label: const Text('Record Payment'),
            )
          : null,
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          final entry = entries.where((e) => e.id == entryId).firstOrNull;
          if (entry == null) return const Center(child: Text('Entry not found.'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.employeeName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${entry.compensationType} · $monthKey', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (canManage)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Sync Salary', style: TextStyle(fontSize: 12)),
                      onPressed: () => _syncWithCurrentCompensation(context, ref, entry),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _stat('Expected', entry.expectedAmountPaisa)),
                  Expanded(child: _stat('Paid', entry.totalPaidAmountPaisa)),
                  Expanded(child: _stat('Remaining', entry.remainingAmountPaisa)),
                ],
              ),
              const SectionHeader('Payment History'),
              paymentsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (payments) {
                  if (payments.isEmpty) {
                    return const Text('No payments recorded yet.', style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: payments
                        .map((p) => Card(
                              child: ListTile(
                                title: MoneyText(paisa: p.amountPaisa, isCashIn: false),
                                subtitle: Text(
                                    '${p.paymentDateKey} · ${p.paymentMethod ?? '—'} · by ${p.paidByUserName}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (p.receiptUrl != null) const Icon(Icons.attachment, size: 18),
                                    if (canManage) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        tooltip: 'Delete Payment',
                                        onPressed: () => _confirmDeletePayment(context, ref, p),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, int paisa) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        MoneyText(paisa: paisa, isCashIn: false, fontSize: 14),
      ],
    );
  }

  void _confirmDeletePayment(BuildContext context, WidgetRef ref, PayrollPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Delete this payment of PKR ${(payment.amountPaisa / 100).toStringAsFixed(0)} on ${payment.paymentDateKey}? Payroll totals will be recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(payrollRepositoryProvider).deletePayrollPayment(payment.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete payment: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditExpectedDialog(BuildContext context, WidgetRef ref, PayrollEntry entry) {
    final ctrl = TextEditingController(text: (entry.expectedAmountPaisa / 100).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Expected Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update expected salary for ${entry.employeeName} (${entry.monthKey}):', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              decoration: const InputDecoration(
                labelText: 'Expected Amount (PKR)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text.trim());
              if (val == null || val < 0) return;
              Navigator.pop(ctx);
              try {
                await ref.read(payrollRepositoryProvider).updateExpectedAmount(entry.id, val * 100);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expected amount updated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating expected amount: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncWithCurrentCompensation(BuildContext context, WidgetRef ref, PayrollEntry entry) async {
    try {
      final comp = await ref.read(employeeRepositoryProvider).compensationFor(entry.employeeId);
      if (comp == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No compensation record found for this employee')),
          );
        }
        return;
      }
      await ref.read(payrollRepositoryProvider).updateExpectedAmount(entry.id, comp.baseSalaryPaisa);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced expected amount to PKR ${(comp.baseSalaryPaisa / 100).toStringAsFixed(0)}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing compensation: $e')),
        );
      }
    }
  }

  void _showRecordPaymentSheet(BuildContext context, WidgetRef ref, String entryId) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? paymentMethod;
    DateTime date = DateTime.now();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Record Payroll Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              AmountField(controller: amountCtrl),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: ['Cash', 'Bank Transfer', 'JazzCash', 'EasyPaisa', 'Other']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setSheetState(() => paymentMethod = v),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payment Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() => date = picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final amount = num.tryParse(amountCtrl.text);
                        if (amount == null || amount <= 0) return;
                        setSheetState(() => saving = true);
                        try {
                          final repo = ref.read(payrollRepositoryProvider);
                          final paymentId = repo.newPaymentId(); // deterministic idempotency key
                          await repo.recordPayrollPayment(
                            payrollEntryId: entryId,
                            paymentId: paymentId,
                            amountPaisa: (amount * 100).round(),
                            paymentDateKey: MonthKey.dateKeyFromDate(date),
                            paymentMethod: paymentMethod,
                            notes: notesCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setSheetState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Could not record payment: $e')),
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
