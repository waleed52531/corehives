import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../features/transactions/presentation/transaction_detail_screen.dart';
import '../features/transactions/presentation/add_expense_screen.dart';
import '../features/transactions/presentation/add_cash_in_screen.dart';
import '../features/payroll/presentation/payroll_screen.dart';
import '../features/payroll/presentation/payroll_entry_detail_screen.dart';
import '../features/employees/presentation/employee_directory_screen.dart';
import '../features/employees/presentation/employee_detail_screen.dart';
import '../features/employees/presentation/add_employee_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/config/presentation/platform_ids_screen.dart';
import '../features/transactions/presentation/pending_reimbursements_screen.dart';
import '../shared/providers/auth_providers.dart';
import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggedIn = authState.value != null;
      final location = state.matchedLocation;

      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isForgotPassword = location == '/forgot-password';

      // Firebase is still checking authentication.
      if (authState.isLoading) {
        return isSplash ? null : '/splash';
      }

      // User is not logged in.
      if (!loggedIn) {
        // Allow login and forgot-password screens.
        if (isLogin || isForgotPassword) {
          return null;
        }

        // Including when currently on splash.
        return '/login';
      }

      // User is already logged in.
      if (isSplash || isLogin || isForgotPassword) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),

      // Full-screen routes pushed on top of the shell (not part of bottom nav).
      GoRoute(
        path: '/add-expense',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => AddExpenseScreen(editId: s.uri.queryParameters['editId']),
      ),
      GoRoute(
        path: '/add-cash-in',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => AddCashInScreen(editId: s.uri.queryParameters['editId']),
      ),
      GoRoute(
        path: '/transactions/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => TransactionDetailScreen(transactionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/payroll/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => PayrollEntryDetailScreen(entryId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/employees', parentNavigatorKey: _rootNavigatorKey, builder: (c, s) => const EmployeeDirectoryScreen()),
      GoRoute(
        path: '/employees/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => EmployeeDetailScreen(employeeId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/add-employee',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const AddEmployeeScreen(),
      ),
      GoRoute(
        path: '/platform-ids',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const PlatformIdsScreen(),
      ),
      GoRoute(
        path: '/pending-reimbursements',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const PendingReimbursementsScreen(),
      ),

      // Bottom-nav shell routes.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          return AppShell(
            currentIndex: shell.currentIndex,
            onTabSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            child: shell,
          );
        },
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/transactions', builder: (c, s) => const TransactionsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/payroll', builder: (c, s) => const PayrollScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen())]),
        ],
      ),
    ],
  );
});
