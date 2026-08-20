"use client";

import { useState } from "react";
import { useMonthTransactions, currentMonthKey } from "@/lib/firebase/use-month-transactions";
import { exportToCsv } from "@/lib/utils/csv-export";
import { paisaToDisplay } from "@/lib/utils/money";

export default function ProjectCostReportPage() {
  const [monthKey, setMonthKey] = useState(currentMonthKey());
  const { transactions, loading } = useMonthTransactions(monthKey);
  const expenses = transactions.filter((t) => t.type === "expense" && t.projectName);

  const byProject: Record<string, { total: number; dev: number; software: number; other: number }> = {};
  for (const t of expenses) {
    const key = t.projectName!;
    if (!byProject[key]) byProject[key] = { total: 0, dev: 0, software: 0, other: 0 };
    byProject[key].total += t.amountPaisa;
    if (t.categoryName === "Development & Project Costs") byProject[key].dev += t.amountPaisa;
    else if (t.categoryName === "Software & Subscriptions") byProject[key].software += t.amountPaisa;
    else byProject[key].other += t.amountPaisa;
  }

  function handleExport() {
    exportToCsv(
      Object.entries(byProject).map(([project, d]) => ({
        Project: project, TotalPKR: (d.total / 100).toFixed(0),
        DevelopmentPKR: (d.dev / 100).toFixed(0), SoftwarePKR: (d.software / 100).toFixed(0),
        OtherPKR: (d.other / 100).toFixed(0),
      })),
      `project-costs-${monthKey}.csv`
    );
  }

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Project Cost Report</h1>
        <div className="flex gap-2">
          <input type="month" value={monthKey} onChange={(e) => setMonthKey(e.target.value)} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          <button onClick={handleExport} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">Export CSV</button>
        </div>
      </div>
      {loading ? <p className="text-sm text-neutral-500">Loading...</p> : Object.keys(byProject).length === 0 ? (
        <p className="text-sm text-neutral-500">No project-linked expenses this month.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-neutral-500">
                <th className="p-3">Project</th>
                <th className="p-3 text-right">Development</th>
                <th className="p-3 text-right">Software</th>
                <th className="p-3 text-right">Other</th>
                <th className="p-3 text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(byProject).map(([project, d]) => (
                <tr key={project} className="border-b last:border-0">
                  <td className="p-3 font-medium">{project}</td>
                  <td className="p-3 text-right">{paisaToDisplay(d.dev)}</td>
                  <td className="p-3 text-right">{paisaToDisplay(d.software)}</td>
                  <td className="p-3 text-right">{paisaToDisplay(d.other)}</td>
                  <td className="p-3 text-right font-medium text-red-600">{paisaToDisplay(d.total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
