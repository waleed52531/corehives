"use client";

import { useState } from "react";
import { useMonthTransactions, currentMonthKey } from "@/lib/firebase/use-month-transactions";
import { SummaryCard } from "@/components/ui/summary-card";
import { exportToCsv } from "@/lib/utils/csv-export";
import { paisaToDisplay } from "@/lib/utils/money";

export default function CashFlowReportPage() {
  const [monthKey, setMonthKey] = useState(currentMonthKey());
  const { transactions, loading } = useMonthTransactions(monthKey);

  const cashIn = transactions.filter((t) => t.type === "cash_in" && t.status === "completed");
  const expenses = transactions.filter((t) => t.type === "expense");
  const totalCashIn = cashIn.reduce((s, t) => s + t.amountPaisa, 0);
  const totalExpense = expenses.reduce((s, t) => s + t.amountPaisa, 0);
  const net = totalCashIn - totalExpense;

  const bySource: Record<string, number> = {};
  for (const t of cashIn) bySource[t.sourceType ?? "Other"] = (bySource[t.sourceType ?? "Other"] ?? 0) + t.amountPaisa;

  function handleExport() {
    exportToCsv(
      Object.entries(bySource).map(([source, amount]) => ({
        Source: source, AmountPKR: (amount / 100).toFixed(0),
      })),
      `cash-flow-${monthKey}.csv`
    );
  }

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Monthly Cash Flow</h1>
        <div className="flex gap-2">
          <input type="month" value={monthKey} onChange={(e) => setMonthKey(e.target.value)} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          <button onClick={handleExport} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">Export CSV</button>
        </div>
      </div>
      {loading ? <p className="text-sm text-neutral-500">Loading...</p> : (
        <>
          <div className="grid grid-cols-3 gap-4">
            <SummaryCard label="Total Cash In" paisa={totalCashIn} tone="cashIn" />
            <SummaryCard label="Total Cash Out" paisa={totalExpense} tone="cashOut" />
            <SummaryCard label="Net Cash Flow" paisa={net} tone={net >= 0 ? "cashIn" : "cashOut"} />
          </div>
          <div className="rounded-lg border border-neutral-200 bg-white p-4">
            <h2 className="mb-3 text-sm font-semibold">Cash In Breakdown by Source</h2>
            <table className="w-full text-sm">
              <tbody>
                {Object.entries(bySource).map(([k, v]) => (
                  <tr key={k} className="border-b last:border-0">
                    <td className="py-1.5">{k}</td>
                    <td className="py-1.5 text-right font-medium text-emerald-700">{paisaToDisplay(v)}</td>
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
