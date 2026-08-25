import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String transactionId;
  final String type;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.transactionId,
    required this.type,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? createdAtDate;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      createdAtDate = rawCreated.toDate();
    }
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      createdAt: createdAtDate ?? DateTime.now(),
      read: data['read'] ?? false,
      transactionId: data['transactionId'] ?? '',
      type: data['type'] ?? '',
    );
  }
}
