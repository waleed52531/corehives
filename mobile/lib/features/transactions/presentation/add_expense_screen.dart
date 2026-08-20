import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/receipt_picker.dart';
import '../../../shared/models/month_key.dart';
import '../../config/presentation/config_providers.dart';
import '../../config/domain/config_models.dart';
import '../domain/transaction_model.dart';
import '../presentation/transaction_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  ExpenseCategory? _category;
  ExpenseSubcategory? _subcategory;
  dynamic _payee; // Payee?
  dynamic _project; // Project?
  DateTime _date = DateTime.now();
  String? _paymentMethod;
  File? _receiptFile;
  double? _uploadProgress;
  bool _uploadFailed = false;
  bool _saving = false;

  static const _paymentMethods = ['Cash', 'Bank Transfer', 'JazzCash', 'EasyPaisa', 'Card', 'Other'];

  Future<void> _submit() async {
    if (_saving) return; // duplicate-submit guard
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _subcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category and subcategory')),
      );
      return;
    }

    setState(() => _saving = true);

    final user = ref.read(currentAppUserProvider).value;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final docRef = repo.newDocRef();
    final amountPaisa = (num.parse(_amountCtrl.text) * 100).round();
    final dateKey = MonthKey.dateKeyFromDate(_date);
    final monthKey = MonthKey.fromDate(_date);

    final tx = Transaction(
      id: docRef.id,
      type: TxType.expense,
      amountPaisa: amountPaisa,
      categoryId: _category!.id,
      categoryName: _category!.name,
      subcategoryId: _subcategory!.id,
      subcategoryName: _subcategory!.name,
      payeeId: _payee?.id,
      payeeName: _payee?.name,
      projectId: _project?.id,
      projectName: _project?.name,
      paidByUserId: user.uid,
      paidByUserName: user.name,
      paymentMethod: _paymentMethod,
      transactionDateKey: dateKey,
      monthKey: monthKey,
      status: 'completed',
      attachmentStatus: _receiptFile != null ? AttachmentStatus.pending : AttachmentStatus.none,
      description: _descCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdByUserId: user.uid,
      createdByName: user.name,
    );

    try {
      // Save the transaction FIRST — never lose the financial record because
      // of a receipt upload failure.
      await repo.create(tx);

      if (_receiptFile != null) {
        try {
          final result = await ref.read(receiptUploadServiceProvider).uploadReceipt(
                file: _receiptFile!,
                transactionId: docRef.id,
                year: _date.year,
                month: _date.month,
                onProgress: (p) => setState(() => _uploadProgress = p),
              );
          await repo.updateAttachment(
            txId: docRef.id,
            url: result.url,
            storagePath: result.storagePath,
            status: AttachmentStatus.uploaded,
          );
        } catch (_) {
          await repo.markAttachmentFailed(docRef.id);
          setState(() => _uploadFailed = true);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save expense. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeExpenseCategoriesProvider);
    final projectsAsync = ref.watch(activeProjectsProvider);
    final payeesAsync = ref.watch(activePayeesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AmountField(controller: _amountCtrl),
            const SectionHeader('Category'),
            categoriesAsync.when(
              data: (cats) => DropdownButtonFormField<ExpenseCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() {
                  _category = v;
                  _subcategory = null;
                }),
                validator: (v) => v == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load categories'),
            ),
            const SizedBox(height: 12),
            if (_category != null)
              Consumer(builder: (context, ref, _) {
                final subsAsync = ref.watch(activeSubcategoriesProvider(_category!.id));
                return subsAsync.when(
                  data: (subs) => DropdownButtonFormField<ExpenseSubcategory>(
                    value: _subcategory,
                    decoration: const InputDecoration(labelText: 'Subcategory', border: OutlineInputBorder()),
                    items: subs.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: (v) => setState(() => _subcategory = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Could not load subcategories'),
                );
              }),
            const SectionHeader('Optional Details'),
            payeesAsync.when(
              data: (payees) => DropdownButtonFormField(
                value: _payee,
                decoration: const InputDecoration(labelText: 'Paid To / Payee (optional)', border: OutlineInputBorder()),
                items: payees.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _payee = v),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            projectsAsync.when(
              data: (projects) => DropdownButtonFormField(
                value: _project,
                decoration: const InputDecoration(labelText: 'Project (optional)', border: OutlineInputBorder()),
                items: projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _project = v),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method (optional)', border: OutlineInputBorder()),
              items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _paymentMethod = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transaction Date'),
              subtitle: Text(MonthKey.dateKeyFromDate(_date)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SectionHeader('Receipt'),
            ReceiptPicker(
              file: _receiptFile,
              uploadProgress: _uploadProgress,
              failed: _uploadFailed,
              onPicked: (f) => setState(() {
                _receiptFile = f;
                _uploadFailed = false;
              }),
            ),
            const SectionHeader('Notes'),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
