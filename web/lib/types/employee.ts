export interface Employee {
  id: string;
  employeeCode: string;
  fullName: string;
  profilePhotoUrl?: string | null;
  profilePhotoStoragePath?: string | null;
  jobTitle: string;
  departmentId?: string;
  employmentType: string;
  employmentStatus: "Active" | "Inactive" | "On Leave" | "Resigned" | "Terminated";
  personalEmail?: string;
  companyEmail?: string;
  phoneNumber?: string;
  whatsappNumber?: string;
  currentAddress?: string;
  emergencyContactName?: string;
  emergencyContactPhone?: string;
  joiningDate?: string;
  probationEndDate?: string;
  reportingManagerEmployeeId?: string;
  workLocation?: string;
  shiftTiming?: string;
  lastWorkingDate?: string | null;
  leavingReason?: string | null;
  notes?: string;
  createdAt: unknown;
  createdByUserId: string;
  updatedAt: unknown;
  updatedByUserId: string;
}

export interface EmployeeCompensation {
  employeeId: string;
  baseSalaryPaisa: number;
  currency: "PKR";
  compensationType: string;
  defaultPaymentMethod?: string;
  effectiveFrom: string;
  updatedAt: unknown;
  updatedBy: string;
}

export interface EmployeeCompensationHistory {
  id: string;
  employeeId: string;
  baseSalaryPaisa: number;
  currency: "PKR";
  compensationType: string;
  effectiveFrom: string;
  effectiveTo: string;
  changedAt: unknown;
  changedByUserId: string;
}
