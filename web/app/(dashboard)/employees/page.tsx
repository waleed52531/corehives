"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { EmployeeFormModal } from "@/components/employees/employee-form-modal";
import type { Employee } from "@/lib/types/employee";

const STATUSES = ["All", "Active", "Inactive", "On Leave", "Resigned", "Terminated"];

export default function EmployeesPage() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Employee | null>(null);

  useEffect(() => {
    const q = query(collection(db, "employees"), orderBy("fullName"));
    const unsub = onSnapshot(q, (snap) => {
      setEmployees(snap.docs.map((d) => ({ ...(d.data() as Omit<Employee, "id">), id: d.id })));
      setLoading(false);
    });
    return unsub;
  }, []);

  const filtered = employees.filter((e) => {
    if (statusFilter !== "All" && e.employmentStatus !== statusFilter) return false;
    if (!search) return true;
    const haystack = `${e.fullName} ${e.employeeCode} ${e.jobTitle}`.toLowerCase();
    return haystack.includes(search.toLowerCase());
  });

  return (
    <div className="space-y-4 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Employees</h1>
        <button
          onClick={() => { setEditing(null); setModalOpen(true); }}
          className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white"
        >
          Add Employee
        </button>
      </div>

      <div className="flex gap-3">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search name, code, job title..."
          className="w-full max-w-xs rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
        />
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
        >
          {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
        </select>
      </div>

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-neutral-500">No employees found.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-neutral-500">
                <th className="p-3">Name</th>
                <th className="p-3">Code</th>
                <th className="p-3">Job Title</th>
                <th className="p-3">Type</th>
                <th className="p-3">Status</th>
                <th className="p-3">Joining Date</th>
                <th className="p-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((e) => (
                <tr key={e.id} className="border-b last:border-0 hover:bg-neutral-50">
                  <td className="p-3 font-medium">
                    <Link href={`/employees/${e.id}`} className="hover:underline">{e.fullName}</Link>
                  </td>
                  <td className="p-3 text-neutral-500">{e.employeeCode}</td>
                  <td className="p-3">{e.jobTitle}</td>
                  <td className="p-3 text-neutral-500">{e.employmentType}</td>
                  <td className="p-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs ${
                      e.employmentStatus === "Active" ? "bg-emerald-100 text-emerald-700" : "bg-neutral-200 text-neutral-600"
                    }`}>
                      {e.employmentStatus}
                    </span>
                  </td>
                  <td className="p-3 text-neutral-500">{e.joiningDate ?? "—"}</td>
                  <td className="p-3 text-right">
                    <button onClick={() => { setEditing(e); setModalOpen(true); }} className="text-emerald-700 hover:underline">
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <EmployeeFormModal open={modalOpen} onClose={() => setModalOpen(false)} editing={editing} />
    </div>
  );
}
