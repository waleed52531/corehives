import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/receipt_picker.dart';
import '../../../shared/models/month_key.dart';
import '../../config/presentation/config_providers.dart';
import '../../config/domain/config_models.dart';
import '../domain/transaction_model.dart';
import '../presentation/transaction_providers.dart';

const _sourceTypes = ['Upwork', 'Front Sale', 'PayPal', 'Direct Client', 'Fiverr', 'Other'];

class AddCashInScreen extends ConsumerStatefulWidget {
  final String? editId;
  const AddCashInScreen({super.key, this.editId});
  @override
  ConsumerState<AddCashInScreen> createState() => _AddCashInScreenState();
}

class _AddCashInScreenState extends ConsumerState<AddCashInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _sourceType = 'Upwork';
  UpworkAccount? _upworkAccount;
  dynamic _project;
  dynamic _salespersonEmployee;
  DateTime _date = DateTime.now();
  String _status = 'Pending';
  File? _receiptFile;
  double? _uploadProgress;
  bool _uploadFailed = false;
  bool _saving = false;
  Transaction? _originalTx;

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
      _originalTx = tx;
      setState(() {
        _amountCtrl.text = (tx.amountPaisa / 100).toStringAsFixed(2);
        _notesCtrl.text = tx.notes ?? '';
        _clientNameCtrl.text = tx.clientName ?? '';
        _sourceType = tx.sourceType ?? 'Other';
        if (tx.status.isNotEmpty) {
          _status = tx.status[0].toUpperCase() + tx.status.substring(1);
        }
        _date = DateTime.tryParse(tx.transactionDateKey) ?? DateTime.now();

        if (tx.upworkAccountId != null) {
          final accounts = ref.read(activeUpworkAccountsProvider).value ?? [];
          try {
            _upworkAccount = accounts.firstWhere((a) => a.id == tx.upworkAccountId);
          } catch (_) {
            _upworkAccount = UpworkAccount(id: tx.upworkAccountId!, name: tx.upworkAccountName!, platform: _sourceType.toLowerCase(), active: true);
          }
        }

        if (tx.projectId != null) {
          final projects = ref.read(activeProjectsProvider).value ?? [];
          try {
            _project = projects.firstWhere((p) => p.id == tx.projectId);
          } catch (_) {
            _project = Project(id: tx.projectId!, name: tx.projectName!, type: ProjectType.other, active: true);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _clientNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  static const _statuses = ['Pending', 'Completed', 'Failed', 'Cancelled'];

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if ((_sourceType == 'Upwork' || _sourceType == 'Fiverr') && _upworkAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select an $_sourceType account')));
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

    final tx = Transaction(
      id: docId,
      type: TxType.cashIn,
      sourceType: _sourceType,
      amountPaisa: amountPaisa,
      upworkAccountId: (_sourceType == 'Upwork' || _sourceType == 'Fiverr') ? _upworkAccount?.id : null,
      upworkAccountName: (_sourceType == 'Upwork' || _sourceType == 'Fiverr') ? _upworkAccount?.name : null,
      projectId: _sourceType == 'Front Sale' ? _project?.id : null,
      projectName: _sourceType == 'Front Sale' ? _project?.name : null,
      salespersonEmployeeId: _sourceType == 'Front Sale' ? _salespersonEmployee?.id : null,
      salespersonName: _sourceType == 'Front Sale' ? _salespersonEmployee?.fullName : null,
      clientName: _sourceType == 'Front Sale' || _sourceType == 'Direct Client'
          ? _clientNameCtrl.text.trim()
          : null,
      paidByUserId: user.uid,
      paidByUserName: user.name,
      transactionDateKey: dateKey,
      monthKey: monthKey,
      status: _status.toLowerCase(),
      attachmentStatus: _receiptFile != null ? AttachmentStatus.pending : AttachmentStatus.none,
      notes: _notesCtrl.text.trim(),
      createdByUserId: user.uid,
      createdByName: user.name,
    );

    try {
      final isPendingWithdrawal = _status.toLowerCase() == 'pending' &&
          (_sourceType == 'Upwork' || _sourceType == 'Fiverr') &&
          _upworkAccount != null;

      if (widget.editId != null) {
        if (_originalTx != null) {
          final isCreator = _originalTx!.createdByUserId == user.uid;
          final isOwner = _isUpworkAccountOwner(user.name, _originalTx!.upworkAccountName);
          if (!isCreator && !isOwner) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are not authorized to edit this transaction.')),
            );
            return;
          }
        }
        await repo.update(docId, {
          'sourceType': _sourceType,
          'amountPaisa': amountPaisa,
          'upworkAccountId': (_sourceType == 'Upwork' || _sourceType == 'Fiverr') ? _upworkAccount?.id : null,
          'upworkAccountName': (_sourceType == 'Upwork' || _sourceType == 'Fiverr') ? _upworkAccount?.name : null,
          'projectId': _sourceType == 'Front Sale' ? _project?.id : null,
          'projectName': _sourceType == 'Front Sale' ? _project?.name : null,
          'salespersonEmployeeId': _sourceType == 'Front Sale' ? _salespersonEmployee?.id : null,
          'salespersonName': _sourceType == 'Front Sale' ? _salespersonEmployee?.fullName : null,
          'clientName': _sourceType == 'Front Sale' || _sourceType == 'Direct Client'
              ? _clientNameCtrl.text.trim()
              : null,
          'transactionDateKey': dateKey,
          'monthKey': monthKey,
          'status': _status.toLowerCase(),
          'notes': _notesCtrl.text.trim(),
          'updatedByUserId': user.uid,
          'updatedByName': user.name,
        });
        if (isPendingWithdrawal) {
          NotificationService.sendPendingWithdrawalNotification(
            upworkAccountId: _upworkAccount!.id,
            upworkAccountName: _upworkAccount!.name,
            amount: amountPaisa / 100,
            transactionId: docId,
          );
        }
        if (_originalTx != null &&
            _originalTx!.status.toLowerCase() == 'pending' &&
            _status.toLowerCase() == 'completed' &&
            _originalTx!.createdByUserId != user.uid) {
          NotificationService.sendPendingWithdrawalCompletedNotification(
            originalCreatorUserId: _originalTx!.createdByUserId,
            amount: amountPaisa / 100,
            updaterName: user.name,
            transactionId: docId,
          );
        }
      } else {
        await repo.create(tx);
        if (isPendingWithdrawal) {
          NotificationService.sendPendingWithdrawalNotification(
            upworkAccountId: _upworkAccount!.id,
            upworkAccountName: _upworkAccount!.name,
            amount: amountPaisa / 100,
            transactionId: docId,
          );
        }
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
          print('Cash-in receipt upload failed: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash in recorded')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upworkAsync = ref.watch(activeUpworkAccountsProvider);
    final projectsAsync = ref.watch(activeProjectsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.editId != null ? 'Edit Cash In' : 'Add Cash In')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _sourceType,
              decoration: const InputDecoration(labelText: 'Source Type', border: OutlineInputBorder()),
              items: _sourceTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() {
                _sourceType = v!;
                _upworkAccount = null;
                _project = null;
                _salespersonEmployee = null;
                _clientNameCtrl.clear();
              }),
            ),
            const SizedBox(height: 12),
            AmountField(controller: _amountCtrl, label: 'PKR Amount Received'),
            const SectionHeader('Source Details'),

            if (_sourceType == 'Upwork' || _sourceType == 'Fiverr')
              upworkAsync.when(
                data: (accounts) {
                  final targetPlatform = _sourceType == 'Upwork' ? 'upwork' : 'fiverr';
                  final filtered = accounts.where((a) => a.platform == targetPlatform).toList();
                  final dropdownItems = _upworkAccount != null && !filtered.contains(_upworkAccount)
                      ? [...filtered, _upworkAccount!]
                      : filtered;

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<UpworkAccount>(
                          value: _upworkAccount,
                          decoration: InputDecoration(
                            labelText: _sourceType == 'Upwork' ? 'Upwork Account' : 'Fiverr Account',
                            border: const OutlineInputBorder(),
                          ),
                          items: dropdownItems.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                          onChanged: (v) => setState(() => _upworkAccount = v),
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
                error: (_, __) => Text('Could not load $_sourceType accounts'),
              ),

            if (_sourceType == 'Front Sale') ...[
              projectsAsync.when(
                data: (projects) {
                  final dropdownItems = _project != null && !projects.contains(_project)
                      ? [...projects, _project!]
                      : projects;
                  return DropdownButtonFormField<dynamic>(
                    value: _project,
                    decoration: InputDecoration(
                      labelText: 'Project / Client',
                      border: const OutlineInputBorder(),
                      suffixIcon: _project == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _project = null),
                            ),
                    ),
                    items: dropdownItems.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (v) => setState(() => _project = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load projects'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clientNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Client Name (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('Salesperson (optional) — employee linking available once directory loads',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],

            if (_sourceType == 'Direct Client')
              TextFormField(
                controller: _clientNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Client / Project', border: OutlineInputBorder()),
              ),

            if (_sourceType == 'PayPal' || _sourceType == 'Other')
              const Text('No additional fields required for this source type.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),

            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
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
            const SectionHeader('Screenshot / Proof'),
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
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.editId != null ? 'Save Changes' : 'Save Cash In'),
            ),
          ],
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
}
