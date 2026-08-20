import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../shared/providers/auth_providers.dart';
import '../data/payroll_repository.dart';
import '../domain/payroll_models.dart';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instance);

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

final payrollEntriesForMonthProvider = StreamProvider.family<List<PayrollEntry>, String>((ref, monthKey) {
  return ref.watch(payrollRepositoryProvider).entriesForMonth(monthKey);
});

final payrollPaymentsForEntryProvider = StreamProvider.family<List<PayrollPayment>, String>((ref, entryId) {
  return ref.watch(payrollRepositoryProvider).paymentsForEntry(entryId);
});
