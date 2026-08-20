import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
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
        _row('Company Email', employee.companyEmail),
        _row('Personal Email', employee.personalEmail),
        _row('Phone', employee.phoneNumber),
        _row('WhatsApp', employee.whatsappNumber),
      ],
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmploymentTab extends StatelessWidget {
  final Employee employee;
  const _EmploymentTab({required this.employee});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row('Employee Code', employee.employeeCode),
        _row('Employment Type', employee.employmentType),
        _row('Employment Status', employee.employmentStatus),
        _row('Joining Date', employee.joiningDate),
        _row('Work Location', employee.workLocation),
        _row('Shift Timing', employee.shiftTiming),
        _row('Notes', employee.notes),
      ],
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
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
    return FutureBuilder<EmployeeCompensation?>(
      future: ref.read(employeeRepositoryProvider).compensationFor(employeeId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final comp = snap.data;
        if (comp == null) {
          return const Center(child: Text('No compensation record set.', style: TextStyle(color: Colors.grey)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('Current Compensation'),
            MoneyText(paisa: comp.baseSalaryPaisa, isCashIn: false, fontSize: 22),
            const SizedBox(height: 8),
            Text(comp.compensationType, style: const TextStyle(color: Colors.grey)),
            if (comp.effectiveFrom != null) Text('Effective from ${comp.effectiveFrom}'),
            if (comp.defaultPaymentMethod != null) Text('Default method: ${comp.defaultPaymentMethod}'),
          ],
        );
      },
    );
  }
}
