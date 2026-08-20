import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../domain/transaction_model.dart';
import '../presentation/transaction_providers.dart';
import '../../home/presentation/monthly_closing_providers.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(transactionRepositoryProvider);
    final user = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Detail')),
      body: FutureBuilder<Transaction?>(
        future: repo.byId(transactionId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final t = snap.data;
          if (t == null) return const Center(child: Text('Transaction not found.'));

          final monthClosedAsync = ref.watch(monthlyClosingStatusProvider(t.monthKey));
          final isCashIn = t.type == TxType.cashIn;

          return monthClosedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Could not check month status.')),
            data: (isClosed) {
              final canEdit = user != null &&
                  (user.isAdmin || (t.createdByUserId == user.uid && !isClosed));

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isCashIn ? 'Cash In' : 'Expense',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (t.lateEntry)
                        const Chip(label: Text('Late Entry'), backgroundColor: Color(0xFFFFE9CC)),
                    ],
                  ),
                  MoneyText(paisa: t.amountPaisa, isCashIn: isCashIn, fontSize: 28),
                  const Divider(height: 32),
                  _row('Category', t.categoryName ?? t.sourceType),
                  _row('Subcategory', t.subcategoryName),
                  _row('Project', t.projectName),
                  _row('Payee', t.payeeName),
                  _row('Upwork Account', t.upworkAccountName),
                  _row('Client', t.clientName),
                  _row('Salesperson', t.salespersonName),
                  _row('Paid By', t.paidByUserName),
                  _row('Payment Method', t.paymentMethod),
                  _row('Transaction Date', t.transactionDateKey),
                  _row('Status', t.status),
                  _row('Created By', t.createdByName),
                  _row('Created At', _formatTs(t.createdAt)),
                  _row('Updated At', _formatTs(t.updatedAt)),
                  if (t.notes != null && t.notes!.isNotEmpty) _row('Notes', t.notes),
                  if (t.description != null && t.description!.isNotEmpty) _row('Description', t.description),
                  if (t.attachmentUrl != null) ...[
                    const SectionHeader('Receipt'),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(t.attachmentUrl!, fit: BoxFit.cover),
                    ),
                  ] else if (t.attachmentStatus == AttachmentStatus.failed) ...[
                    const SectionHeader('Receipt'),
                    const Text('Upload failed — no receipt attached.', style: TextStyle(color: Colors.red)),
                  ],
                  if (isClosed && !user!.isAdmin) ...[
                    const SizedBox(height: 16),
                    const Text('This month is closed. Contact an admin to make changes.',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                  const SizedBox(height: 24),
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, ref, t.id, user.uid),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete Transaction', style: TextStyle(color: Colors.red)),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return '';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
    } catch (_) {
      return '';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String txId, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('This will remove the transaction from reports. It is not permanently erased.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(transactionRepositoryProvider).softDelete(txId, uid);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) context.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
