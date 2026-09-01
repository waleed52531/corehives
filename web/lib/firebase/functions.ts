import { getFunctions, httpsCallable } from "firebase/functions";
import { app } from "./client";

const functions = getFunctions(app);

export async function generatePayroll(monthKey: string) {
  const fn = httpsCallable(functions, "generatePayroll");
  const res = await fn({ monthKey });
  return res.data as { status: string; monthKey: string; entriesCreated?: number };
}

export async function recordPayrollPayment(input: {
  payrollEntryId: string;
  paymentId: string;
  amountPaisa: number;
  paymentDateKey: string;
  paymentMethod?: string;
  receiptUrl?: string;
  receiptStoragePath?: string;
  notes?: string;
  confirmOverpayment?: boolean;
}) {
  const fn = httpsCallable(functions, "recordPayrollPayment");
  const res = await fn(input);
  return res.data as { status: string; linkedTransactionId: string };
}

export async function deletePayrollPayment(paymentId: string) {
  const fn = httpsCallable(functions, "deletePayrollPayment");
  const res = await fn({ paymentId });
  return res.data as { status: string; paymentId: string; newTotalPaid: number; newRemaining: number; newStatus: string };
}

export async function updatePayrollEntryExpected(entryId: string, expectedAmountPaisa: number) {
  const fn = httpsCallable(functions, "updatePayrollEntryExpected");
  const res = await fn({ entryId, expectedAmountPaisa });
  return res.data as { status: string; entryId: string; expectedAmountPaisa: number; remainingAmountPaisa: number };
}

export async function closeMonth(monthKey: string) {
  const fn = httpsCallable(functions, "closeMonth");
  const res = await fn({ monthKey });
  return res.data as { status: string; monthKey: string };
}

export async function reopenMonth(monthKey: string, reason: string) {
  const fn = httpsCallable(functions, "reopenMonth");
  const res = await fn({ monthKey, reason });
  return res.data as { status: string; monthKey: string };
}

export async function updateEmployeeCompensation(input: {
  employeeId: string;
  baseSalaryPaisa: number;
  compensationType: string;
  defaultPaymentMethod?: string;
  effectiveFrom: string;
}) {
  const fn = httpsCallable(functions, "updateEmployeeCompensation");
  const res = await fn(input);
  return res.data as { status: string; employeeId: string };
}
