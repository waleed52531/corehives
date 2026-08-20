export type PayrollStatus = "Pending" | "Partial" | "Paid" | "Skipped";

export interface PayrollEntry {
  id: string; // {monthKey}_{employeeId}
  employeeId: string;
  employeeName: string;
  monthKey: string;
  expectedAmountPaisa: number;
  totalPaidAmountPaisa: number;
  remainingAmountPaisa: number;
  currency: "PKR";
  compensationType: string;
  status: PayrollStatus;
  notes?: string;
  generatedAt: unknown;
  generatedByUserId: string;
  updatedAt: unknown;
}

export interface PayrollPayment {
  id: string;
  payrollEntryId: string;
  employeeId: string;
  employeeName: string;
  amountPaisa: number;
  currency: "PKR";
  paymentDateKey: string;
  paidByUserId: string;
  paidByUserName: string;
  paymentMethod?: string;
  receiptUrl?: string | null;
  receiptStoragePath?: string | null;
  notes?: string;
  linkedTransactionId: string;
  createdAt: unknown;
  createdByUserId: string;
}

export interface MonthlyClosing {
  monthKey: string;
  status: "open" | "closed";
  closedAt?: unknown;
  closedByUserId?: string;
  closedByName?: string;
  reopenedAt?: unknown;
  reopenedByUserId?: string;
  reopenReason?: string;
  notes?: string;
}
