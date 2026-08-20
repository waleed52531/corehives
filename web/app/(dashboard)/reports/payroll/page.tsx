"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, orderBy, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { currentMonthKey } from "@/lib/firebase/use-month-transactions";
import { exportToCsv } from "@/lib/utils/csv-export";
import { paisaToDisplay } from "@/lib/utils/money";
import type { PayrollEntry } from "@/lib/types/payroll";

export default function PayrollReportPage() {
  const [monthKey, setMonthKey] = useState(currentMonthKey());
  const [entries, setEntries] = useState<PayrollEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "payroll_entries"), where("monthKey", "==", monthKey), orderBy("employeeName"));
    const unsub = onSnapshot(q, (snap) => {
      setEntries(snap.docs.map((d) => ({ ...(d.data() as Omit<PayrollEntry, "id">), id: d.id })));
      setLoading(false);
    });
    return unsub;
  }, [monthKey]);

  const expected = entries.reduce((s, e) => s + e.expectedAmountPaisa, 0);
  const paid = entries.reduce((s, e) => s + e.totalPaidAmountPaisa, 0);
  const pending = entries.filter((e) => e.status === "Pending").length;
  const partial = entries.filter((e) => e.status === "Partial").length;

  const byType: Record<string, number> = {};
  for (const e of entries) byType[e.compensationType] = (byType[e.compensationType] ?? 0) + e.expectedAmountPaisa;

  function handleExport() {
    exportToCsv(
      entries.map((e) => ({
        Employee: e.employeeName, Type: e.compensationType,
        ExpectedPKR: (e.expectedAmountPaisa / 100).toFixed(0),
        PaidPKR: (e.totalPaidAmountPaisa / 100).toFixed(0), Status: e.status,
      })),
      `payroll-report-${monthKey}.csv`
    );
  }

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Payroll Report</h1>
        <div className="flex gap-2">
          <input type="month" value={monthKey} onChange={(e) => setMonthKey(e.target.value)} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          <button onClick={handleExport} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">Export CSV</button>
        </div>
      </div>
      {loading ? <p className="text-sm text-neutral-500">Loading...</p> : (
        <>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <div className="rounded-lg border border-neutral-200 bg-white p-4">
              <p className="text-xs text-neutral-500">Expected</p>
              <p className="mt-1 text-lg font-semibold">{paisaToDisplay(expected)}</p>
            </div>
            <div className="rounded-lg border border-neutral-200 bg-white p-4">
              <p className="text-xs text-neutral-500">Paid</p>
              <p className="mt-1 text-lg font-semibold text-emerald-700">{paisaToDisplay(paid)}</p>
            </div>
            <div className="rounded-lg border border-neutral-200 bg-white p-4">
              <p className="text-xs text-neutral-500">Pending Entries</p>
              <p className="mt-1 text-lg font-semibold text-red-600">{pending}</p>
            </div>
            <div className="rounded-lg border border-neutral-200 bg-white p-4">
              <p className="text-xs text-neutral-500">Partial Entries</p>
              <p className="mt-1 text-lg font-semibold text-orange-600">{partial}</p>
            </div>
          </div>
          <div className="rounded-lg border border-neutral-200 bg-white p-4">
            <h2 className="mb-3 text-sm font-semibold">By Compensation Type</h2>
            <table className="w-full text-sm">
              <tbody>
                {Object.entries(byType).map(([k, v]) => (
                  <tr key={k} className="border-b last:border-0">
                    <td className="py-1.5">{k}</td>
                    <td className="py-1.5 text-right font-medium">{paisaToDisplay(v)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}
