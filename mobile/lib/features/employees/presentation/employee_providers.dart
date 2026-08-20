import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_providers.dart';

import '../data/employee_repository.dart';
import '../domain/employee_model.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(
    ref.watch(firestoreProvider),
  );
});

final allEmployeesProvider = StreamProvider.autoDispose<List<Employee>>((ref) {
  final uid = ref.watch(authorizedUidProvider);

  final appUserState = ref.watch(currentAppUserProvider);

  final appUser = appUserState.asData?.value;

  if (uid == null || appUser == null) {
    return Stream.value(
      const <Employee>[],
    );
  }

  final canViewEmployees = appUser.isAdmin || appUser.permissions.viewEmployees;

  if (!canViewEmployees) {
    return Stream.value(
      const <Employee>[],
    );
  }

  return ref.watch(employeeRepositoryProvider).all();
});
