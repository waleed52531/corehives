import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
import 'package:intl/intl.dart';
import '../domain/employee_model.dart';
import 'employee_providers.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(allEmployeesProvider);
    final user = ref.watch(currentAppUserProvider).value;
    final canViewComp = user != null && user.can((p) => p.viewPayroll);

    return DefaultTabController(
      length: canViewComp ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Employee'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Overview'),
              const Tab(text: 'Employment'),
              if (canViewComp) const Tab(text: 'Compensation'),
            ],
          ),
        ),
        body: employeesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (employees) {
            final e = employees.where((x) => x.id == employeeId).firstOrNull;
            if (e == null) return const Center(child: Text('Employee not found.'));

            return TabBarView(
              children: [
                _OverviewTab(employee: e),
                _EmploymentTab(employee: e),
                if (canViewComp) _CompensationTab(employeeId: employeeId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Employee employee;
  const _OverviewTab({required this.employee});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            child: Text(employee.fullName.isNotEmpty ? employee.fullName[0] : '?', style: const TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(employee.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        Center(child: Text(employee.jobTitle, style: const TextStyle(color: Colors.grey))),
        const SectionHeader('Contact'),
        _row(
          'Company Email',
          employee.companyEmail,
          icon: Icons.copy_outlined,
          onTap: employee.companyEmail != null && employee.companyEmail!.isNotEmpty
              ? () async {
                  await Clipboard.setData(ClipboardData(text: employee.companyEmail!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Company Email copied to clipboard')),
                    );
                  }
                }
              : null,
        ),
        _row(
          'Personal Email',
          employee.personalEmail,
          icon: Icons.copy_outlined,
          onTap: employee.personalEmail != null && employee.personalEmail!.isNotEmpty
              ? () async {
                  await Clipboard.setData(ClipboardData(text: employee.personalEmail!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Personal Email copied to clipboard')),
                    );
                  }
                }
              : null,
        ),
        _row(
          'Phone',
          employee.phoneNumber,
          onTap: employee.phoneNumber != null && employee.phoneNumber!.isNotEmpty
              ? () async {
                  await Clipboard.setData(ClipboardData(text: employee.phoneNumber!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number copied to clipboard')),
                    );
                  }
                }
              : null,
          onIconPressed: employee.phoneNumber != null && employee.phoneNumber!.isNotEmpty
              ? () async {
                  final cleanPhone = employee.phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
                  final uri = Uri.parse('tel:$cleanPhone');
                  try {
                    await launchUrl(uri);
                  } catch (e) {
                    debugPrint('Could not launch dialer: $e');
                  }
                }
              : null,
        ),
        _row(
          'WhatsApp',
          employee.whatsappNumber,
          icon: Icons.chat_bubble_outline,
          onTap: employee.whatsappNumber != null && employee.whatsappNumber!.isNotEmpty
              ? () async {
                  await Clipboard.setData(ClipboardData(text: employee.whatsappNumber!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('WhatsApp number copied to clipboard')),
                    );
                  }
                }
              : null,
          onIconPressed: employee.whatsappNumber != null && employee.whatsappNumber!.isNotEmpty
              ? () async {
                  var digits = employee.whatsappNumber!.replaceAll(RegExp(r'\D'), '');
                  if (digits.startsWith('03') && digits.length == 11) {
                    digits = '92${digits.substring(1)}';
                  }
                  if (digits.startsWith('3') && digits.length == 10) {
                    digits = '92$digits';
                  }
                  final uri = Uri.parse('https://wa.me/$digits');
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch WhatsApp URL: $e');
                  }
                }
              : null,
        ),
        _row('Address', employee.address),
        if (employee.bankName != null || employee.bankAccountOrIban != null) ...[
          const SectionHeader('Bank Account'),
          _row('Bank Name', employee.bankName),
          _row(
            'Account / IBAN',
            employee.bankAccountOrIban,
            icon: Icons.copy_outlined,
            onTap: employee.bankAccountOrIban != null && employee.bankAccountOrIban!.isNotEmpty
                ? () async {
                    await Clipboard.setData(ClipboardData(text: employee.bankAccountOrIban!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account / IBAN copied to clipboard')),
                      );
                    }
                  }
                : null,
          ),
        ],
        if (employee.emergencyContactName != null || employee.emergencyContactPhone != null) ...[
          const SectionHeader('Emergency Contact'),
          _row('Name', employee.emergencyContactName),
          _row(
            'Phone',
            employee.emergencyContactPhone,
            onTap: employee.emergencyContactPhone != null && employee.emergencyContactPhone!.isNotEmpty
                ? () async {
                    await Clipboard.setData(ClipboardData(text: employee.emergencyContactPhone!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Emergency phone copied to clipboard')),
                      );
                    }
                  }
                : null,
            onIconPressed: employee.emergencyContactPhone != null && employee.emergencyContactPhone!.isNotEmpty
                ? () async {
                    final cleanPhone = employee.emergencyContactPhone!.replaceAll(RegExp(r'[^\d+]'), '');
                    final uri = Uri.parse('tel:$cleanPhone');
                    try {
                      await launchUrl(uri);
                    } catch (e) {
                      debugPrint('Could not launch emergency dialer: $e');
                    }
                  }
                : null,
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.push('/add-employee', extra: employee),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Employee Details'),
        ),
      ],
    );
  }

  Widget _row(String label, String? value, {VoidCallback? onTap, VoidCallback? onIconPressed, IconData? icon}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(value),
          ),
          if (onIconPressed != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(icon ?? Icons.phone_outlined, size: 20, color: Colors.blue),
              onPressed: onIconPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmploymentTab extends ConsumerWidget {
  final Employee employee;
  const _EmploymentTab({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).value;
    final canManage = user != null && user.can((p) => p.manageEmployees);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row('Employee Code', employee.employeeCode),
        _row('Employment Type', employee.employmentType),
        _row(
          'Employment Status',
          employee.employmentStatus,
          trailing: canManage
              ? SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: BorderSide(color: employee.employmentStatus == 'Active' ? Colors.red : Colors.green),
                    ),
                    onPressed: () async {
                      final newStatus = employee.employmentStatus == 'Active' ? 'Inactive' : 'Active';
                      await ref.read(employeeRepositoryProvider).updateEmploymentStatus(employee.id, newStatus);
                    },
                    child: Text(
                      employee.employmentStatus == 'Active' ? 'Mark Inactive' : 'Mark Active',
                      style: TextStyle(color: employee.employmentStatus == 'Active' ? Colors.red : Colors.green, fontSize: 12),
                    ),
                  ),
                )
              : null,
        ),
        _row('Joining Date', employee.joiningDate),
        _row('Work Location', employee.workLocation),
        _row('Shift Timing', employee.shiftTiming),
        _row('Notes', employee.notes),
      ],
    );
  }

  Widget _row(String label, String? value, {Widget? trailing}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}

