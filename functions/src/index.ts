import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

initializeApp();
const db = getFirestore();

interface AppUserDoc {
  active: boolean;
  role: "admin" | "member";
  name: string;
  permissions?: Record<string, boolean>;
}

async function getUser(uid: string | undefined): Promise<{ uid: string } & AppUserDoc> {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists || snap.data()?.active !== true) {
    throw new HttpsError("permission-denied", "Account inactive or not found.");
  }
  return { uid, ...(snap.data() as AppUserDoc) };
}

function can(user: AppUserDoc, permission: string): boolean {
  return user.role === "admin" || user.permissions?.[permission] === true;
}

async function requireAdmin(uid: string | undefined) {
  const user = await getUser(uid);
  if (user.role !== "admin") throw new HttpsError("permission-denied", "Admin access required.");
  return user;
}

async function requirePermission(uid: string | undefined, permission: string) {
  const user = await getUser(uid);
  if (!can(user, permission)) {
    throw new HttpsError("permission-denied", `Requires ${permission} permission.`);
  }
  return user;
}

function monthKeyFromDateKey(dateKey: string): string {
  const parts = dateKey.split("-");
  const year = parseInt(parts[0], 10);
  const month = parseInt(parts[1], 10);
  const day = parseInt(parts[2], 10);

  if (day >= 10) {
    let nextMonth = month + 1;
    let nextYear = year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear += 1;
    }
    return `${nextYear.toString().padStart(4, "0")}-${nextMonth.toString().padStart(2, "0")}`;
  } else {
    return `${year.toString().padStart(4, "0")}-${month.toString().padStart(2, "0")}`;
  }
}

