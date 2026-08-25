import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../shared/providers/auth_providers.dart';
import '../domain/notification_model.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentAppUserProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => AppNotification.fromDoc(doc)).toList());
});

final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentAppUserProvider).value;
  if (user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _showUndoBanner = false;
  AppNotification? _lastDeletedNotification;
  Timer? _bannerTimer;

  Future<void> _markAsRead(String uid, String notifId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  Future<void> _markAllAsRead(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final unreadSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unreadSnap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _deleteNotification(String uid, String notifId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .delete();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).value;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (user != null)
            ref.watch(unreadNotificationsCountProvider).when(
                  data: (unreadCount) => unreadCount > 0
                      ? TextButton(
                          onPressed: () => _markAllAsRead(user.uid),
                          child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Could not load notifications: $err')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No notifications yet.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final dateStr = DateFormat('MMM dd, hh:mm a').format(item.createdAt);

                        return Dismissible(
                          key: Key(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade600,
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (direction) async {
                            await _deleteNotification(user.uid, item.id);
                            _bannerTimer?.cancel();
                            setState(() {
                              _lastDeletedNotification = item;
                              _showUndoBanner = true;
                            });
                            _bannerTimer = Timer(const Duration(seconds: 5), () {
                              if (mounted) {
                                setState(() {
                                  _showUndoBanner = false;
                                });
                              }
                            });
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.read ? Colors.grey.shade100 : Colors.blue.shade50,
                              child: Icon(
                                item.type == 'pending_withdrawal'
                                    ? Icons.pending_actions_outlined
                                    : (item.type == 'reimbursement_completed'
                                        ? Icons.assignment_turned_in_outlined
                                        : Icons.notifications_none_outlined),
                                color: item.read ? Colors.grey : Colors.blue,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.read ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(item.body, style: TextStyle(color: Colors.grey.shade800)),
                                const SizedBox(height: 4),
                                Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            trailing: !item.read
                                ? Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              // Mark as read
                              if (!item.read) {
                                await _markAsRead(user.uid, item.id);
                              }
                              
                              // Navigate to the transaction detail page
                              if (item.transactionId.isNotEmpty && context.mounted) {
                                context.push('/transactions/${item.transactionId}');
                              }
                            },
                          ),
                        );
                      },
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      bottom: _showUndoBanner ? 16 : -100,
                      left: 16,
                      right: 16,
                      child: _lastDeletedNotification == null
                          ? const SizedBox.shrink()
                          : Material(
                              elevation: 6,
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Deleted "${_lastDeletedNotification!.title}"',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final notif = _lastDeletedNotification!;
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .collection('notifications')
                                            .doc(notif.id)
                                            .set({
                                          'title': notif.title,
                                          'body': notif.body,
                                          'createdAt': notif.createdAt,
                                          'read': notif.read,
                                          'transactionId': notif.transactionId,
                                          'type': notif.type,
                                        });
                                        _bannerTimer?.cancel();
                                        setState(() {
                                          _showUndoBanner = false;
                                          _lastDeletedNotification = null;
                                        });
                                      },
                                      child: const Text(
                                        'Undo',
                                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
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
