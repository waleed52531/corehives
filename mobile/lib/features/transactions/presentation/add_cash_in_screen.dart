import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/receipt_picker.dart';
import '../../../shared/models/month_key.dart';
import '../../config/presentation/config_providers.dart';
import '../domain/transaction_model.dart';
import '../presentation/transaction_providers.dart';

const _sourceTypes = ['Upwork', 'Front Sale', 'PayPal', 'Direct Client', 'Fiverr', 'Other'];

class AddCashInScreen extends ConsumerStatefulWidget {
  const AddCashInScreen({super.key});
  @override
  ConsumerState<AddCashInScreen> createState() => _AddCashInScreenState();
}

class _AddCashInScreenState extends ConsumerState<AddCashInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _sourceType = 'Upwork';
  dynamic _upworkAccount;
  dynamic _project;
  dynamic _salespersonEmployee;
  DateTime _date = DateTime.now();
  String _status = 'Completed';
  File? _receiptFile;
  double? _uploadProgress;
  bool _uploadFailed = false;
  bool _saving = false;

  static const _statuses = ['Pending', 'Completed', 'Failed', 'Cancelled'];

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_sourceType == 'Upwork' && _upworkAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an Upwork account')));
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
      type: TxType.cashIn,
      sourceType: _sourceType,
      amountPaisa: amountPaisa,
      upworkAccountId: _sourceType == 'Upwork' ? _upworkAccount?.id : null,
      upworkAccountName: _sourceType == 'Upwork' ? _upworkAccount?.name : null,
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
      appBar: AppBar(title: const Text('Add Cash In')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _sourceType,
              decoration: const InputDecoration(labelText: 'Source Type', border: OutlineInputBorder()),
              items: _sourceTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _sourceType = v!),
            ),
            const SizedBox(height: 12),
            AmountField(controller: _amountCtrl, label: 'PKR Amount Received'),
            const SectionHeader('Source Details'),

            if (_sourceType == 'Upwork')
              upworkAsync.when(
                data: (accounts) => DropdownButtonFormField(
                  value: _upworkAccount,
                  decoration: const InputDecoration(labelText: 'Upwork Account', border: OutlineInputBorder()),
                  items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _upworkAccount = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load Upwork accounts'),
              ),

            if (_sourceType == 'Front Sale') ...[
              projectsAsync.when(
                data: (projects) => DropdownButtonFormField(
                  value: _project,
                  decoration: const InputDecoration(labelText: 'Project / Client', border: OutlineInputBorder()),
                  items: projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (v) => setState(() => _project = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load projects'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clientNameCtrl,
                decoration: const InputDecoration(labelText: 'Client Name (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('Salesperson (optional) — employee linking available once directory loads',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],

            if (_sourceType == 'Direct Client')
              TextFormField(
                controller: _clientNameCtrl,
                decoration: const InputDecoration(labelText: 'Client / Project', border: OutlineInputBorder()),
              ),

            if (_sourceType == 'PayPal' || _sourceType == 'Fiverr' || _sourceType == 'Other')
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
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Cash In'),
            ),
          ],
        ),
      ),
    );
  }
}