/* ------------------------------------------------------------------ */
/* generatePayroll                                                     */
/* ------------------------------------------------------------------ */
export const generatePayroll = onCall(async (req) => {
  const user = await requirePermission(req.auth?.uid, "managePayroll");
  const { monthKey } = req.data as { monthKey: string };
  if (!monthKey || !/^\d{4}-\d{2}$/.test(monthKey)) {
    throw new HttpsError("invalid-argument", "monthKey must be YYYY-MM.");
  }

  const monthDocRef = db.collection("payroll_months").doc(monthKey);
  const monthDoc = await monthDocRef.get();
  if (monthDoc.exists) {
    return { status: "already_generated", monthKey };
  }

  // Load active employees whose compensation is set.
  const employeesSnap = await db
    .collection("employees")
    .where("employmentStatus", "==", "Active")
    .get();

  let createdCount = 0;
  const batch = db.batch();

  for (const empDoc of employeesSnap.docs) {
    const employeeId = empDoc.id;
    const employee = empDoc.data();
    const compSnap = await db.collection("employee_compensation").doc(employeeId).get();
    if (!compSnap.exists) continue; // no compensation set — skip, don't guess
    const comp = compSnap.data()!;

    const entryId = `${monthKey}_${employeeId}`;
    const entryRef = db.collection("payroll_entries").doc(entryId);
    const existing = await entryRef.get();
    if (existing.exists) continue; // idempotent — never duplicate

    batch.set(entryRef, {
      id: entryId,
      employeeId,
      employeeName: employee.fullName,
      monthKey,
      expectedAmountPaisa: comp.baseSalaryPaisa,
      totalPaidAmountPaisa: 0,
      remainingAmountPaisa: comp.baseSalaryPaisa,
      currency: "PKR",
      compensationType: comp.compensationType,
      status: "Pending",
      notes: "",
      generatedAt: FieldValue.serverTimestamp(),
      generatedByUserId: user.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    createdCount++;
  }

  batch.set(monthDocRef, {
    monthKey,
    generatedAt: FieldValue.serverTimestamp(),
    generatedByUserId: user.uid,
  });

  await batch.commit();
  return { status: "generated", monthKey, entriesCreated: createdCount };
});

/* ------------------------------------------------------------------ */
/* recordPayrollPayment                                                */
/* ------------------------------------------------------------------ */
export const recordPayrollPayment = onCall(async (req) => {
  const user = await requirePermission(req.auth?.uid, "managePayroll");
  const {
    payrollEntryId,
    paymentId,
    amountPaisa,
    paymentDateKey,
    paymentMethod,
    receiptUrl,
    receiptStoragePath,
    notes,
    confirmOverpayment,
  } = req.data as {
    payrollEntryId: string;
    paymentId: string;
    amountPaisa: number;
    paymentDateKey: string;
    paymentMethod?: string;
    receiptUrl?: string;
    receiptStoragePath?: string;
    notes?: string;
    confirmOverpayment?: boolean;
  };

  if (!payrollEntryId || !paymentId || !amountPaisa || amountPaisa <= 0 || !paymentDateKey) {
    throw new HttpsError("invalid-argument", "payrollEntryId, paymentId, amountPaisa, paymentDateKey required.");
  }

  const monthKey = monthKeyFromDateKey(paymentDateKey);
  const closingSnap = await db.collection("monthly_closings").doc(monthKey).get();
  if (closingSnap.exists && closingSnap.data()?.status === "closed") {
    throw new HttpsError("failed-precondition", `Month ${monthKey} is closed. Reopen it before recording payments.`);
  }

  const linkedTxId = `payroll_payment_${paymentId}`;

  const result = await db.runTransaction(async (tx) => {
    const paymentRef = db.collection("payroll_payments").doc(paymentId);
    const paymentSnap = await tx.get(paymentRef);
    if (paymentSnap.exists) {
      // Idempotent retry — already recorded, nothing to do.
      return { alreadyRecorded: true };
    }

    const entryRef = db.collection("payroll_entries").doc(payrollEntryId);
    const entrySnap = await tx.get(entryRef);
    if (!entrySnap.exists) throw new HttpsError("not-found", "Payroll entry not found.");
    const entry = entrySnap.data()!;

    const newTotalPaid = (entry.totalPaidAmountPaisa ?? 0) + amountPaisa;
    if (newTotalPaid > entry.expectedAmountPaisa && !confirmOverpayment) {
      throw new HttpsError(
        "failed-precondition",
        "This payment exceeds the expected amount. Retry with confirmOverpayment=true to proceed."
      );
    }

    const newRemaining = entry.expectedAmountPaisa - newTotalPaid;
    const newStatus = newTotalPaid <= 0 ? "Pending" : newTotalPaid >= entry.expectedAmountPaisa ? "Paid" : "Partial";

    // 1. Record the payment.
    tx.set(paymentRef, {
      id: paymentId,
      payrollEntryId,
      employeeId: entry.employeeId,
      employeeName: entry.employeeName,
      amountPaisa,
      currency: "PKR",
      paymentDateKey,
      paidByUserId: user.uid,
      paidByUserName: user.name,
      paymentMethod: paymentMethod ?? null,
      receiptUrl: receiptUrl ?? null,
      receiptStoragePath: receiptStoragePath ?? null,
      notes: notes ?? "",
      linkedTransactionId: linkedTxId,
      createdAt: FieldValue.serverTimestamp(),
      createdByUserId: user.uid,
    });

    // 2. Recompute entry totals + status.
    tx.update(entryRef, {
      totalPaidAmountPaisa: newTotalPaid,
      remainingAmountPaisa: newRemaining,
      status: newStatus,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // 3. Upsert exactly one linked expense transaction (deterministic id).
    const txRef = db.collection("transactions").doc(linkedTxId);
    tx.set(txRef, {
      id: linkedTxId,
      type: "expense",
      amountPaisa,
      currency: "PKR",
      categoryId: "payroll-compensation",
      categoryName: "Payroll & Compensation",
      subcategoryId: "payroll-compensation__salary",
      subcategoryName: "Salary",
      payeeId: null,
      payeeName: entry.employeeName,
      employeeId: entry.employeeId,
      employeeName: entry.employeeName,
      paidByUserId: user.uid,
      paidByUserName: user.name,
      paymentMethod: paymentMethod ?? null,
      transactionDateKey: paymentDateKey,
      monthKey,
      status: "completed",
      attachmentUrl: receiptUrl ?? null,
      attachmentStoragePath: receiptStoragePath ?? null,
      attachmentStatus: receiptUrl ? "uploaded" : "none",
      description: `Payroll payment — ${entry.employeeName}`,
      notes: notes ?? "",
      lateEntry: false,
      createdByUserId: user.uid,
      createdByName: user.name,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      deletedAt: null,
      deletedByUserId: null,
    });

    return { alreadyRecorded: false, newStatus, newTotalPaid, newRemaining };
  });

  return { status: "recorded", linkedTransactionId: linkedTxId, ...result };
});

/* ------------------------------------------------------------------ */
/* closeMonth / reopenMonth                                            */
/* ------------------------------------------------------------------ */
export const closeMonth = onCall(async (req) => {
  const user = await requireAdmin(req.auth?.uid);
  const { monthKey } = req.data as { monthKey: string };
  if (!monthKey || !/^\d{4}-\d{2}$/.test(monthKey)) {
    throw new HttpsError("invalid-argument", "monthKey must be YYYY-MM.");
  }

  await db.collection("monthly_closings").doc(monthKey).set(
    {
      monthKey,
      status: "closed",
      closedAt: FieldValue.serverTimestamp(),
      closedByUserId: user.uid,
      closedByName: user.name,
    },
    { merge: true }
  );
  return { status: "closed", monthKey };
});

export const reopenMonth = onCall(async (req) => {
  const user = await requireAdmin(req.auth?.uid);
  const { monthKey, reason } = req.data as { monthKey: string; reason?: string };
  if (!monthKey) throw new HttpsError("invalid-argument", "monthKey required.");
  if (!reason || !reason.trim()) {
    throw new HttpsError("invalid-argument", "A reopen reason is required for audit purposes.");
  }

  await db.collection("monthly_closings").doc(monthKey).set(
    {
      monthKey,
      status: "open",
      reopenedAt: FieldValue.serverTimestamp(),
      reopenedByUserId: user.uid,
      reopenReason: reason.trim(),
    },
    { merge: true }
  );
  return { status: "open", monthKey };
});

/* ------------------------------------------------------------------ */
/* updateEmployeeCompensation — preserves history, snapshots nothing   */
/* retroactively into already-generated payroll_entries.               */
/* ------------------------------------------------------------------ */
export const updateEmployeeCompensation = onCall(async (req) => {
  const user = await requirePermission(req.auth?.uid, "manageEmployees");
  const { employeeId, baseSalaryPaisa, compensationType, defaultPaymentMethod, effectiveFrom } = req.data as {
    employeeId: string;
    baseSalaryPaisa: number;
    compensationType: string;
    defaultPaymentMethod?: string;
    effectiveFrom: string; // YYYY-MM-DD
  };
  if (!employeeId || !baseSalaryPaisa || !compensationType || !effectiveFrom) {
    throw new HttpsError("invalid-argument", "employeeId, baseSalaryPaisa, compensationType, effectiveFrom required.");
  }

  const compRef = db.collection("employee_compensation").doc(employeeId);
  const currentSnap = await compRef.get();

  await db.runTransaction(async (tx) => {
    if (currentSnap.exists) {
      const current = currentSnap.data()!;
      const dayBefore = new Date(effectiveFrom);
      dayBefore.setUTCDate(dayBefore.getUTCDate() - 1);
      const effectiveTo = dayBefore.toISOString().slice(0, 10);

      const historyRef = db.collection("employee_compensation_history").doc();
      tx.set(historyRef, {
        id: historyRef.id,
        employeeId,
        baseSalaryPaisa: current.baseSalaryPaisa,
        currency: "PKR",
        compensationType: current.compensationType,
        effectiveFrom: current.effectiveFrom,
        effectiveTo,
        changedAt: FieldValue.serverTimestamp(),
        changedByUserId: user.uid,
      });
    }

    tx.set(compRef, {
      employeeId,
      baseSalaryPaisa,
      currency: "PKR",
      compensationType,
      defaultPaymentMethod: defaultPaymentMethod ?? null,
      effectiveFrom,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: user.uid,
    });
  });

  return { status: "updated", employeeId };
});
