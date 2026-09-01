"use client";

import { useState } from "react";
import Link from "next/link";
import { useMonthTransactions, currentMonthKey } from "@/lib/firebase/use-month-transactions";
import { SummaryCard } from "@/components/ui/summary-card";
import { paisaToDisplay } from "@/lib/utils/money";

export default function DashboardPage() {
  const [monthKey, setMonthKey] = useState(currentMonthKey());
  const { transactions, loading } = useMonthTransactions(monthKey);

  const cashIn = transactions.filter((t) => t.type === "cash_in" && t.status === "completed");
  const expenses = transactions.filter((t) => t.type === "expense");

  const totalCashIn = cashIn.reduce((s, t) => s + t.amountPaisa, 0);
  const totalExpense = expenses.reduce((s, t) => s + t.amountPaisa, 0);
  const net = totalCashIn - totalExpense;

  const bySource: Record<string, number> = {};
  for (const t of cashIn) bySource[t.sourceType ?? "Other"] = (bySource[t.sourceType ?? "Other"] ?? 0) + t.amountPaisa;

  const byCategory: Record<string, number> = {};
  for (const t of expenses) {
    const key = t.categoryName ?? "Uncategorized";
    byCategory[key] = (byCategory[key] ?? 0) + t.amountPaisa;
  }

  const payrollExpenses = expenses.filter((t) => t.categoryId === "payroll-compensation");
  const payrollPaid = payrollExpenses.reduce((s, t) => s + t.amountPaisa, 0);

  const recent = transactions.slice(0, 8);

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Dashboard</h1>
        <input
          type="month"
          value={monthKey}
          onChange={(e) => setMonthKey(e.target.value)}
          className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
        />
      </div>

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <SummaryCard label="Cash In" paisa={totalCashIn} tone="cashIn" href={`/transactions?filter=cashIn`} />
            <SummaryCard label="Total Cash Out" paisa={totalExpense} tone="cashOut" href={`/transactions?filter=expense`} />
            <SummaryCard label="Payroll Paid" paisa={payrollPaid} tone="cashOut" href={`/payroll/${monthKey}`} />
            <SummaryCard label="Net Cash Flow" paisa={net} tone={net >= 0 ? "cashIn" : "cashOut"} />
          </div>

          <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
            <div className="rounded-lg border border-neutral-200 bg-white p-4">
              <h2 className="mb-3 text-sm font-semibold">Cash-In Source Breakdown</h2>
              {Object.keys(bySource).length === 0 ? (
                <p className="text-sm text-neutral-400">No cash in this month.</p>
              ) : (
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
              )}
            </div>

            <div className="rounded-lg border border-neutral-200 bg-white p-4">
              <h2 className="mb-3 text-sm font-semibold">Expense Category Breakdown</h2>
              {Object.keys(byCategory).length === 0 ? (
                <p className="text-sm text-neutral-400">No expenses this month.</p>
              ) : (
                <table className="w-full text-sm">
                  <tbody>
                    {Object.entries(byCategory).map(([k, v]) => (
                      <tr key={k} className="border-b last:border-0">
                        <td className="py-1.5">{k}</td>
                        <td className="py-1.5 text-right font-medium text-red-600">{paisaToDisplay(v)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>

          <div className="rounded-lg border border-neutral-200 bg-white p-4">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-sm font-semibold">Recent Transactions</h2>
              <Link href="/transactions" className="text-xs text-emerald-700 hover:underline">
                View all
              </Link>
            </div>
            {recent.length === 0 ? (
              <p className="text-sm text-neutral-400">No transactions yet.</p>
            ) : (
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left text-neutral-500">
                    <th className="py-1.5">Date</th>
                    <th className="py-1.5">Type</th>
                    <th className="py-1.5">Description</th>
                    <th className="py-1.5 text-right">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {recent.map((t) => (
                    <tr key={t.id} className="border-b last:border-0">
                      <td className="py-1.5">{t.transactionDateKey}</td>
                      <td className="py-1.5">{t.type === "cash_in" ? t.sourceType : t.categoryName}</td>
                      <td className="py-1.5">
                        <Link href={`/transactions/${t.id}`} className="hover:underline">
                          {t.description || t.subcategoryName || "—"}
                        </Link>
                      </td>
                      <td className={`py-1.5 text-right font-medium ${t.type === "cash_in" ? "text-emerald-700" : "text-red-600"}`}>
                        {paisaToDisplay(t.amountPaisa)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
    </div>
  );
}
