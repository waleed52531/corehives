"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { collection, doc, getDoc, onSnapshot, orderBy, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { generatePayroll, closeMonth, reopenMonth } from "@/lib/firebase/functions";
import { paisaToDisplay } from "@/lib/utils/money";
import { exportToCsv } from "@/lib/utils/csv-export";
import type { PayrollEntry, PayrollStatus, MonthlyClosing } from "@/lib/types/payroll";

const STATUS_COLOR: Record<PayrollStatus, string> = {
  Paid: "bg-emerald-100 text-emerald-700",
  Partial: "bg-orange-100 text-orange-700",
  Pending: "bg-red-100 text-red-700",
  Skipped: "bg-neutral-200 text-neutral-600",
};

export default function PayrollMonthPage() {
  const params = useParams<{ monthKey: string }>();
  const router = useRouter();
  const [entries, setEntries] = useState<PayrollEntry[]>([]);
  const [closing, setClosing] = useState<MonthlyClosing | null>(null);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(db, "payroll_entries"), where("monthKey", "==", params.monthKey), orderBy("employeeName"));
    const unsub = onSnapshot(q, (snap) => {
      setEntries(snap.docs.map((d) => ({ ...(d.data() as Omit<PayrollEntry, "id">), id: d.id })));
      setLoading(false);
    });
    return unsub;
  }, [params.monthKey]);

  useEffect(() => {
    getDoc(doc(db, "monthly_closings", params.monthKey)).then((snap) => {
      setClosing(snap.exists() ? (snap.data() as MonthlyClosing) : null);
    });
  }, [params.monthKey]);

  async function handleGenerate() {
    setGenerating(true);
    setError(null);
    try {
      await generatePayroll(params.monthKey);
    } catch {
      setError("Could not generate payroll. Please try again.");
    } finally {
      setGenerating(false);
    }
  }

  async function handleClose() {
    if (!confirm(`Close ${params.monthKey}? Members will no longer be able to edit transactions from this month.`)) return;
    setBusy(true);
    try {
      await closeMonth(params.monthKey);
      setClosing({ monthKey: params.monthKey, status: "closed" });
    } catch {
      setError("Could not close month.");
    } finally {
      setBusy(false);
    }
  }

  async function handleReopen() {
    const reason = prompt("Reason for reopening this month (required for audit):");
    if (!reason) return;
    setBusy(true);
    try {
      await reopenMonth(params.monthKey, reason);
      setClosing({ monthKey: params.monthKey, status: "open" });
    } catch {
      setError("Could not reopen month.");
    } finally {
      setBusy(false);
    }
  }

  function handleMonthChange(newMonth: string) {
    router.push(`/payroll/${newMonth}`);
  }

  function handleExport() {
    exportToCsv(
      entries.map((e) => ({
        Employee: e.employeeName,
        CompensationType: e.compensationType,
        ExpectedPKR: (e.expectedAmountPaisa / 100).toFixed(0),
        PaidPKR: (e.totalPaidAmountPaisa / 100).toFixed(0),
        RemainingPKR: (e.remainingAmountPaisa / 100).toFixed(0),
        Status: e.status,
      })),
      `payroll-${params.monthKey}.csv`
    );
  }

  const totalExpected = entries.reduce((s, e) => s + e.expectedAmountPaisa, 0);
  const totalPaid = entries.reduce((s, e) => s + e.totalPaidAmountPaisa, 0);
  const isClosed = closing?.status === "closed";

  return (
    <div className="space-y-4 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Payroll — {params.monthKey}</h1>
        <div className="flex items-center gap-2">
          <input
            type="month"
            value={params.monthKey}
            onChange={(e) => handleMonthChange(e.target.value)}
            className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
          />
          <button onClick={handleExport} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
            Export CSV
          </button>
          {isClosed ? (
            <button onClick={handleReopen} disabled={busy} className="rounded-md border border-orange-300 px-3 py-1.5 text-sm text-orange-700">
              Reopen Month
            </button>
          ) : (
            <button onClick={handleClose} disabled={busy} className="rounded-md border border-red-300 px-3 py-1.5 text-sm text-red-600">
              Close Month
            </button>
          )}
          {entries.length === 0 && (
            <button
              onClick={handleGenerate}
              disabled={generating}
              className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-60"
            >
              {generating ? "Generating..." : "Generate Monthly Payroll"}
            </button>
          )}
        </div>
      </div>

      {isClosed && (
        <div className="rounded-md bg-orange-50 p-3 text-sm text-orange-700">
          This month is closed. Reopen it to record additional payments.
        </div>
      )}
      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <p className="text-xs text-neutral-500">Expected</p>
          <p className="mt-1 text-xl font-semibold">{paisaToDisplay(totalExpected)}</p>
        </div>
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <p className="text-xs text-neutral-500">Paid</p>
          <p className="mt-1 text-xl font-semibold text-emerald-700">{paisaToDisplay(totalPaid)}</p>
        </div>
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <p className="text-xs text-neutral-500">Remaining</p>
          <p className="mt-1 text-xl font-semibold text-red-600">{paisaToDisplay(totalExpected - totalPaid)}</p>
        </div>
      </div>

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : entries.length === 0 ? (
        <p className="text-sm text-neutral-500">No payroll generated for this month yet.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-neutral-500">
                <th className="p-3">Employee</th>
                <th className="p-3">Type</th>
                <th className="p-3 text-right">Expected</th>
                <th className="p-3 text-right">Paid</th>
                <th className="p-3 text-right">Remaining</th>
                <th className="p-3">Status</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((e) => (
                <tr key={e.id} className="border-b last:border-0 hover:bg-neutral-50">
                  <td className="p-3 font-medium">
                    <Link href={`/payroll/${params.monthKey}/${e.id}`} className="hover:underline">{e.employeeName}</Link>
                  </td>
                  <td className="p-3 text-neutral-500">{e.compensationType}</td>
                  <td className="p-3 text-right">{paisaToDisplay(e.expectedAmountPaisa)}</td>
                  <td className="p-3 text-right text-emerald-700">{paisaToDisplay(e.totalPaidAmountPaisa)}</td>
                  <td className="p-3 text-right text-red-600">{paisaToDisplay(e.remainingAmountPaisa)}</td>
                  <td className="p-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs ${STATUS_COLOR[e.status]}`}>{e.status}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
