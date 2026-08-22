import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/config_models.dart';

/// Read-only repository for active configuration records.
/// Phase 2 scope: mobile only reads what forms (Phase 3+) will need.
/// Full CRUD management lives in the Next.js admin app.
class ConfigRepository {
  final FirebaseFirestore _db;
  ConfigRepository(this._db);

  Stream<List<Department>> activeDepartments() => _db
      .collection('departments')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Department.fromMap(d.id, d.data())).toList());

  Stream<List<ExpenseCategory>> activeExpenseCategories() => _db
      .collection('expense_categories')
      .where('active', isEqualTo: true)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => ExpenseCategory.fromMap(d.id, d.data())).toList());

  Stream<List<ExpenseSubcategory>> activeSubcategoriesForCategory(String categoryId) => _db
      .collection('expense_subcategories')
      .where('categoryId', isEqualTo: categoryId)
      .where('active', isEqualTo: true)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => ExpenseSubcategory.fromMap(d.id, d.data())).toList());

  Stream<List<Project>> activeProjects() => _db
      .collection('projects')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Project.fromMap(d.id, d.data())).toList());

  Stream<List<Payee>> activePayees() => _db
      .collection('payees')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => Payee.fromMap(d.id, d.data())).toList());

  Stream<List<UpworkAccount>> activeUpworkAccounts() => _db
      .collection('upwork_accounts')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map(
        (s) => s.docs
        .map((d) => UpworkAccount.fromMap(d.id, d.data()))
        .toList(),
  );

  Stream<List<RevenueSource>> activeRevenueSources() => _db
      .collection('revenue_sources')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map((d) => RevenueSource.fromMap(d.id, d.data())).toList());

  Future<void> addUpworkAccount({
    required String name,
    required String platform,
    required String userId,
    required String userName,
    String? ownerName,
  }) async {
    final docId = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    await _db.collection('upwork_accounts').doc(docId).set({
      'name': name,
      'active': true,
      'platform': platform,
      'notes': '',
      'ownerName': ownerName,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUserId': userId,
      'createdByName': userName,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUserId': userId,
      'updatedByName': userName,
    });
  }

  Future<void> updateUpworkAccount({
    required String id,
    required String name,
    required String userId,
    required String userName,
    String? ownerName,
  }) async {
    await _db.collection('upwork_accounts').doc(id).update({
      'name': name,
      'ownerName': ownerName,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUserId': userId,
      'updatedByName': userName,
    });
  }

  Future<void> deleteUpworkAccount(String id) async {
    await _db.collection('upwork_accounts').doc(id).update({
      'active': false,
    });
  }
}
