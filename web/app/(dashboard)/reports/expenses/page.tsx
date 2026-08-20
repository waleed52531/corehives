"use client";

import { useState } from "react";
import { useMonthTransactions, currentMonthKey } from "@/lib/firebase/use-month-transactions";
import { exportToCsv } from "@/lib/utils/csv-export";
import { paisaToDisplay } from "@/lib/utils/money";

export default function ExpenseReportPage() {
  const [monthKey, setMonthKey] = useState(currentMonthKey());
  const { transactions, loading } = useMonthTransactions(monthKey);
  const expenses = transactions.filter((t) => t.type === "expense");

  const byCategory: Record<string, number> = {};
  const byPerson: Record<string, number> = {};
  const byProject: Record<string, number> = {};
  const byPayee: Record<string, number> = {};
  for (const t of expenses) {
    const cat = t.categoryName ?? "Uncategorized";
    byCategory[cat] = (byCategory[cat] ?? 0) + t.amountPaisa;
    byPerson[t.paidByUserName] = (byPerson[t.paidByUserName] ?? 0) + t.amountPaisa;
    if (t.projectName) byProject[t.projectName] = (byProject[t.projectName] ?? 0) + t.amountPaisa;
    if (t.payeeName) byPayee[t.payeeName] = (byPayee[t.payeeName] ?? 0) + t.amountPaisa;
  }

  function handleExport() {
    exportToCsv(
      expenses.map((t) => ({
        Date: t.transactionDateKey, Category: t.categoryName ?? "", Subcategory: t.subcategoryName ?? "",
        Payee: t.payeeName ?? "", Project: t.projectName ?? "", PaidBy: t.paidByUserName,
        AmountPKR: (t.amountPaisa / 100).toFixed(0),
      })),
      `expenses-${monthKey}.csv`
    );
  }

  function Breakdown({ title, data }: { title: string; data: Record<string, number> }) {
    const entries = Object.entries(data).sort((a, b) => b[1] - a[1]);
    return (
      <div className="rounded-lg border border-neutral-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-semibold">{title}</h2>
        {entries.length === 0 ? <p className="text-sm text-neutral-400">No data.</p> : (
          <table className="w-full text-sm">
            <tbody>
              {entries.map(([k, v]) => (
                <tr key={k} className="border-b last:border-0">
                  <td className="py-1.5">{k}</td>
                  <td className="py-1.5 text-right font-medium text-red-600">{paisaToDisplay(v)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Expense Breakdown</h1>
        <div className="flex gap-2">
          <input type="month" value={monthKey} onChange={(e) => setMonthKey(e.target.value)} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          <button onClick={handleExport} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">Export CSV</button>
        </div>
      </div>
      {loading ? <p className="text-sm text-neutral-500">Loading...</p> : (
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
          <Breakdown title="By Category" data={byCategory} />
          <Breakdown title="By Person Paid" data={byPerson} />
          <Breakdown title="By Project" data={byProject} />
          <Breakdown title="By Payee" data={byPayee} />
        </div>
      )}
    </div>
  );
}
