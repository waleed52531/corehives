"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { doc, getDoc, updateDoc, serverTimestamp } from "firebase/firestore";
import { db, auth } from "@/lib/firebase/client";
import { paisaToDisplay } from "@/lib/utils/money";
import type { Transaction } from "@/lib/types/transaction";
import type { MonthlyClosing } from "@/lib/types/payroll";

export default function TransactionDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const [tx, setTx] = useState<Transaction | null>(null);
  const [closing, setClosing] = useState<MonthlyClosing | null>(null);
  const [loading, setLoading] = useState(true);
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    (async () => {
      const snap = await getDoc(doc(db, "transactions", params.id));
      if (snap.exists()) {
        const data = { ...(snap.data() as Omit<Transaction, "id">), id: snap.id };
        setTx(data);
        setNotes(data.notes ?? "");
        const closingSnap = await getDoc(doc(db, "monthly_closings", data.monthKey));
        setClosing(closingSnap.exists() ? (closingSnap.data() as MonthlyClosing) : null);
      }
      setLoading(false);
    })();
  }, [params.id]);

  const isClosed = closing?.status === "closed";

  async function saveNotes() {
    if (!tx) return;
    setSaving(true);
    try {
      await updateDoc(doc(db, "transactions", tx.id), {
        notes,
        updatedAt: serverTimestamp(),
      });
    } finally {
      setSaving(false);
    }
  }

  async function softDelete() {
    if (!tx) return;
    if (!confirm("Delete this transaction? It will be removed from reports but not permanently erased.")) return;
    
    if (tx.id.startsWith("payroll_payment_")) {
      const paymentId = tx.id.replace("payroll_payment_", "");
      try {
        const { deletePayrollPayment } = await import("@/lib/firebase/functions");
        await deletePayrollPayment(paymentId);
      } catch (err) {
        console.error("Failed to delete linked payroll payment:", err);
        // Fallback to direct soft delete if function is unavailable
        await updateDoc(doc(db, "transactions", tx.id), {
          deletedAt: serverTimestamp(),
          deletedByUserId: auth.currentUser?.uid ?? null,
          updatedAt: serverTimestamp(),
        });
      }
    } else {
      await updateDoc(doc(db, "transactions", tx.id), {
        deletedAt: serverTimestamp(),
        deletedByUserId: auth.currentUser?.uid ?? null,
        updatedAt: serverTimestamp(),
      });
    }
    router.push("/transactions");
  }

  if (loading) return <p className="p-6 text-sm text-neutral-500">Loading...</p>;
  if (!tx) return <p className="p-6 text-sm text-neutral-500">Transaction not found.</p>;

  const isCashIn = tx.type === "cash_in";

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs text-neutral-500">{isCashIn ? "Cash In" : "Expense"}</p>
          <p className={`text-2xl font-semibold ${isCashIn ? "text-emerald-700" : "text-red-600"}`}>
            {paisaToDisplay(tx.amountPaisa)}
          </p>
        </div>
        {tx.lateEntry && (
          <span className="rounded bg-orange-100 px-2 py-1 text-xs text-orange-700">Late Entry</span>
        )}
      </div>

      {isClosed && (
        <div className="rounded-md bg-orange-50 p-3 text-sm text-orange-700">
          This month is closed. Only admins can reopen it to make changes.
        </div>
      )}

      <div className="rounded-lg border border-neutral-200 bg-white p-4 text-sm">
        <Row label="Category / Source" value={tx.categoryName ?? tx.sourceType} />
        <Row label="Subcategory" value={tx.subcategoryName} />
        <Row label="Project" value={tx.projectName} />
        <Row label="Payee" value={tx.payeeName} />
        <Row 
          label={tx.subcategoryName?.toLowerCase().includes("fiverr") ? "Fiverr Account" : "Upwork Account"} 
          value={tx.upworkAccountName} 
        />
        <Row label="Client" value={tx.clientName} />
        <Row label="Salesperson" value={tx.salespersonName} />
        <Row label="Paid By" value={tx.paidByUserName} />
        <Row label="Payment Method" value={tx.paymentMethod} />
        <Row label="Transaction Date" value={tx.transactionDateKey} />
        <Row label="Status" value={tx.status} />
        <Row label="Created By" value={tx.createdByName} />
      </div>

      {tx.attachmentUrl && (
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <p className="mb-2 text-xs font-medium text-neutral-500">Receipt</p>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={tx.attachmentUrl} alt="Receipt" className="max-h-80 rounded-md" />
        </div>
      )}

      <div className="rounded-lg border border-neutral-200 bg-white p-4">
        <label className="text-xs font-medium text-neutral-500">Notes</label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          disabled={isClosed}
          rows={3}
          className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm disabled:bg-neutral-100"
        />
        <button
          onClick={saveNotes}
          disabled={saving || isClosed}
          className="mt-2 rounded-md bg-emerald-700 px-3 py-1.5 text-sm text-white disabled:opacity-60"
        >
          {saving ? "Saving..." : "Save Notes"}
        </button>
      </div>

      <button
        onClick={softDelete}
        disabled={isClosed}
        className="rounded-md border border-red-300 px-3 py-1.5 text-sm text-red-600 disabled:opacity-50"
      >
        Delete Transaction
      </button>
    </div>
  );
}

function Row({ label, value }: { label: string; value?: string | null }) {
  if (!value) return null;
  return (
    <div className="flex border-b py-2 last:border-0">
      <span className="w-40 text-neutral-500">{label}</span>
      <span className="font-medium">{value}</span>
    </div>
  );
}
