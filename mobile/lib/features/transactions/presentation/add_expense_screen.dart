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
import '../../../shared/services/notification_service.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? editId;
  const AddExpenseScreen({super.key, this.editId});
  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  String _status = 'completed';

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTransaction();
      });
    }
  }

  void _loadTransaction() async {
    final repo = ref.read(transactionRepositoryProvider);
    final tx = await repo.byId(widget.editId!);
    if (tx != null && mounted) {
      setState(() {
        _originalTx = tx;
        _amountCtrl.text = (tx.amountPaisa / 100).toStringAsFixed(2);
        _descCtrl.text = tx.description ?? '';
        _notesCtrl.text = tx.notes ?? '';
        _payeeCtrl.text = tx.payeeName ?? '';
        _paymentMethod = tx.paymentMethod;
        _status = tx.status;
        _date = DateTime.tryParse(tx.transactionDateKey) ?? DateTime.now();

        // Populate Category
        final categories = ref.read(activeExpenseCategoriesProvider).value ?? [];
        try {
          _category = categories.firstWhere((c) => c.id == tx.categoryId);
        } catch (_) {
          _category = ExpenseCategory(id: tx.categoryId!, name: tx.categoryName!, active: true, order: 0);
        }

        // Populate Subcategory
        if (_category != null) {
          final subRef = ref.read(activeSubcategoriesProvider(_category!.id)).value ?? [];
          try {
            _subcategory = subRef.firstWhere((s) => s.id == tx.subcategoryId);
          } catch (_) {
            _subcategory = ExpenseSubcategory(id: tx.subcategoryId!, categoryId: tx.categoryId!, name: tx.subcategoryName!, active: true, order: 0);
          }
        }

        // Populate Platform Account
        if (tx.upworkAccountId != null) {
          final accounts = ref.read(activeUpworkAccountsProvider).value ?? [];
          try {
            _selectedPlatformAccount = accounts.firstWhere((a) => a.id == tx.upworkAccountId);
          } catch (_) {
            _selectedPlatformAccount = UpworkAccount(id: tx.upworkAccountId!, name: tx.upworkAccountName!, platform: 'upwork', active: true);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _payeeCtrl.dispose();
    super.dispose();
  }

  Transaction? _originalTx;
  ExpenseCategory? _category;
  ExpenseSubcategory? _subcategory;
  DateTime _date = DateTime.now();
  String? _paymentMethod;
  File? _receiptFile;
  double? _uploadProgress;
  bool _uploadFailed = false;
  bool _saving = false;

  UpworkAccount? _selectedPlatformAccount;

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
    final docId = widget.editId ?? repo.newDocRef().id;
    final amountPaisa = (num.parse(_amountCtrl.text) * 100).round();
    final dateKey = MonthKey.dateKeyFromDate(_date);
    final monthKey = MonthKey.fromDate(_date);

    final payees = ref.read(activePayeesProvider).value ?? [];
    final enteredPayeeName = _payeeCtrl.text.trim();
    String? payeeId;
    String? payeeName;

    if (enteredPayeeName.isNotEmpty) {
      payeeName = enteredPayeeName;
      try {
        final matchingPayee = payees.firstWhere(
          (p) => p.name.toLowerCase() == enteredPayeeName.toLowerCase(),
        );
        payeeId = matchingPayee.id;
        payeeName = matchingPayee.name;
      } catch (_) {
        // Keep payeeId as null, keep payeeName as typed
      }
    }

    final tx = Transaction(
      id: docId,
      type: TxType.expense,
      amountPaisa: amountPaisa,
      categoryId: _category!.id,
      categoryName: _category!.name,
      subcategoryId: _subcategory!.id,
      subcategoryName: _subcategory!.name,
      payeeId: payeeId,
      payeeName: payeeName,
      projectId: null,
      projectName: null,
      upworkAccountId: _selectedPlatformAccount?.id,
      upworkAccountName: _selectedPlatformAccount?.name,
      paidByUserId: user.uid,
      paidByUserName: user.name,
      paymentMethod: _paymentMethod,
      transactionDateKey: dateKey,
      monthKey: monthKey,
      status: _status.toLowerCase(),
      attachmentStatus: _receiptFile != null ? AttachmentStatus.pending : AttachmentStatus.none,
      description: _descCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdByUserId: user.uid,
      createdByName: user.name,
    );

    try {
      // Save the transaction FIRST — never lose the financial record because
      // of a receipt upload failure.
      if (widget.editId != null) {
        await repo.update(docId, {
          'amountPaisa': amountPaisa,
          'categoryId': _category!.id,
          'categoryName': _category!.name,
          'subcategoryId': _subcategory!.id,
          'subcategoryName': _subcategory!.name,
          'payeeId': payeeId,
          'payeeName': payeeName,
          'upworkAccountId': _selectedPlatformAccount?.id,
          'upworkAccountName': _selectedPlatformAccount?.name,
          'paymentMethod': _paymentMethod,
          'transactionDateKey': dateKey,
          'monthKey': monthKey,
          'description': _descCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
          'status': _status.toLowerCase(),
          'updatedByUserId': user.uid,
          'updatedByName': user.name,
        });
        if (_originalTx != null &&
            _originalTx!.status.toLowerCase() == 'pending' &&
            _status.toLowerCase() == 'completed' &&
            _originalTx!.createdByUserId != user.uid) {
          NotificationService.sendPendingReimbursementCompletedNotification(
            originalCreatorUserId: _originalTx!.createdByUserId,
            amount: amountPaisa / 100,
            updaterName: user.name,
            transactionId: docId,
          );
        }
      } else {
        await repo.create(tx);
      }

      if (_receiptFile != null) {
        try {
          final result = await ref.read(receiptUploadServiceProvider).uploadReceipt(
                file: _receiptFile!,
                transactionId: docId,
                year: _date.year,
                month: _date.month,
                onProgress: (p) => setState(() => _uploadProgress = p),
              );
          await repo.updateAttachment(
            txId: docId,
            url: result.url,
            storagePath: result.storagePath,
            status: AttachmentStatus.uploaded,
          );
        } catch (e) {
          print('Expense receipt upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e')),
            );
          }
          await repo.markAttachmentFailed(docId);
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
    final payeesAsync = ref.watch(activePayeesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.editId != null ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AmountField(controller: _amountCtrl),
            const SectionHeader('Category'),
            categoriesAsync.when(
              data: (cats) {
                final dropdownItems = _category != null && !cats.contains(_category)
                    ? [...cats, _category!]
                    : cats;
                return DropdownButtonFormField<ExpenseCategory>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: dropdownItems.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() {
                    _category = v;
                    _subcategory = null;
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load categories'),
            ),
            const SizedBox(height: 12),
            if (_category != null)
              Consumer(builder: (context, ref, _) {
                final subsAsync = ref.watch(activeSubcategoriesProvider(_category!.id));
                return subsAsync.when(
                  data: (subs) {
                    final subName = _subcategory?.name;
                    final isUpwork = subName == 'Upwork Connects' || subName == 'Upwork Subscription';
                    final isFiverr = subName == 'Fiverr Expense';
                    final isFreelancer = subName == 'Freelancer Subscription';
                    final showPlatformDropdown = isUpwork || isFiverr || isFreelancer;
                    final targetPlatform = isUpwork ? 'upwork' : (isFiverr ? 'fiverr' : 'freelancer');
                    final labelText = isUpwork ? 'Select Upwork ID' : (isFiverr ? 'Select Fiverr ID' : 'Select Freelancer ID');

                    final dropdownItems = _subcategory != null && !subs.contains(_subcategory)
                        ? [...subs, _subcategory!]
                        : subs;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<ExpenseSubcategory>(
                          value: _subcategory,
                          decoration: const InputDecoration(labelText: 'Subcategory', border: OutlineInputBorder()),
                          items: dropdownItems.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                          onChanged: (v) => setState(() {
                            _subcategory = v;
                            _selectedPlatformAccount = null;
                          }),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        if (showPlatformDropdown) ...[
                          const SizedBox(height: 12),
                          Consumer(builder: (context, ref, _) {
                            final accountsAsync = ref.watch(activeUpworkAccountsProvider);
                            return accountsAsync.when(
                              data: (accounts) {
                                final filtered = accounts.where((a) => a.platform == targetPlatform).toList();
                                final dropdownItems = _selectedPlatformAccount != null && !filtered.contains(_selectedPlatformAccount)
                                    ? [...filtered, _selectedPlatformAccount!]
                                    : filtered;
                                return Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<UpworkAccount>(
                                        value: _selectedPlatformAccount,
                                        decoration: InputDecoration(
                                          labelText: labelText,
                                          border: const OutlineInputBorder(),
                                        ),
                                        items: dropdownItems
                                            .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                                            .toList(),
                                        onChanged: (a) => setState(() => _selectedPlatformAccount = a),
                                        validator: (a) => a == null ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      tooltip: 'Manage Platform IDs',
                                      onPressed: () => context.push('/platform-ids'),
                                    ),
                                  ],
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => const Text('Could not load accounts'),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Could not load subcategories'),
                );
              }),
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
            const SectionHeader('Notes'),
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            ),
            const SectionHeader('Optional Details'),
            payeesAsync.when(
              data: (payees) => TextFormField(
                controller: _payeeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Paid To / Payee (optional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: payees.isEmpty
                      ? null
                      : PopupMenuButton<Payee>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (Payee value) {
                            setState(() {
                              _payeeCtrl.text = value.name;
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            return payees.map((Payee p) {
                              return PopupMenuItem<Payee>(
                                value: p,
                                child: Text(p.name),
                              );
                            }).toList();
                          },
                        ),
                ),
              ),
              loading: () => TextFormField(
                controller: _payeeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Paid To / Payee (optional)',
                  border: OutlineInputBorder(),
                  suffixIcon: SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              error: (_, __) => TextFormField(
                controller: _payeeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Paid To / Payee (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method (optional)', border: OutlineInputBorder()),
              items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _paymentMethod = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'pending', child: Text('Pending Reimbursement')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.editId != null ? 'Save Changes' : 'Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
