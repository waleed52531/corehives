import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_providers.dart';
import '../domain/config_models.dart';
import 'config_providers.dart';

class PlatformIdsScreen extends ConsumerStatefulWidget {
  const PlatformIdsScreen({super.key});

  @override
  ConsumerState<PlatformIdsScreen> createState() => _PlatformIdsScreenState();
}

class _PlatformIdsScreenState extends ConsumerState<PlatformIdsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _platform = 'upwork';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    _nameCtrl.clear();
    setState(() {
      _platform = 'upwork';
      _saving = false;
    });

    String ownerName = 'Ishtiaq';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Platform ID'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Account Name / ID',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _platform,
                      decoration: const InputDecoration(
                        labelText: 'Platform Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'upwork', child: Text('Upwork')),
                        DropdownMenuItem(value: 'fiverr', child: Text('Fiverr')),
                        DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => _platform = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ownerName,
                      decoration: const InputDecoration(
                        labelText: 'Owner / User',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Ishtiaq', child: Text('Ishtiaq')),
                        DropdownMenuItem(value: 'Zain', child: Text('Zain')),
                        DropdownMenuItem(value: 'Hanzalah', child: Text('Hanzalah')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => ownerName = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setDialogState(() => _saving = true);

                          final user = ref.read(currentAppUserProvider).value;
                          if (user == null) {
                            setDialogState(() => _saving = false);
                            return;
                          }

                          try {
                            await ref.read(configRepositoryProvider).addUpworkAccount(
                                  name: _nameCtrl.text.trim(),
                                  platform: _platform,
                                  userId: user.uid,
                                  userName: user.name,
                                  ownerName: ownerName,
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Platform ID added successfully')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to add ID: $e')),
                              );
                            }
                          } finally {
                            setDialogState(() => _saving = false);
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(UpworkAccount account) {
    _nameCtrl.text = account.name;
    setState(() => _saving = false);
    String ownerName = account.ownerName ?? 'Ishtiaq';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Platform ID'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Account Name / ID',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ownerName,
                      decoration: const InputDecoration(
                        labelText: 'Owner / User',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Ishtiaq', child: Text('Ishtiaq')),
                        DropdownMenuItem(value: 'Zain', child: Text('Zain')),
                        DropdownMenuItem(value: 'Hanzalah', child: Text('Hanzalah')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => ownerName = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setDialogState(() => _saving = true);

                          final user = ref.read(currentAppUserProvider).value;
                          if (user == null) {
                            setDialogState(() => _saving = false);
                            return;
                          }

                          try {
                            await ref.read(configRepositoryProvider).updateUpworkAccount(
                                  id: account.id,
                                  name: _nameCtrl.text.trim(),
                                  userId: user.uid,
                                  userName: user.name,
                                  ownerName: ownerName,
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Platform ID updated successfully')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update: $e')),
                              );
                            }
                          } finally {
                            setDialogState(() => _saving = false);
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(UpworkAccount account) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Platform ID'),
          content: Text('Are you sure you want to delete "${account.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ref.read(configRepositoryProvider).deleteUpworkAccount(account.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Platform ID deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(List<UpworkAccount> accounts, String platform) {
    final filtered = accounts.where((a) => a.platform == platform).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No ${platform[0].toUpperCase()}${platform.substring(1)} IDs added yet.',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final account = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Owner: ${account.ownerName ?? 'Not Assigned'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditDialog(account),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(account),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformIdsAsync = ref.watch(activeUpworkAccountsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Platform IDs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upwork'),
              Tab(text: 'Fiverr'),
              Tab(text: 'Freelancer'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddDialog,
          child: const Icon(Icons.add),
        ),
        body: platformIdsAsync.when(
          data: (accounts) {
            return TabBarView(
              children: [
                _buildList(accounts, 'upwork'),
                _buildList(accounts, 'fiverr'),
                _buildList(accounts, 'freelancer'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
