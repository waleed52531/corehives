import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/models/month_key.dart';
import 'package:intl/intl.dart';
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
      appBar: AppBar(title: const Text('Payroll Entry')),
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
              Text(entry.employeeName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(entry.compensationType, style: const TextStyle(color: Colors.grey)),
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
                                trailing: p.receiptUrl != null ? const Icon(Icons.attachment, size: 18) : null,
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
