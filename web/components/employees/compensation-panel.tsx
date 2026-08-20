"use client";

import { useEffect, useState } from "react";
import { collection, doc, getDoc, onSnapshot, orderBy, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { updateEmployeeCompensation } from "@/lib/firebase/functions";
import { paisaToDisplay, rupeesToPaisa } from "@/lib/utils/money";
import type { EmployeeCompensation, EmployeeCompensationHistory } from "@/lib/types/employee";

const COMP_TYPES = ["Salary", "Partner Compensation", "Contractor", "Intern Stipend", "Other"];

export function CompensationPanel({ employeeId }: { employeeId: string }) {
  const [current, setCurrent] = useState<EmployeeCompensation | null>(null);
  const [history, setHistory] = useState<EmployeeCompensationHistory[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [salary, setSalary] = useState("");
  const [compType, setCompType] = useState("Salary");
  const [effectiveFrom, setEffectiveFrom] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const snap = await getDoc(doc(db, "employee_compensation", employeeId));
      if (snap.exists()) {
        const data = snap.data() as EmployeeCompensation;
        setCurrent(data);
        setSalary((data.baseSalaryPaisa / 100).toString());
        setCompType(data.compensationType);
      }
      setLoading(false);
    })();

    const q = query(
      collection(db, "employee_compensation_history"),
      where("employeeId", "==", employeeId),
      orderBy("effectiveFrom", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      setHistory(snap.docs.map((d) => ({ ...(d.data() as Omit<EmployeeCompensationHistory, "id">), id: d.id })));
    });
    return unsub;
  }, [employeeId]);

  async function handleSave() {
    const amount = Number(salary);
    if (!amount || amount <= 0) return setError("Enter a valid salary.");
    if (!effectiveFrom) return setError("Effective date is required.");
    setSaving(true);
    setError(null);
    try {
      await updateEmployeeCompensation({
        employeeId,
        baseSalaryPaisa: rupeesToPaisa(amount),
        compensationType: compType,
        effectiveFrom,
      });
      setEditing(false);
      // Refresh current
      const snap = await getDoc(doc(db, "employee_compensation", employeeId));
      if (snap.exists()) setCurrent(snap.data() as EmployeeCompensation);
    } catch {
      setError("Could not update compensation. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <p className="text-sm text-neutral-500">Loading...</p>;

  return (
    <div className="space-y-4">
      <div className="rounded-lg border border-neutral-200 bg-white p-4">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold">Current Compensation</h3>
          <button onClick={() => setEditing((v) => !v)} className="text-sm text-emerald-700 hover:underline">
            {editing ? "Cancel" : "Update"}
          </button>
        </div>
        {current ? (
          <div className="mt-2 text-sm">
            <p className="text-xl font-semibold">{paisaToDisplay(current.baseSalaryPaisa)}</p>
            <p className="text-neutral-500">{current.compensationType} · effective {current.effectiveFrom}</p>
          </div>
        ) : (
          <p className="mt-2 text-sm text-neutral-400">No compensation record set.</p>
        )}

        {editing && (
          <div className="mt-4 space-y-3 border-t pt-4">
            <div>
              <label className="text-sm font-medium">Base Salary (PKR)</label>
              <input
                type="number"
                value={salary}
                onChange={(e) => setSalary(e.target.value)}
                className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
              />
            </div>
            <div>
              <label className="text-sm font-medium">Compensation Type</label>
              <select value={compType} onChange={(e) => setCompType(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
                {COMP_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <div>
              <label className="text-sm font-medium">Effective From</label>
              <input
                type="date"
                value={effectiveFrom}
                onChange={(e) => setEffectiveFrom(e.target.value)}
                className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
              />
            </div>
            {error && <p className="text-sm text-red-600">{error}</p>}
            <p className="text-xs text-neutral-400">
              The previous compensation period will be preserved in history — not overwritten.
              Already-generated payroll entries are never retroactively changed.
            </p>
            <button
              onClick={handleSave}
              disabled={saving}
              className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-60"
            >
              {saving ? "Saving..." : "Save New Compensation"}
            </button>
          </div>
        )}
      </div>

      <div className="rounded-lg border border-neutral-200 bg-white p-4">
        <h3 className="mb-2 text-sm font-semibold">Compensation History</h3>
        {history.length === 0 ? (
          <p className="text-sm text-neutral-400">No prior compensation periods.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-neutral-500">
                <th className="py-1.5">Period</th>
                <th className="py-1.5">Type</th>
                <th className="py-1.5 text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              {history.map((h) => (
                <tr key={h.id} className="border-b last:border-0">
                  <td className="py-1.5">{h.effectiveFrom} – {h.effectiveTo}</td>
                  <td className="py-1.5 text-neutral-500">{h.compensationType}</td>
                  <td className="py-1.5 text-right">{paisaToDisplay(h.baseSalaryPaisa)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
