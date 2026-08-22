import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/auth_providers.dart';
import 'employee_providers.dart';

class EmployeeDirectoryScreen extends ConsumerStatefulWidget {
  const EmployeeDirectoryScreen({super.key});
  @override
  ConsumerState<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends ConsumerState<EmployeeDirectoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(allEmployeesProvider);
    final user = ref.watch(currentAppUserProvider).value;
    final canManage = user != null && user.can((p) => p.manageEmployees);

    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => context.push('/add-employee'),
              tooltip: 'Add Employee',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search name, code, job title...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load employees: $e')),
              data: (employees) {
                final filtered = employees.where((e) {
                  if (_search.isEmpty) return true;
                  return '${e.fullName} ${e.employeeCode} ${e.jobTitle}'.toLowerCase().contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No employees found.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(e.fullName.isNotEmpty ? e.fullName[0] : '?')),
                      title: Text(e.fullName),
                      subtitle: Text('${e.jobTitle} · ${e.employeeCode}'),
                      trailing: Chip(
                        label: Text(e.employmentStatus, style: const TextStyle(fontSize: 11)),
                        backgroundColor: e.employmentStatus == 'Active'
                            ? const Color(0xFFDFF5E7)
                            : const Color(0xFFF0F0F0),
                      ),
                      onTap: () => context.push('/employees/${e.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
