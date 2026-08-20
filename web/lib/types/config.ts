export interface AuditFields {
  createdAt: unknown; // Firestore Timestamp
  createdByUserId: string;
  updatedAt: unknown;
  updatedByUserId: string;
}

export interface Department extends AuditFields {
  id: string;
  name: string;
  active: boolean;
  order?: number;
}

export interface ExpenseCategory extends AuditFields {
  id: string;
  name: string;
  active: boolean;
  order: number;
}

export interface ExpenseSubcategory extends AuditFields {
  id: string;
  categoryId: string;
  name: string;
  active: boolean;
  order: number;
}

export type ProjectType = "Company" | "Internal Product" | "Client Project" | "Other";

export interface Project extends AuditFields {
  id: string;
  name: string;
  type: ProjectType;
  active: boolean;
  notes?: string;
}

export type PayeeType = "employee" | "contractor" | "vendor" | "service provider" | "other";

export interface Payee extends AuditFields {
  id: string;
  name: string;
  employeeId?: string | null;
  type?: PayeeType;
  active: boolean;
}

export interface UpworkAccount extends AuditFields {
  id: string;
  name: string;
  active: boolean;
  notes?: string;
}

export interface RevenueSource extends AuditFields {
  id: string;
  name: string;
  active: boolean;
  order?: number;
}
