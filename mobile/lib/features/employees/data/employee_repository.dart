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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String newDocId() {
    return _db.collection('employees').doc().id;
  }
}
