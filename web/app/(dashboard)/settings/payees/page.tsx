"use client";

import { useEffect, useState } from "react";
import {
  listenAll,
  createConfigDoc,
  updateConfigDoc,
  setActive,
  isDuplicateName,
} from "@/lib/firebase/config-repo";
import { StatusBadge } from "@/components/ui/status-badge";
import { Modal } from "@/components/ui/modal";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { SearchInput } from "@/components/ui/search-input";
import type { Payee, PayeeType } from "@/lib/types/config";

const PAYEE_TYPES: PayeeType[] = ["employee", "contractor", "vendor", "service provider", "other"];

interface EmployeeOption {
  id: string;
  fullName: string;
}

export default function PayeesPage() {
  const [rows, setRows] = useState<Payee[]>([]);
  const [employees, setEmployees] = useState<EmployeeOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Payee | null>(null);
  const [name, setName] = useState("");
  const [type, setType] = useState<PayeeType>("other");
  const [employeeId, setEmployeeId] = useState<string>("");
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmTarget, setConfirmTarget] = useState<Payee | null>(null);

  useEffect(() => {
    const unsub = listenAll<Payee>("payees", (r) => {
      setRows(r);
      setLoading(false);
    });
    // Employee directory lands in Phase 3 — this listener degrades
    // gracefully to an empty list until then.
    const unsubEmp = listenAll<EmployeeOption>("employees", setEmployees, "fullName");
    return () => {
      unsub();
      unsubEmp();
    };
  }, []);

  function openAdd() {
    setEditing(null);
    setName("");
    setType("other");
    setEmployeeId("");
    setFormError(null);
    setModalOpen(true);
  }

  function openEdit(row: Payee) {
    setEditing(row);
    setName(row.name);
    setType(row.type ?? "other");
    setEmployeeId(row.employeeId ?? "");
    setFormError(null);
    setModalOpen(true);
  }

  async function handleSave() {
    const trimmed = name.trim();
    if (!trimmed) return setFormError("Name is required.");
    if (isDuplicateName(rows, trimmed, editing?.id)) {
      return setFormError("A payee with this name already exists.");
    }
    setSaving(true);
    try {
      const payload: Record<string, unknown> = {
        name: trimmed,
        type,
        employeeId: employeeId || null,
      };
      if (editing) {
        await updateConfigDoc("payees", editing.id, payload);
      } else {
        await createConfigDoc("payees", payload);
      }
      setModalOpen(false);
    } catch {
      setFormError("Could not save. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  async function confirmDeactivate() {
    if (!confirmTarget) return;
    await setActive("payees", confirmTarget.id, false);
    setConfirmTarget(null);
  }

  const filtered = rows.filter((r) => r.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Payees</h1>
        <button onClick={openAdd} className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white">
          Add Payee
        </button>
      </div>

      <SearchInput value={search} onChange={setSearch} placeholder="Search payees..." />

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-neutral-500">No payees found.</p>
      ) : (
        <table className="w-full border-collapse text-sm">
          <thead>
            <tr className="border-b text-left text-neutral-500">
              <th className="py-2">Name</th>
              <th className="py-2">Type</th>
              <th className="py-2">Linked Employee</th>
              <th className="py-2">Status</th>
              <th className="py-2 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((row) => (
              <tr key={row.id} className="border-b last:border-0">
                <td className="py-2 font-medium">{row.name}</td>
                <td className="py-2 text-neutral-500">{row.type ?? "—"}</td>
                <td className="py-2 text-neutral-500">
                  {row.employeeId ? employees.find((e) => e.id === row.employeeId)?.fullName ?? "—" : "—"}
                </td>
                <td className="py-2"><StatusBadge active={row.active} /></td>
                <td className="py-2 text-right space-x-3">
                  <button onClick={() => openEdit(row)} className="text-emerald-700 hover:underline">Edit</button>
                  <button
                    onClick={() => (row.active ? setConfirmTarget(row) : setActive("payees", row.id, true))}
                    className={row.active ? "text-red-600 hover:underline" : "text-emerald-700 hover:underline"}
                  >
                    {row.active ? "Deactivate" : "Reactivate"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <Modal open={modalOpen} title={editing ? "Edit Payee" : "Add Payee"} onClose={() => setModalOpen(false)}>
        <div className="space-y-3">
          <div>
            <label className="text-sm font-medium">Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          </div>
          <div>
            <label className="text-sm font-medium">Type</label>
            <select value={type} onChange={(e) => setType(e.target.value as PayeeType)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
              {PAYEE_TYPES.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm font-medium">Linked Employee (optional)</label>
            <select value={employeeId} onChange={(e) => setEmployeeId(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
              <option value="">None</option>
              {employees.map((e) => (
                <option key={e.id} value={e.id}>{e.fullName}</option>
              ))}
            </select>
          </div>
          {formError && <p className="text-sm text-red-600">{formError}</p>}
          <div className="flex justify-end gap-2 pt-2">
            <button onClick={() => setModalOpen(false)} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">Cancel</button>
            <button onClick={handleSave} disabled={saving} className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-60">
              {saving ? "Saving..." : "Save"}
            </button>
          </div>
        </div>
      </Modal>

      <ConfirmDialog
        open={!!confirmTarget}
        title="Deactivate Payee"
        message={`"${confirmTarget?.name}" will no longer be selectable for new transactions. Historical records are unaffected.`}
        confirmLabel="Deactivate"
        onConfirm={confirmDeactivate}
        onCancel={() => setConfirmTarget(null)}
      />
    </div>
  );
}
