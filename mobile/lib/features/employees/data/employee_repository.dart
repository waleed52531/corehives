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
}
