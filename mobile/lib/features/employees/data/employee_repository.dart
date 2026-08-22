import 'package:cloud_firestore/cloud_firestore.dart';
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
    await _db.collection('employee_compensation').doc(comp.employeeId).set({
      'baseSalaryPaisa': comp.baseSalaryPaisa,
      'currency': comp.currency,
      'compensationType': comp.compensationType,
      'defaultPaymentMethod': comp.defaultPaymentMethod,
      'effectiveFrom': comp.effectiveFrom,
    }, SetOptions(merge: true));
  }
}
