import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/services/notification_service.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../config/presentation/config_providers.dart';

const _appVersion = '0.1.0 (V1)';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: userState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load profile.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _capitalizeWords(user.name),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user.email,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Chip(
                  label: Text(
                    user.role,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card_outlined),
                title: const Text('Platform IDs'),
                subtitle: const Text('Manage Upwork, Fiverr & Freelancer IDs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/platform-ids'),
              ),
              FutureBuilder<String?>(
                future: NotificationService.getDeviceToken(),
                builder: (context, snapshot) {
                  final token = snapshot.data;
                  if (token == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('FCM Push Token'),
                    subtitle: Text(
                      token,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.copy_outlined),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('FCM Token copied to clipboard')),
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.invalidate(authStateProvider);
                  ref.invalidate(currentAppUserProvider);
                  ref.invalidate(transactionsForMonthProvider);
                  ref.invalidate(activeDepartmentsProvider);
                  ref.invalidate(activeExpenseCategoriesProvider);
                  ref.invalidate(activeProjectsProvider);
                  ref.invalidate(activePayeesProvider);
                  ref.invalidate(activeUpworkAccountsProvider);
                  ref.invalidate(activeRevenueSourcesProvider);
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'App Version $_appVersion',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _capitalizeWords(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final success = await showDialog<bool>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );

    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != _passCtrl.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  if (!_formKey.currentState!.validate()) return;
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  try {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null) {
                      await currentUser.updatePassword(_passCtrl.text);
                      navigator.pop(true);
                    } else {
                      setState(() {
                        _error = 'User is not logged in';
                        _loading = false;
                      });
                    }
                  } on FirebaseAuthException catch (e) {
                    setState(() {
                      if (e.code == 'requires-recent-login') {
                        _error = 'Please log out and log back in to perform this action.';
                      } else {
                        _error = e.message ?? 'Failed to update password';
                      }
                      _loading = false;
                    });
                  } catch (e) {
                    setState(() {
                      _error = 'Failed to update password: $e';
                      _loading = false;
                    });
                  }
                },
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
