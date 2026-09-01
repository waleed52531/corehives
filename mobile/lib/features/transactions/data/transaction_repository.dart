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
  Future<void> softDelete(String txId, String deletedByUserId) async {
    if (txId.startsWith('payroll_payment_')) {
      final paymentId = txId.replaceFirst('payroll_payment_', '');
      await _db.runTransaction((transaction) async {
        final paymentRef = _db.collection('payroll_payments').doc(paymentId);
        final paymentSnap = await transaction.get(paymentRef);

        if (paymentSnap.exists) {
          final payment = paymentSnap.data()!;
          final payrollEntryId = payment['payrollEntryId'] as String?;
          final amountPaisa = (payment['amountPaisa'] as num?)?.toInt() ?? 0;

          if (payrollEntryId != null) {
            final entryRef = _db.collection('payroll_entries').doc(payrollEntryId);
            final entrySnap = await transaction.get(entryRef);

            if (entrySnap.exists) {
              final entry = entrySnap.data()!;
              final currentPaid = (entry['totalPaidAmountPaisa'] ?? 0) as int;
              final expected = (entry['expectedAmountPaisa'] ?? 0) as int;
              final newTotalPaid = (currentPaid - amountPaisa) < 0 ? 0 : (currentPaid - amountPaisa);
              final newRemaining = expected - newTotalPaid;
              final newStatus = newTotalPaid <= 0
                  ? 'Pending'
                  : newTotalPaid >= expected
                      ? 'Paid'
                      : 'Partial';

              transaction.update(entryRef, {
                'totalPaidAmountPaisa': newTotalPaid,
                'remainingAmountPaisa': newRemaining,
                'status': newStatus,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
          transaction.delete(paymentRef);
        }

        final txRef = _col.doc(txId);
        transaction.update(txRef, {
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedByUserId': deletedByUserId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      await _col.doc(txId).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedByUserId': deletedByUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

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
