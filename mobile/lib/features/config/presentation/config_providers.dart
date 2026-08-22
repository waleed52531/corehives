import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_providers.dart';

import '../data/config_repository.dart';
import '../domain/config_models.dart';

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository(
    ref.watch(firestoreProvider),
  );
});

final activeDepartmentsProvider =
    StreamProvider.autoDispose<List<Department>>((ref) {
  final uid = ref.watch(authorizedUidProvider);

  if (uid == null) {
    return Stream.value(
      const <Department>[],
    );
  }

  return ref.watch(configRepositoryProvider).activeDepartments();
});

final activeExpenseCategoriesProvider =
    StreamProvider.autoDispose<List<ExpenseCategory>>(
  (ref) {
    final uid = ref.watch(authorizedUidProvider);

    if (uid == null) {
      return Stream.value(
        const <ExpenseCategory>[],
      );
    }

    return ref.watch(configRepositoryProvider).activeExpenseCategories();
  },
);

final activeSubcategoriesProvider =
    StreamProvider.autoDispose.family<List<ExpenseSubcategory>, String>(
  (ref, categoryId) {
    final uid = ref.watch(authorizedUidProvider);

    if (uid == null) {
      return Stream.value(
        const <ExpenseSubcategory>[],
      );
    }

    return ref.watch(configRepositoryProvider).activeSubcategoriesForCategory(
          categoryId,
        );
  },
);

final activeProjectsProvider = StreamProvider.autoDispose<List<Project>>((ref) {
  final uid = ref.watch(authorizedUidProvider);

  if (uid == null) {
    return Stream.value(
      const <Project>[],
    );
  }

  return ref.watch(configRepositoryProvider).activeProjects();
});

final activePayeesProvider = StreamProvider.autoDispose<List<Payee>>((ref) {
  final uid = ref.watch(authorizedUidProvider);

  if (uid == null) {
    return Stream.value(
      const <Payee>[],
    );
  }

  return ref.watch(configRepositoryProvider).activePayees();
});

final activeUpworkAccountsProvider =
    StreamProvider.autoDispose<List<UpworkAccount>>(
  (ref) {
    final uid = ref.watch(authorizedUidProvider);

    if (uid == null) {
      return Stream.value(
        const <UpworkAccount>[],
      );
    }

    return ref.watch(configRepositoryProvider).activeUpworkAccounts();
  },
);

final activeRevenueSourcesProvider =
    StreamProvider.autoDispose<List<RevenueSource>>(
  (ref) {
    final uid = ref.watch(authorizedUidProvider);

    if (uid == null) {
      return Stream.value(
        const <RevenueSource>[],
      );
    }

    return ref.watch(configRepositoryProvider).activeRevenueSources();
  },
);

final activeBanksProvider = StreamProvider.autoDispose<List<Bank>>((ref) {
  final uid = ref.watch(authorizedUidProvider);

  if (uid == null) {
    return Stream.value(
      const <Bank>[],
    );
  }

  return ref.watch(configRepositoryProvider).activeBanks();
});
