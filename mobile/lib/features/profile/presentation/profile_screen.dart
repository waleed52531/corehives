import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_providers.dart';

const _appVersion = '0.1.0 (V1)';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(user?.name.isNotEmpty == true ? user!.name[0] : '?', style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(user?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text(user?.email ?? '', style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 4),
          Center(
            child: Chip(label: Text(user?.role ?? '', style: const TextStyle(fontSize: 12))),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (user == null) return;
              await ref.read(authRepositoryProvider).sendPasswordReset(user.email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset email sent.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          const SizedBox(height: 32),
          Center(child: Text('App Version $_appVersion', style: const TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }
}
