class Department {
  final String id;
  final String name;
  final bool active;
  final int? order;

  Department({required this.id, required this.name, required this.active, this.order});

  factory Department.fromMap(String id, Map<String, dynamic> m) => Department(
        id: id,
        name: m['name'] ?? '',
        active: m['active'] ?? false,
        order: m['order'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Department && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ExpenseCategory {
  final String id;
  final String name;
  final bool active;
  final int order;

  ExpenseCategory({required this.id, required this.name, required this.active, required this.order});

  factory ExpenseCategory.fromMap(String id, Map<String, dynamic> m) => ExpenseCategory(
        id: id,
        name: m['name'] ?? '',
        active: m['active'] ?? false,
        order: m['order'] ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ExpenseSubcategory {
  final String id;
  final String categoryId;
  final String name;
  final bool active;
  final int order;

  ExpenseSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.active,
    required this.order,
  });

  factory ExpenseSubcategory.fromMap(String id, Map<String, dynamic> m) => ExpenseSubcategory(
        id: id,
        categoryId: m['categoryId'] ?? '',
        name: m['name'] ?? '',
        active: m['active'] ?? false,
        order: m['order'] ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseSubcategory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum ProjectType { company, internalProduct, clientProject, other }

ProjectType projectTypeFromString(String s) {
  switch (s) {
    case 'Company':
      return ProjectType.company;
    case 'Internal Product':
      return ProjectType.internalProduct;
    case 'Client Project':
      return ProjectType.clientProject;
    default:
      return ProjectType.other;
  }
}

class Project {
  final String id;
  final String name;
  final ProjectType type;
  final bool active;
  final String? notes;

  Project({required this.id, required this.name, required this.type, required this.active, this.notes});

  factory Project.fromMap(String id, Map<String, dynamic> m) => Project(
        id: id,
        name: m['name'] ?? '',
        type: projectTypeFromString(m['type'] ?? 'Other'),
        active: m['active'] ?? false,
        notes: m['notes'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Payee {
  final String id;
  final String name;
  final String? employeeId;
  final String? type;
  final bool active;

  Payee({required this.id, required this.name, this.employeeId, this.type, required this.active});

  factory Payee.fromMap(String id, Map<String, dynamic> m) => Payee(
        id: id,
        name: m['name'] ?? '',
        employeeId: m['employeeId'],
        type: m['type'],
        active: m['active'] ?? false,
      );
}

class UpworkAccount {
  final String id;
  final String name;
  final bool active;
  final String? platform; // 'upwork' | 'fiverr' | 'freelancer'
  final String? notes;
  final String? ownerName; // 'Ishtiaq' | 'Zain' | 'Hanzalah'

  UpworkAccount({
    required this.id,
    required this.name,
    required this.active,
    this.platform,
    this.notes,
    this.ownerName,
  });

  factory UpworkAccount.fromMap(String id, Map<String, dynamic> m) => UpworkAccount(
        id: id,
        name: m['name'] ?? '',
        active: m['active'] ?? false,
        platform: m['platform'] ?? 'upwork',
        notes: m['notes'],
        ownerName: m['ownerName'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpworkAccount && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class RevenueSource {
  final String id;
  final String name;
  final bool active;
  final int? order;

  RevenueSource({required this.id, required this.name, required this.active, this.order});

  factory RevenueSource.fromMap(String id, Map<String, dynamic> m) => RevenueSource(
        id: id,
        name: m['name'] ?? '',
        active: m['active'] ?? false,
        order: m['order'],
      );
}

class Bank {
  final String id;
  final String name;
  final bool active;

  Bank({required this.id, required this.name, required this.active});

  factory Bank.fromMap(String id, Map<String, dynamic> m) => Bank(
        id: id,
        name: m['name'] ?? '',
        active: m['active'] ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bank && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
