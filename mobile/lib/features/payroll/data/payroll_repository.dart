import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/payroll_models.dart';

class PayrollRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  PayrollRepository(this._db, this._functions);

  Stream<List<PayrollEntry>> entriesForMonth(String monthKey) {
    return _db
        .collection('payroll_entries')
        .where('monthKey', isEqualTo: monthKey)
        .orderBy('employeeName')
        .snapshots()
        .map((s) => s.docs.map((d) => PayrollEntry.fromMap(d.id, d.data())).toList());
  }

  Stream<List<PayrollPayment>> paymentsForEntry(String payrollEntryId) {
    return _db
        .collection('payroll_payments')
        .where('payrollEntryId', isEqualTo: payrollEntryId)
        .orderBy('paymentDateKey', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PayrollPayment.fromMap(d.id, d.data())).toList());
  }

  /// All privileged payroll writes go through callable Cloud Functions —
  /// never direct client writes — for idempotency + audit guarantees.

  Future<void> generatePayroll(String monthKey) async {
    final callable = _functions.httpsCallable('generatePayroll');
    await callable.call({'monthKey': monthKey});
  }

  /// paymentId should be client-generated (e.g. Firestore auto-id string)
  /// and passed consistently on retry so the Function can dedupe.
  Future<void> recordPayrollPayment({
    required String payrollEntryId,
    required String paymentId,
    required int amountPaisa,
    required String paymentDateKey,
    String? paymentMethod,
    String? receiptUrl,
    String? receiptStoragePath,
    String? notes,
  }) async {
    final callable = _functions.httpsCallable('recordPayrollPayment');
    await callable.call({
      'payrollEntryId': payrollEntryId,
      'paymentId': paymentId,
      'amountPaisa': amountPaisa,
      'paymentDateKey': paymentDateKey,
      'paymentMethod': paymentMethod,
      'receiptUrl': receiptUrl,
      'receiptStoragePath': receiptStoragePath,
      'notes': notes,
    });
  }

  String newPaymentId() => _db.collection('payroll_payments').doc().id;
}
