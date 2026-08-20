export interface AppUserPermissions {
  viewPayroll: boolean;
  managePayroll: boolean;
  viewEmployees: boolean;
  manageEmployees: boolean;
  viewReports: boolean;
}

export type AppRole = "admin" | "member";

export interface AppUser {
  uid: string;
  name: string;
  email: string;
  role: AppRole;
  permissions: AppUserPermissions;
  active: boolean;
  employeeId?: string | null;
}

/** Admins implicitly have every permission. */
export function can(user: AppUser, key: keyof AppUserPermissions): boolean {
  return user.role === "admin" || user.permissions[key] === true;
}
