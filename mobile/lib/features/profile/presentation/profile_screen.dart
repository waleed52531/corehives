import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_providers.dart';
import '../../config/presentation/config_providers.dart';
import '../../employees/presentation/employee_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';

const _appVersion = '0.1.0 (V1)';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final userState = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: userState.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load profile.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (user) {
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user.email,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Chip(
                  label: Text(
                    user.role,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                ),
                title: const Text(
                  'Change Password',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () async {
                  try {
                    await ref.read(authRepositoryProvider).sendPasswordReset(
                          user.email,
                        );

                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password reset email sent.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Unable to send password reset email: $e',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  await ref
                      .read(authRepositoryProvider)
                      .signOut();

                  ref.invalidate(authStateProvider);
                  ref.invalidate(currentAppUserProvider);

                  ref.invalidate(transactionsForMonthProvider);

                  ref.invalidate(activeDepartmentsProvider);
                  ref.invalidate(activeExpenseCategoriesProvider);
                  ref.invalidate(activeProjectsProvider);
                  ref.invalidate(activePayeesProvider);
                  ref.invalidate(activeUpworkAccountsProvider);
                  ref.invalidate(activeRevenueSourcesProvider);

                  ref.invalidate(allEmployeesProvider);
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'App Version $_appVersion',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
