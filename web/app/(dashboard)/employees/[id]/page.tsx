"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { CompensationPanel } from "@/components/employees/compensation-panel";
import { EmployeePayrollHistory } from "@/components/employees/employee-payroll-history";
import type { Employee } from "@/lib/types/employee";

const TABS = ["Overview", "Contact", "Employment", "Compensation", "Payroll History"] as const;
type Tab = (typeof TABS)[number];

export default function EmployeeDetailPage() {
  const params = useParams<{ id: string }>();
  const [employee, setEmployee] = useState<Employee | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>("Overview");

  useEffect(() => {
    (async () => {
      const snap = await getDoc(doc(db, "employees", params.id));
      if (snap.exists()) setEmployee({ ...(snap.data() as Omit<Employee, "id">), id: snap.id });
      setLoading(false);
    })();
  }, [params.id]);

  if (loading) return <p className="p-6 text-sm text-neutral-500">Loading...</p>;
  if (!employee) return <p className="p-6 text-sm text-neutral-500">Employee not found.</p>;

  return (
    <div className="mx-auto max-w-3xl space-y-4 p-6">
      <div>
        <h1 className="text-xl font-semibold">{employee.fullName}</h1>
        <p className="text-sm text-neutral-500">{employee.jobTitle} · {employee.employeeCode}</p>
      </div>

      <div className="flex gap-4 border-b text-sm">
        {TABS.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`border-b-2 px-1 pb-2 ${tab === t ? "border-emerald-700 text-emerald-700" : "border-transparent text-neutral-500"}`}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "Overview" && (
        <div className="rounded-lg border border-neutral-200 bg-white p-4 text-sm">
          <Row label="Employment Status" value={employee.employmentStatus} />
          <Row label="Employment Type" value={employee.employmentType} />
          <Row label="Joining Date" value={employee.joiningDate} />
          <Row label="Work Location" value={employee.workLocation} />
        </div>
      )}

      {tab === "Contact" && (
        <div className="rounded-lg border border-neutral-200 bg-white p-4 text-sm">
          <Row label="Company Email" value={employee.companyEmail} />
          <Row label="Personal Email" value={employee.personalEmail} />
          <Row label="Phone" value={employee.phoneNumber} />
          <Row label="WhatsApp" value={employee.whatsappNumber} />
          <Row label="Address" value={employee.currentAddress} />
          <Row label="Emergency Contact" value={employee.emergencyContactName} />
          <Row label="Emergency Phone" value={employee.emergencyContactPhone} />
        </div>
      )}

      {tab === "Employment" && (
        <div className="rounded-lg border border-neutral-200 bg-white p-4 text-sm">
          <Row label="Employee Code" value={employee.employeeCode} />
          <Row label="Shift Timing" value={employee.shiftTiming} />
          <Row label="Probation End" value={employee.probationEndDate} />
          <Row label="Last Working Date" value={employee.lastWorkingDate} />
          <Row label="Leaving Reason" value={employee.leavingReason} />
          <Row label="Notes" value={employee.notes} />
        </div>
      )}

      {tab === "Compensation" && <CompensationPanel employeeId={employee.id} />}
      {tab === "Payroll History" && <EmployeePayrollHistory employeeId={employee.id} />}
    </div>
  );
}

function Row({ label, value }: { label: string; value?: string | null }) {
  if (!value) return null;
  return (
    <div className="flex border-b py-2 last:border-0">
      <span className="w-40 text-neutral-500">{label}</span>
      <span className="font-medium">{value}</span>
    </div>
  );
}
