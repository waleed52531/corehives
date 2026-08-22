import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../config/presentation/config_providers.dart';
import '../../config/domain/config_models.dart';
import '../domain/employee_model.dart';
import 'employee_providers.dart';

class AddEmployeeScreen extends ConsumerStatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  ConsumerState<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends ConsumerState<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _compEmailCtrl = TextEditingController();
  final _persEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  Department? _department;
  String _employmentType = 'Full-time';
  String _employmentStatus = 'Active';
  String _workLocation = 'On-site';
  String _shiftTiming = '12 PM to 9 PM';
  DateTime? _joiningDate;
  bool _saving = false;

  final _employmentTypes = ['Full-time', 'Part-time', 'Contractor', 'Intern'];
  final _employmentStatuses = ['Active', 'Inactive'];
  final _workLocations = ['On-site', 'Remote'];
  final _shiftTimings = [
    '12 PM to 9 PM',
    '3 PM to 12 AM',
    '6 PM to 3 AM',
    '9 PM to 6 AM'
  ];

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _compEmailCtrl.dispose();
    _persEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _notesCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final user = ref.read(currentAppUserProvider).value;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final repo = ref.read(employeeRepositoryProvider);
    final docId = repo.newDocId();

    final employee = Employee(
      id: docId,
      employeeCode: _codeCtrl.text.trim(),
      fullName: _nameCtrl.text.trim(),
      jobTitle: _titleCtrl.text.trim(),
      departmentId: _department?.id,
      employmentType: _employmentType,
      employmentStatus: _employmentStatus,
      companyEmail: _compEmailCtrl.text.trim().isEmpty ? null : _compEmailCtrl.text.trim(),
      personalEmail: _persEmailCtrl.text.trim().isEmpty ? null : _persEmailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      whatsappNumber: _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
      joiningDate: _joiningDate != null
          ? "${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}"
          : null,
      workLocation: _workLocation,
      shiftTiming: _shiftTiming,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      emergencyContactName: _emergencyNameCtrl.text.trim().isEmpty ? null : _emergencyNameCtrl.text.trim(),
      emergencyContactPhone: _emergencyPhoneCtrl.text.trim().isEmpty ? null : _emergencyPhoneCtrl.text.trim(),
    );

    try {
      await repo.create(employee);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee added successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save employee: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(activeDepartmentsProvider);
    final employees = ref.watch(allEmployeesProvider).value;

    // Auto-generate employee code if empty
    if (employees != null && _codeCtrl.text.isEmpty) {
      int maxNum = 0;
      for (final e in employees) {
        final code = e.employeeCode;
        final match = RegExp(r'CH-(\d+)').firstMatch(code);
        if (match != null) {
          final numVal = int.tryParse(match.group(1) ?? '');
          if (numVal != null && numVal > maxNum) {
            maxNum = numVal;
          }
        }
      }
      _codeCtrl.text = 'CH-${(maxNum + 1).toString().padLeft(3, '0')}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(labelText: 'Employee Code', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Job Title', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            deptsAsync.when(
              data: (depts) => DropdownButtonFormField<Department>(
                value: _department,
                decoration: const InputDecoration(labelText: 'Department (optional)', border: OutlineInputBorder()),
                items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                onChanged: (v) => setState(() => _department = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load departments'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _employmentType,
                    decoration: const InputDecoration(labelText: 'Employment Type', border: OutlineInputBorder()),
                    items: _employmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _employmentType = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _employmentStatus,
                    decoration: const InputDecoration(labelText: 'Employment Status', border: OutlineInputBorder()),
                    items: _employmentStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _employmentStatus = v!),
                  ),
                ),
              ],
            ),
            const SectionHeader('Contact Info'),
            TextFormField(
              controller: _compEmailCtrl,
              decoration: const InputDecoration(labelText: 'Company Email (optional)', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _persEmailCtrl,
              decoration: const InputDecoration(labelText: 'Personal Email (optional)', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _whatsappCtrl,
                    decoration: const InputDecoration(labelText: 'WhatsApp (optional)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Home Address (optional)', border: OutlineInputBorder()),
            ),
            const SectionHeader('Emergency Contact'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emergencyNameCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Name (optional)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _emergencyPhoneCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Phone (optional)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SectionHeader('Deployment Details'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Joining Date'),
              subtitle: Text(_joiningDate == null
                  ? 'Select date'
                  : "${_joiningDate!.year}-${_joiningDate!.month.toString().padLeft(2, '0')}-${_joiningDate!.day.toString().padLeft(2, '0')}"),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _joiningDate = picked);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _workLocation,
                    decoration: const InputDecoration(labelText: 'Work Location', border: OutlineInputBorder()),
                    items: _workLocations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _workLocation = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _shiftTiming,
                    decoration: const InputDecoration(labelText: 'Shift Timing', border: OutlineInputBorder()),
                    items: _shiftTimings.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _shiftTiming = v!),
                  ),
                ),
              ],
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
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Employee'),
            ),
          ],
        ),
      ),
    );
  }
}
