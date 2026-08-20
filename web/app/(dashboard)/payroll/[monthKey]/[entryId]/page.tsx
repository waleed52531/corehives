"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { collection, doc, onSnapshot, orderBy, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { recordPayrollPayment } from "@/lib/firebase/functions";
import { paisaToDisplay, rupeesToPaisa } from "@/lib/utils/money";
import type { PayrollEntry, PayrollPayment } from "@/lib/types/payroll";

const PAYMENT_METHODS = ["Cash", "Bank Transfer", "JazzCash", "EasyPaisa", "Card", "Other"];

export default function PayrollEntryDetailPage() {
  const params = useParams<{ monthKey: string; entryId: string }>();
  const [entry, setEntry] = useState<PayrollEntry | null>(null);
  const [payments, setPayments] = useState<PayrollPayment[]>([]);
  const [loading, setLoading] = useState(true);

  const [amount, setAmount] = useState("");
  const [dateKey, setDateKey] = useState(new Date().toISOString().slice(0, 10));
  const [method, setMethod] = useState("Bank Transfer");
  const [notes, setNotes] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmOverpay, setConfirmOverpay] = useState(false);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, "payroll_entries", params.entryId), (snap) => {
      if (snap.exists()) setEntry({ ...(snap.data() as Omit<PayrollEntry, "id">), id: snap.id });
      setLoading(false);
    });
    return unsub;
  }, [params.entryId]);

  useEffect(() => {
    const q = query(
      collection(db, "payroll_payments"),
      where("payrollEntryId", "==", params.entryId),
      orderBy("paymentDateKey", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      setPayments(snap.docs.map((d) => ({ ...(d.data() as Omit<PayrollPayment, "id">), id: d.id })));
    });
    return unsub;
  }, [params.entryId]);

  async function handleRecordPayment() {
    const amt = Number(amount);
    if (!amt || amt <= 0) return setError("Enter a valid amount.");
    setSaving(true);
    setError(null);
    try {
      // Client-generated deterministic id — passed as-is on retry so the
      // Cloud Function can dedupe (payroll_payment_{paymentId} linked tx).
      const paymentId = doc(collection(db, "payroll_payments")).id;
      await recordPayrollPayment({
        payrollEntryId: params.entryId,
        paymentId,
        amountPaisa: rupeesToPaisa(amt),
        paymentDateKey: dateKey,
        paymentMethod: method,
        notes,
        confirmOverpayment: confirmOverpay,
      });
      setAmount("");
      setNotes("");
      setConfirmOverpay(false);
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : "";
      if (message.includes("exceeds the expected amount")) {
        setError("This payment exceeds the expected amount. Check the box below to confirm and retry.");
        setConfirmOverpay(true);
      } else {
        setError("Could not record payment. Please try again.");
      }
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <p className="p-6 text-sm text-neutral-500">Loading...</p>;
  if (!entry) return <p className="p-6 text-sm text-neutral-500">Payroll entry not found.</p>;

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <div>
        <h1 className="text-xl font-semibold">{entry.employeeName}</h1>
        <p className="text-sm text-neutral-500">{entry.compensationType} · {params.monthKey}</p>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <Stat label="Expected" value={entry.expectedAmountPaisa} />
        <Stat label="Paid" value={entry.totalPaidAmountPaisa} tone="text-emerald-700" />
        <Stat label="Remaining" value={entry.remainingAmountPaisa} tone="text-red-600" />
      </div>

      <div className="rounded-lg border border-neutral-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-semibold">Record Payment</h2>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-sm font-medium">Amount (PKR)</label>
            <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          </div>
          <div>
            <label className="text-sm font-medium">Date</label>
            <input type="date" value={dateKey} onChange={(e) => setDateKey(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          </div>
          <div>
            <label className="text-sm font-medium">Payment Method</label>
            <select value={method} onChange={(e) => setMethod(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
              {PAYMENT_METHODS.map((m) => <option key={m} value={m}>{m}</option>)}
            </select>
          </div>
          <div className="col-span-2">
            <label className="text-sm font-medium">Notes (optional)</label>
            <input value={notes} onChange={(e) => setNotes(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          </div>
        </div>
        {confirmOverpay && (
          <label className="mt-3 flex items-center gap-2 text-sm text-orange-700">
            <input type="checkbox" checked={confirmOverpay} onChange={(e) => setConfirmOverpay(e.target.checked)} />
            Confirm this payment exceeds the expected amount
          </label>
        )}
        {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
        <button
          onClick={handleRecordPayment}
          disabled={saving}
          className="mt-4 rounded-md bg-emerald-700 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
        >
          {saving ? "Saving..." : "Save Payment"}
        </button>
      </div>

      <div>
        <h2 className="mb-2 text-sm font-semibold">Payment History</h2>
        {payments.length === 0 ? (
          <p className="text-sm text-neutral-400">No payments recorded yet.</p>
        ) : (
          <div className="space-y-2">
            {payments.map((p) => (
              <div key={p.id} className="flex items-center justify-between rounded-lg border border-neutral-200 bg-white p-3 text-sm">
                <div>
                  <p className="font-medium">{paisaToDisplay(p.amountPaisa)}</p>
                  <p className="text-neutral-500">{p.paymentDateKey} · {p.paymentMethod} · by {p.paidByUserName}</p>
                </div>
                {p.notes && <p className="max-w-xs text-neutral-400">{p.notes}</p>}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value, tone }: { label: string; value: number; tone?: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4">
      <p className="text-xs text-neutral-500">{label}</p>
      <p className={`mt-1 text-lg font-semibold ${tone ?? ""}`}>{paisaToDisplay(value)}</p>
    </div>
  );
}
