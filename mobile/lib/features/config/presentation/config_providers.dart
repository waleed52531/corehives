import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_providers.dart';
import '../data/config_repository.dart';
import '../domain/config_models.dart';

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository(ref.watch(firestoreProvider));
});

final activeDepartmentsProvider = StreamProvider<List<Department>>((ref) {
  return ref.watch(configRepositoryProvider).activeDepartments();
});

final activeExpenseCategoriesProvider = StreamProvider<List<ExpenseCategory>>((ref) {
  return ref.watch(configRepositoryProvider).activeExpenseCategories();
});

/// Family provider — pass the selected categoryId to get its active subcategories.
/// Usage: ref.watch(activeSubcategoriesProvider(categoryId))
final activeSubcategoriesProvider =
    StreamProvider.family<List<ExpenseSubcategory>, String>((ref, categoryId) {
  return ref.watch(configRepositoryProvider).activeSubcategoriesForCategory(categoryId);
});

final activeProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(configRepositoryProvider).activeProjects();
});

final activePayeesProvider = StreamProvider<List<Payee>>((ref) {
  return ref.watch(configRepositoryProvider).activePayees();
});

final activeUpworkAccountsProvider = StreamProvider<List<UpworkAccount>>((ref) {
  return ref.watch(configRepositoryProvider).activeUpworkAccounts();
});

final activeRevenueSourcesProvider = StreamProvider<List<RevenueSource>>((ref) {
  return ref.watch(configRepositoryProvider).activeRevenueSources();
});
