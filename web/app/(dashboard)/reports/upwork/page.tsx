"use client";

import { useState } from "react";
import { useMonthTransactions, currentMonthKey } from "@/lib/firebase/use-month-transactions";
import { exportToCsv } from "@/lib/utils/csv-export";
import { paisaToDisplay } from "@/lib/utils/money";

export default function UpworkReportPage() {
  const [monthKey, setMonthKey] = useState(currentMonthKey());
  const { transactions, loading } = useMonthTransactions(monthKey);
  const upworkTx = transactions.filter((t) => t.type === "cash_in" && t.sourceType === "Upwork");

  const byAccount: Record<string, { total: number; count: number }> = {};
  for (const t of upworkTx) {
    const key = t.upworkAccountName ?? "Unknown";
    if (!byAccount[key]) byAccount[key] = { total: 0, count: 0 };
    byAccount[key].total += t.amountPaisa;
    byAccount[key].count += 1;
  }

  function handleExport() {
    exportToCsv(
      Object.entries(byAccount).map(([account, data]) => ({
        Account: account, TotalPKR: (data.total / 100).toFixed(0), Withdrawals: data.count,
      })),
      `upwork-withdrawals-${monthKey}.csv`
    );
  }

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Upwork Account Breakdown</h1>
        <div className="flex gap-2">
          <input type="month" value={monthKey} onChange={(e) => setMonthKey(e.target.value)} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          <button onClick={handleExport} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">Export CSV</button>
        </div>
      </div>
      {loading ? <p className="text-sm text-neutral-500">Loading...</p> : Object.keys(byAccount).length === 0 ? (
        <p className="text-sm text-neutral-500">No Upwork withdrawals this month.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-neutral-500">
                <th className="p-3">Account</th>
                <th className="p-3 text-right">PKR Received</th>
                <th className="p-3 text-right">Withdrawals</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(byAccount).map(([account, data]) => (
                <tr key={account} className="border-b last:border-0">
                  <td className="p-3 font-medium">{account}</td>
                  <td className="p-3 text-right text-emerald-700">{paisaToDisplay(data.total)}</td>
                  <td className="p-3 text-right">{data.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
