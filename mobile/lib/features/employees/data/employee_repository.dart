import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../domain/employee_model.dart';

class EmployeeRepository {
  final FirebaseFirestore _db;
  EmployeeRepository(this._db);

  Stream<List<Employee>> all() => _db
      .collection('employees')
      .orderBy('fullName')
      .snapshots()
      .map((s) => s.docs.map((d) => Employee.fromMap(d.id, d.data())).toList());

  /// Rules restrict this read to users with viewPayroll permission —
  /// a permission-denied error here means the UI should hide compensation,
  /// not surface a raw Firestore error.
  Future<EmployeeCompensation?> compensationFor(String employeeId) async {
    final doc = await _db.collection('employee_compensation').doc(employeeId).get();
    if (!doc.exists) return null;
    return EmployeeCompensation.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateEmploymentStatus(String employeeId, String status) async {
    await _db.collection('employees').doc(employeeId).update({
      'employmentStatus': status,
    });
  }

  Future<void> create(Employee employee) async {
    await _db.collection('employees').doc(employee.id).set({
      'employeeCode': employee.employeeCode,
      'fullName': employee.fullName,
      'jobTitle': employee.jobTitle,
      'departmentId': employee.departmentId,
      'employmentType': employee.employmentType,
      'employmentStatus': employee.employmentStatus,
      'companyEmail': employee.companyEmail,
      'personalEmail': employee.personalEmail,
      'phoneNumber': employee.phoneNumber,
      'whatsappNumber': employee.whatsappNumber,
      'joiningDate': employee.joiningDate,
      'reportingManagerEmployeeId': employee.reportingManagerEmployeeId,
      'workLocation': employee.workLocation,
      'shiftTiming': employee.shiftTiming,
      'notes': employee.notes,
      'address': employee.address,
      'emergencyContactName': employee.emergencyContactName,
      'emergencyContactPhone': employee.emergencyContactPhone,
      'emergencyContactRelation': employee.emergencyContactRelation,
      'bankName': employee.bankName,
      'bankAccountOrIban': employee.bankAccountOrIban,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(Employee employee) async {
    await _db.collection('employees').doc(employee.id).set({
      'employeeCode': employee.employeeCode,
      'fullName': employee.fullName,
      'jobTitle': employee.jobTitle,
      'departmentId': employee.departmentId,
      'employmentType': employee.employmentType,
      'employmentStatus': employee.employmentStatus,
      'companyEmail': employee.companyEmail,
      'personalEmail': employee.personalEmail,
      'phoneNumber': employee.phoneNumber,
      'whatsappNumber': employee.whatsappNumber,
      'joiningDate': employee.joiningDate,
      'reportingManagerEmployeeId': employee.reportingManagerEmployeeId,
      'workLocation': employee.workLocation,
      'shiftTiming': employee.shiftTiming,
      'notes': employee.notes,
      'address': employee.address,
      'emergencyContactName': employee.emergencyContactName,
      'emergencyContactPhone': employee.emergencyContactPhone,
      'emergencyContactRelation': employee.emergencyContactRelation,
      'bankName': employee.bankName,
      'bankAccountOrIban': employee.bankAccountOrIban,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String newDocId() {
    return _db.collection('employees').doc().id;
  }

  Stream<EmployeeCompensation?> compensationStream(String employeeId) {
    return _db.collection('employee_compensation').doc(employeeId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return EmployeeCompensation.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> saveCompensation(EmployeeCompensation comp) async {
    final effectiveFrom = comp.effectiveFrom ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Try Cloud Function first (which runs with admin privileges)
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('updateEmployeeCompensation');
      await callable.call({
        'employeeId': comp.employeeId,
        'baseSalaryPaisa': comp.baseSalaryPaisa,
        'compensationType': comp.compensationType,
        'defaultPaymentMethod': comp.defaultPaymentMethod,
        'effectiveFrom': effectiveFrom,
      });
      return;
    } catch (_) {
      // Fallback to direct client write
    }

    await _db.collection('employee_compensation').doc(comp.employeeId).set({
      'employeeId': comp.employeeId,
      'baseSalaryPaisa': comp.baseSalaryPaisa,
      'currency': comp.currency,
      'compensationType': comp.compensationType,
      'defaultPaymentMethod': comp.defaultPaymentMethod,
      'effectiveFrom': effectiveFrom,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also auto-sync open current month's payroll entry if it already exists
    final now = DateTime.now();
    final currentMonthKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final entryId = '${currentMonthKey}_${comp.employeeId}';

    final closingSnap = await _db.collection('monthly_closings').doc(currentMonthKey).get();
    if (closingSnap.exists && closingSnap.data()?['status'] == 'closed') {
      return; // Do not modify closed month
    }

    final entryRef = _db.collection('payroll_entries').doc(entryId);
    final entrySnap = await entryRef.get();
    if (entrySnap.exists) {
      final entryData = entrySnap.data()!;
      final totalPaid = (entryData['totalPaidAmountPaisa'] ?? 0) as int;
      final newRemaining = comp.baseSalaryPaisa - totalPaid;
      final newStatus = totalPaid <= 0
          ? 'Pending'
          : totalPaid >= comp.baseSalaryPaisa
              ? 'Paid'
              : 'Partial';

      await entryRef.update({
        'expectedAmountPaisa': comp.baseSalaryPaisa,
        'remainingAmountPaisa': newRemaining,
        'status': newStatus,
        'compensationType': comp.compensationType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
