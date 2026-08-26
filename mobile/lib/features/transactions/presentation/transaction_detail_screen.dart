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
    final user = ref.watch(currentAppUserProvider).value;

    final transactionAsync = ref.watch(transactionStreamProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Detail')),
      body: transactionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (t) {
          if (t == null) return const Center(child: Text('Transaction not found.'));

          final monthClosedAsync = ref.watch(monthlyClosingStatusProvider(t.monthKey));
          final isCashIn = t.type == TxType.cashIn;

          return monthClosedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Could not check month status.')),
            data: (isClosed) {
              bool canEdit = false;
              bool canDelete = false;
              if (user != null) {
                if (isCashIn) {
                  final isCreator = t.createdByUserId == user.uid;
                  final isOwner = _isUpworkAccountOwner(user.name, t.upworkAccountName);
                  final allowedUser = isCreator || isOwner;
                  if (allowedUser) {
                    final allowedAction = !isClosed || user.isAdmin;
                    canEdit = allowedAction;
                    canDelete = allowedAction;
                  }
                } else {
                  canEdit = user.isAdmin || (t.createdByUserId == user.uid && !isClosed);
                  canDelete = t.createdByUserId == user.uid && (!isClosed || user.isAdmin);
                }
              }

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
                  _row(
                    'Paid By',
                    isCashIn
                        ? _getOwnerName(t.upworkAccountName)
                        : _capitalizeWords(t.paidByUserName),
                  ),
                  _row('Payment Method', _capitalizeWords(t.paymentMethod)),
                  _row('Transaction Date', t.transactionDateKey),
                  _rowWidget('Status', _buildStatusBadge(t)),
                  _row('Created By', _capitalizeWords(t.createdByName)),
                  _row('Created At', _formatTs(t.createdAt)),
                  _row('Updated By', _capitalizeWords(t.updatedByName)),
                  _row('Updated At', _formatTs(t.updatedAt)),
                  if (t.notes != null && t.notes!.isNotEmpty) _row('Notes', t.notes),
                  if (t.description != null && t.description!.isNotEmpty) _row('Description', t.description),
                  if (t.attachmentUrl != null && t.attachmentUrl!.isNotEmpty) ...[
                    const SectionHeader('Receipt'),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog.fullscreen(
                            backgroundColor: Colors.black,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      t.attachmentUrl!,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(color: Colors.white),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Text(
                                            'Failed to load receipt image',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 40,
                                  right: 20,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black45,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            t.attachmentUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.grey.shade100,
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey.shade100,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                                    SizedBox(height: 8),
                                    Text('Failed to load receipt image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ] else if (t.attachmentStatus == AttachmentStatus.pending) ...[
                    const SectionHeader('Receipt'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Uploading receipt in background...',
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (t.attachmentStatus == AttachmentStatus.failed) ...[
                    const SectionHeader('Receipt'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Receipt upload failed. Edit transaction to retry.',
                              style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isClosed && !user!.isAdmin) ...[
                    const SizedBox(height: 16),
                    const Text('This month is closed. Contact an admin to make changes.',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                  const SizedBox(height: 24),
                  if (canEdit || canDelete) ...[
                    Row(
                      children: [
                        if (canEdit)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final route = isCashIn
                                    ? '/add-cash-in?editId=${t.id}'
                                    : '/add-expense?editId=${t.id}';
                                context.push(route);
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                          ),
                        if (canEdit && canDelete) const SizedBox(width: 12),
                        if (canDelete)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmDelete(context, ref, t.id, user!.uid),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                      ],
                    ),
                  ],
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

  Widget _rowWidget(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Transaction t) {
    final status = t.status.toLowerCase();
    Color bgColor;
    Color textColor;
    String label = _formatStatus(t);

    if (status == 'completed') {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
    } else if (status == 'pending') {
      bgColor = Colors.amber.shade50;
      textColor = Colors.amber.shade800;
    } else if (status == 'failed') {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
    } else { // cancelled or other
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  bool _isUpworkAccountOwner(String name, String? upworkAccountName) {
    if (upworkAccountName == null) return false;
    final nameLower = name.toLowerCase();
    final accLower = upworkAccountName.toLowerCase();
    if (nameLower.contains('ishtiaq') && accLower.contains('alina')) return true;
    if (nameLower.contains('zain') && (accLower.contains('abiha') || accLower.contains('zain'))) return true;
    if (nameLower.contains('hanzalah') && accLower.contains('hanzalah')) return true;
    return false;
  }

  String _getOwnerName(String? upworkAccountName) {
    if (upworkAccountName == null) return 'Unknown';
    final accLower = upworkAccountName.toLowerCase();
    if (accLower.contains('alina')) return 'Ishtiaq';
    if (accLower.contains('abiha') || accLower.contains('zain')) return 'Zain';
    if (accLower.contains('hanzalah')) return 'Hanzalah';
    return 'Other';
  }

  String _capitalizeWords(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatStatus(Transaction t) {
    if (t.status == 'completed') return 'Completed';
    if (t.status == 'pending') {
      return t.type == TxType.expense ? 'Pending Reimbursement' : 'Pending';
    }
    return _capitalizeWords(t.status);
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
