import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../domain/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _db;

  TransactionRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('transactions');

  /// Creates a transaction with a client-generated doc id so we can attach
  /// the receipt under receipts/{year}/{month}/{transactionId}/{fileName}
  /// before or after the Firestore write without a race.
  DocumentReference<Map<String, dynamic>> newDocRef() => _col.doc();

  Future<void> create(Transaction tx) => _col.doc(tx.id).set(tx.toCreateMap());

  Future<void> updateAttachment({
    required String txId,
    required String url,
    required String storagePath,
    required AttachmentStatus status,
  }) =>
      _col.doc(txId).update({
        'attachmentUrl': url,
        'attachmentStoragePath': storagePath,
        'attachmentStatus': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> markAttachmentFailed(String txId) => _col.doc(txId).update({
        'attachmentStatus': AttachmentStatus.failed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> update(String txId, Map<String, dynamic> changes) => _col.doc(txId).update({
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Soft delete — never hard-delete financial history.
  Future<void> softDelete(String txId, String deletedByUserId) => _col.doc(txId).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedByUserId': deletedByUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Transaction>> forMonth(String monthKey, {int limit = 200}) {
    return _col
        .where('monthKey', isEqualTo: monthKey)
        .where('deletedAt', isNull: true)
        .orderBy('transactionDateKey', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Transaction.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Transaction>> recentForMonth(String monthKey, {int limit = 10}) {
    return forMonth(monthKey, limit: limit);
  }

  Future<Transaction?> byId(String txId) async {
    final doc = await _col.doc(txId).get();
    if (!doc.exists) return null;
    return Transaction.fromMap(doc.id, doc.data()!);
  }

  Stream<Transaction?> streamById(String txId) {
    return _col.doc(txId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Transaction.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<Transaction>> activeSince(String dateKey) {
    return _col
        .where('deletedAt', isNull: true)
        .where('transactionDateKey', isGreaterThanOrEqualTo: dateKey)
        .snapshots()
        .map((s) => s.docs.map((d) => Transaction.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Transaction>> pendingCashIns() {
    return _col
        .where('type', isEqualTo: 'cash_in')
        .where('status', isEqualTo: 'pending')
        .where('deletedAt', isNull: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Transaction.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Transaction>> pendingReimbursements() {
    return _col
        .where('type', isEqualTo: 'expense')
        .where('status', isEqualTo: 'pending')
        .where('deletedAt', isNull: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Transaction.fromMap(d.id, d.data())).toList());
  }
}
