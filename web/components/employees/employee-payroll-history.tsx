"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, orderBy, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { paisaToDisplay } from "@/lib/utils/money";
import type { PayrollPayment } from "@/lib/types/payroll";

export function EmployeePayrollHistory({ employeeId }: { employeeId: string }) {
  const [payments, setPayments] = useState<PayrollPayment[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(
      collection(db, "payroll_payments"),
      where("employeeId", "==", employeeId),
      orderBy("paymentDateKey", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      setPayments(snap.docs.map((d) => ({ ...(d.data() as Omit<PayrollPayment, "id">), id: d.id })));
      setLoading(false);
    });
    return unsub;
  }, [employeeId]);

  if (loading) return <p className="text-sm text-neutral-500">Loading...</p>;
  if (payments.length === 0) return <p className="text-sm text-neutral-400">No payroll payments recorded yet.</p>;

  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b text-left text-neutral-500">
            <th className="py-1.5">Date</th>
            <th className="py-1.5">Method</th>
            <th className="py-1.5">Paid By</th>
            <th className="py-1.5 text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          {payments.map((p) => (
            <tr key={p.id} className="border-b last:border-0">
              <td className="py-1.5">{p.paymentDateKey}</td>
              <td className="py-1.5 text-neutral-500">{p.paymentMethod ?? "—"}</td>
              <td className="py-1.5 text-neutral-500">{p.paidByUserName}</td>
              <td className="py-1.5 text-right font-medium">{paisaToDisplay(p.amountPaisa)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
