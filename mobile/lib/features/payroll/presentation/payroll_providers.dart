import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_providers.dart';
import '../data/payroll_repository.dart';
import '../domain/payroll_models.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final payrollEntriesForMonthProvider =
    StreamProvider.autoDispose.family<List<PayrollEntry>, String>(
  (ref, monthKey) {
    final uid = ref.watch(authorizedUidProvider);
    final appUserState = ref.watch(currentAppUserProvider);
    final appUser = appUserState.asData?.value;

    // User transition in progress.
    if (uid == null || appUser == null) {
      return Stream.value(
        const <PayrollEntry>[],
      );
    }

    // Don't make a query Firestore rules will reject.
    final canViewPayroll = appUser.isAdmin || appUser.permissions.viewPayroll;

    if (!canViewPayroll) {
      return Stream.value(
        const <PayrollEntry>[],
      );
    }

    return ref.watch(payrollRepositoryProvider).entriesForMonth(monthKey);
  },
);

final payrollPaymentsForEntryProvider =
    StreamProvider.autoDispose.family<List<PayrollPayment>, String>(
  (ref, entryId) {
    final uid = ref.watch(authorizedUidProvider);
    final appUserState = ref.watch(currentAppUserProvider);
    final appUser = appUserState.asData?.value;

    if (uid == null || appUser == null) {
      return Stream.value(
        const <PayrollPayment>[],
      );
    }

    final canViewPayroll = appUser.isAdmin || appUser.permissions.viewPayroll;

    if (!canViewPayroll) {
      return Stream.value(
        const <PayrollPayment>[],
      );
    }

    return ref.watch(payrollRepositoryProvider).paymentsForEntry(entryId);
  },
);
