class AppUserPermissions {
  final bool viewPayroll;
  final bool managePayroll;
  final bool viewEmployees;
  final bool manageEmployees;
  final bool viewReports;

  const AppUserPermissions({
    this.viewPayroll = false,
    this.managePayroll = false,
    this.viewEmployees = false,
    this.manageEmployees = false,
    this.viewReports = false,
  });

  factory AppUserPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppUserPermissions();
    return AppUserPermissions(
      viewPayroll: map['viewPayroll'] ?? false,
      managePayroll: map['managePayroll'] ?? false,
      viewEmployees: map['viewEmployees'] ?? false,
      manageEmployees: map['manageEmployees'] ?? false,
      viewReports: map['viewReports'] ?? false,
    );
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // 'admin' | 'member'
  final AppUserPermissions permissions;
  final bool active;
  final String? employeeId;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.active,
    this.employeeId,
  });

  bool get isAdmin => role == 'admin';

  // Admins implicitly have all permissions.
  bool can(bool Function(AppUserPermissions) check) => isAdmin || check(permissions);

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        role: map['role'] ?? 'member',
        permissions: AppUserPermissions.fromMap(map['permissions']),
        active: map['active'] ?? false,
        employeeId: map['employeeId'],
      );
}
