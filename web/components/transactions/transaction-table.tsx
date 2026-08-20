"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useMonthTransactions, currentMonthKey } from "@/lib/firebase/use-month-transactions";
import { paisaToDisplay } from "@/lib/utils/money";
import { exportToCsv } from "@/lib/utils/csv-export";
import type { Transaction, TxType } from "@/lib/types/transaction";

export function TransactionTable({
  typeFilter,
  lateOnly = false,
  title,
}: {
  typeFilter?: TxType;
  lateOnly?: boolean;
  title: string;
}) {
  const [monthKey, setMonthKey] = useState(currentMonthKey());
  const [search, setSearch] = useState("");
  const { transactions, loading } = useMonthTransactions(monthKey);

  const filtered = useMemo(() => {
    return transactions.filter((t) => {
      if (typeFilter && t.type !== typeFilter) return false;
      if (lateOnly && !t.lateEntry) return false;
      if (!search) return true;
      const haystack = [
        t.description, t.notes, t.categoryName, t.subcategoryName,
        t.payeeName, t.projectName, t.sourceType, t.upworkAccountName, t.paidByUserName,
      ].filter(Boolean).join(" ").toLowerCase();
      return haystack.includes(search.toLowerCase());
    });
  }, [transactions, typeFilter, lateOnly, search]);

  function handleExport() {
    const rows = filtered.map((t) => ({
      Date: t.transactionDateKey,
      Type: t.type,
      Category: t.categoryName ?? t.sourceType ?? "",
      Subcategory: t.subcategoryName ?? "",
      Payee: t.payeeName ?? "",
      Project: t.projectName ?? "",
      AmountPKR: (t.amountPaisa / 100).toFixed(0),
      PaidBy: t.paidByUserName,
      Status: t.status,
      LateEntry: t.lateEntry ? "Yes" : "No",
      Notes: t.notes ?? "",
    }));
    exportToCsv(rows, `${title.toLowerCase().replace(/\s+/g, "-")}-${monthKey}.csv`);
  }

  const total = filtered.reduce((s, t) => s + t.amountPaisa, 0);

  return (
    <div className="space-y-4 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">{title}</h1>
        <div className="flex items-center gap-2">
          <input
            type="month"
            value={monthKey}
            onChange={(e) => setMonthKey(e.target.value)}
            className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
          />
          <button onClick={handleExport} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
            Export CSV
          </button>
        </div>
      </div>

      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search description, category, payee, project..."
        className="w-full max-w-md rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
      />

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-neutral-500">No transactions found.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-neutral-500">
                <th className="p-3">Date</th>
                <th className="p-3">Type</th>
                <th className="p-3">Category / Source</th>
                <th className="p-3">Paid By / Account</th>
                <th className="p-3 text-right">Amount</th>
                <th className="p-3">Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((t: Transaction) => (
                <tr key={t.id} className="border-b last:border-0 hover:bg-neutral-50">
                  <td className="p-3">{t.transactionDateKey}</td>
                  <td className="p-3">
                    <span className={t.type === "cash_in" ? "text-emerald-700" : "text-red-600"}>
                      {t.type === "cash_in" ? "Cash In" : "Expense"}
                    </span>
                  </td>
                  <td className="p-3">
                    <Link href={`/transactions/${t.id}`} className="font-medium hover:underline">
                      {t.type === "cash_in" ? t.sourceType : t.categoryName}
                    </Link>
                    {t.lateEntry && (
                      <span className="ml-2 rounded bg-orange-100 px-1.5 py-0.5 text-xs text-orange-700">Late</span>
                    )}
                  </td>
                  <td className="p-3 text-neutral-500">{t.paidByUserName || t.upworkAccountName || "—"}</td>
                  <td className={`p-3 text-right font-medium ${t.type === "cash_in" ? "text-emerald-700" : "text-red-600"}`}>
                    {paisaToDisplay(t.amountPaisa)}
                  </td>
                  <td className="p-3 text-neutral-500">{t.status}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="border-t bg-neutral-50 font-medium">
                <td className="p-3" colSpan={4}>Total</td>
                <td className="p-3 text-right">{paisaToDisplay(total)}</td>
                <td className="p-3" />
              </tr>
            </tfoot>
          </table>
        </div>
      )}
    </div>
  );
}
