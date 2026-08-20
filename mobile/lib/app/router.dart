import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

import '../features/profile/presentation/profile_screen.dart';

import '../shared/providers/auth_providers.dart';

import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final appUserState = ref.watch(currentAppUserProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final firebaseUser = authState.asData?.value;
      final appUser = appUserState.asData?.value;

      final location = state.matchedLocation;

      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isForgotPassword = location == '/forgot-password';

      // ============================================================
      // 1. Firebase is still determining authentication state.
      // ============================================================

      if (authState.isLoading) {
        return isSplash ? null : '/splash';
      }

      // ============================================================
      // 2. Firebase Authentication failed.
      // ============================================================

      if (authState.hasError) {
        if (isLogin || isForgotPassword) {
          return null;
        }

        return '/login';
      }

      // ============================================================
      // 3. User is signed out.
      // ============================================================

      if (firebaseUser == null) {
        if (isLogin || isForgotPassword) {
          return null;
        }

        return '/login';
      }

      // ============================================================
      // 4. Firebase user exists, but Firestore user profile
      //    is still loading.
      // ============================================================

      if (appUserState.isLoading) {
        return isSplash ? null : '/splash';
      }

      // ============================================================
      // 5. Firestore profile failed.
      // ============================================================

      if (appUserState.hasError) {
        return isSplash ? null : '/splash';
      }

      // ============================================================
      // 6. Firestore profile hasn't been created/read yet.
      // ============================================================

      if (appUser == null) {
        return isSplash ? null : '/splash';
      }

      // ============================================================
      // 7. CRITICAL USER-SWITCH GUARD
      //
      // Never allow User B into Home while Riverpod still contains
      // User A's Firestore profile.
      // ============================================================

      if (appUser.uid != firebaseUser.uid) {
        return isSplash ? null : '/splash';
      }

      // ============================================================
      // 8. Firebase Auth and Firestore profile match.
      // ============================================================

      if (isSplash || isLogin || isForgotPassword) {
        return '/home';
      }

      return null;
    },
    routes: [
      // ============================================================
      // AUTH
      // ============================================================

      GoRoute(
        path: '/splash',
        builder: (context, state) {
          return const SplashScreen();
        },
      ),

      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const LoginScreen();
        },
      ),

      GoRoute(
        path: '/forgot-password',
        builder: (context, state) {
          return const ForgotPasswordScreen();
        },
      ),

      // ============================================================
      // FULL-SCREEN ROUTES
      // ============================================================

      GoRoute(
        path: '/add-expense',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return const AddExpenseScreen();
        },
      ),

      GoRoute(
        path: '/add-cash-in',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return const AddCashInScreen();
        },
      ),

      GoRoute(
        path: '/transactions/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return TransactionDetailScreen(
            transactionId: state.pathParameters['id']!,
          );
        },
      ),

      GoRoute(
        path: '/payroll/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return PayrollEntryDetailScreen(
            entryId: state.pathParameters['id']!,
          );
        },
      ),

      GoRoute(
        path: '/employees',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return const EmployeeDirectoryScreen();
        },
      ),

      GoRoute(
        path: '/employees/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return EmployeeDetailScreen(
            employeeId: state.pathParameters['id']!,
          );
        },
      ),

      // ============================================================
      // BOTTOM NAVIGATION
      // ============================================================

      StatefulShellRoute.indexedStack(
        builder: (
          context,
          state,
          navigationShell,
        ) {
          return AppShell(
            currentIndex: navigationShell.currentIndex,
            onTabSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            child: navigationShell,
          );
        },
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) {
                  return const HomeScreen();
                },
              ),
            ],
          ),

          // Transactions
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) {
                  return const TransactionsScreen();
                },
              ),
            ],
          ),

          // Payroll
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payroll',
                builder: (context, state) {
                  return const PayrollScreen();
                },
              ),
            ],
          ),

          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) {
                  return const ProfileScreen();
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
