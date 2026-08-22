import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/payroll_models.dart';

class PayrollRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  PayrollRepository(this._db, this._auth);

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

  /// All privileged payroll writes go directly to Firestore using client-side 
  /// transactions and batches (bypassing Cloud Functions to support the free Spark plan).

  Future<int> generatePayroll(String monthKey) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Unauthenticated");

    // Fetch active employees
    final employeesSnap = await _db
        .collection('employees')
        .where('employmentStatus', isEqualTo: 'Active')
        .get();

    final batch = _db.batch();
    int createdCount = 0;

    for (final empDoc in employeesSnap.docs) {
      final employeeId = empDoc.id;
      final employee = empDoc.data();
      final compSnap = await _db.collection('employee_compensation').doc(employeeId).get();
      final comp = compSnap.data();
      if (comp == null) continue; // skip if no compensation set

      final entryId = '${monthKey}_$employeeId';
      final entryRef = _db.collection('payroll_entries').doc(entryId);
      final existing = await entryRef.get();
      if (existing.exists) continue;

      batch.set(entryRef, {
        'id': entryId,
        'employeeId': employeeId,
        'employeeName': employee['fullName'],
        'monthKey': monthKey,
        'expectedAmountPaisa': comp['baseSalaryPaisa'],
        'totalPaidAmountPaisa': 0,
        'remainingAmountPaisa': comp['baseSalaryPaisa'],
        'currency': 'PKR',
        'compensationType': comp['compensationType'],
        'status': 'Pending',
        'notes': '',
        'generatedAt': FieldValue.serverTimestamp(),
        'generatedByUserId': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      createdCount++;
    }

    if (createdCount > 0) {
      // Mark the month as generated
      final monthDocRef = _db.collection('payroll_months').doc(monthKey);
      batch.set(monthDocRef, {
        'monthKey': monthKey,
        'generatedAt': FieldValue.serverTimestamp(),
        'generatedByUserId': uid,
      }, SetOptions(merge: true));

      await batch.commit();
    }

    return createdCount;
  }

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
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Unauthenticated");

    // Fetch the user's name
    final userSnap = await _db.collection('users').doc(uid).get();
    final userName = userSnap.data()?['name'] ?? 'System';

    final monthKey = paymentDateKey.substring(0, 7);

    // Check if month is closed
    final closingSnap = await _db.collection('monthly_closings').doc(monthKey).get();
    if (closingSnap.exists && closingSnap.data()?['status'] == 'closed') {
      throw Exception("Month $monthKey is closed. Reopen it before recording payments.");
    }

    final linkedTxId = 'payroll_payment_$paymentId';

    await _db.runTransaction((transaction) async {
      final paymentRef = _db.collection('payroll_payments').doc(paymentId);
      final paymentSnap = await transaction.get(paymentRef);
      if (paymentSnap.exists) {
        return; // Already recorded
      }

      final entryRef = _db.collection('payroll_entries').doc(payrollEntryId);
      final entrySnap = await transaction.get(entryRef);
      if (!entrySnap.exists) {
        throw Exception("Payroll entry not found.");
      }
      final entry = entrySnap.data()!;

      final newTotalPaid = (entry['totalPaidAmountPaisa'] ?? 0) + amountPaisa;
      final newRemaining = (entry['expectedAmountPaisa'] ?? 0) - newTotalPaid;
      final newStatus = newTotalPaid <= 0
          ? 'Pending'
          : newTotalPaid >= (entry['expectedAmountPaisa'] ?? 0)
              ? 'Paid'
              : 'Partial';

      // 1. Record the payment
      transaction.set(paymentRef, {
        'id': paymentId,
        'payrollEntryId': payrollEntryId,
        'employeeId': entry['employeeId'],
        'employeeName': entry['employeeName'],
        'amountPaisa': amountPaisa,
        'currency': 'PKR',
        'paymentDateKey': paymentDateKey,
        'paidByUserId': uid,
        'paidByUserName': userName,
        'paymentMethod': paymentMethod,
        'receiptUrl': receiptUrl,
        'receiptStoragePath': receiptStoragePath,
        'notes': notes ?? '',
        'linkedTransactionId': linkedTxId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUserId': uid,
      });

      // 2. Update entry status and totals
      transaction.update(entryRef, {
        'totalPaidAmountPaisa': newTotalPaid,
        'remainingAmountPaisa': newRemaining,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Upsert linked expense transaction
      final txRef = _db.collection('transactions').doc(linkedTxId);
      transaction.set(txRef, {
        'id': linkedTxId,
        'type': 'expense',
        'amountPaisa': amountPaisa,
        'currency': 'PKR',
        'categoryId': 'payroll-compensation',
        'categoryName': 'Payroll & Compensation',
        'subcategoryId': 'payroll-compensation__salary',
        'subcategoryName': 'Salary',
        'payeeId': null,
        'payeeName': entry['employeeName'],
        'employeeId': entry['employeeId'],
        'employeeName': entry['employeeName'],
        'paidByUserId': uid,
        'paidByUserName': userName,
        'paymentMethod': paymentMethod,
        'transactionDateKey': paymentDateKey,
        'monthKey': monthKey,
        'status': 'completed',
        'attachmentUrl': receiptUrl,
        'attachmentStoragePath': receiptStoragePath,
        'attachmentStatus': receiptUrl != null ? 'uploaded' : 'none',
        'description': 'Payroll payment — ${entry['employeeName']}',
        'notes': notes ?? '',
        'lateEntry': false,
        'createdByUserId': uid,
        'createdByName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deletedAt': null,
        'deletedByUserId': null,
      });
    });
  }

  String newPaymentId() => _db.collection('payroll_payments').doc().id;
}