class _CompensationTab extends ConsumerWidget {
  final String employeeId;
  const _CompensationTab({required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<EmployeeCompensation?>(
      stream: ref.watch(employeeRepositoryProvider).compensationStream(employeeId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final comp = snap.data;
        if (comp == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No compensation record set.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showEditSalaryDialog(context, ref, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Salary'),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('Current Compensation'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoneyText(paisa: comp.baseSalaryPaisa, isCashIn: false, fontSize: 22),
                    const SizedBox(height: 8),
                    Text(comp.compensationType, style: const TextStyle(color: Colors.grey)),
                    if (comp.effectiveFrom != null) Text('Effective from ${comp.effectiveFrom}'),
                    if (comp.defaultPaymentMethod != null) Text('Default method: ${comp.defaultPaymentMethod}'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Salary',
                  onPressed: () => _showEditSalaryDialog(context, ref, comp),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showEditSalaryDialog(BuildContext context, WidgetRef ref, EmployeeCompensation? currentComp) {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(
      text: currentComp != null ? (currentComp.baseSalaryPaisa / 100).toStringAsFixed(0) : '',
    );
    String compType = currentComp?.compensationType ?? 'Salary';
    String payMethod = currentComp?.defaultPaymentMethod ?? 'bank';
    DateTime effectiveDate = currentComp?.effectiveFrom != null
        ? (DateTime.tryParse(currentComp!.effectiveFrom!) ?? DateTime.now())
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(currentComp == null ? 'Add Salary' : 'Edit Salary'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        decoration: const InputDecoration(
                          labelText: 'Monthly Salary (PKR)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = int.tryParse(v.trim());
                          if (val == null || val <= 0) return 'Must be a positive number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: compType,
                        decoration: const InputDecoration(
                          labelText: 'Compensation Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Salary', child: Text('Salary')),
                          DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                          DropdownMenuItem(value: 'Hourly', child: Text('Hourly')),
                          DropdownMenuItem(value: 'Commission', child: Text('Commission')),
                        ],
                        onChanged: (v) => setDialogState(() => compType = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: payMethod,
                        decoration: const InputDecoration(
                          labelText: 'Default Payment Method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'bank', child: Text('Bank')),
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        ],
                        onChanged: (v) => setDialogState(() => payMethod = v!),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Effective From'),
                        subtitle: Text(DateFormat('yyyy-MM-dd').format(effectiveDate)),
                        trailing: const Icon(Icons.calendar_today, size: 18),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: effectiveDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => effectiveDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final amountVal = int.parse(amountCtrl.text.trim());
                      final newComp = EmployeeCompensation(
                        employeeId: employeeId,
                        baseSalaryPaisa: amountVal * 100,
                        currency: 'PKR',
                        compensationType: compType,
                        defaultPaymentMethod: payMethod,
                        effectiveFrom: DateFormat('yyyy-MM-dd').format(effectiveDate),
                      );

                      await ref.read(employeeRepositoryProvider).saveCompensation(newComp);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
