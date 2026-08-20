"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
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
import type { ExpenseCategory } from "@/lib/types/config";

export default function ExpenseCategoriesPage() {
  const [rows, setRows] = useState<ExpenseCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<ExpenseCategory | null>(null);
  const [name, setName] = useState("");
  const [order, setOrder] = useState(0);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmTarget, setConfirmTarget] = useState<ExpenseCategory | null>(null);

  useEffect(() => {
    const unsub = listenAll<ExpenseCategory>("expense_categories", (r) => {
      setRows(r.sort((a, b) => (a.order ?? 0) - (b.order ?? 0)));
      setLoading(false);
    }, "order");
    return unsub;
  }, []);

  function openAdd() {
    setEditing(null);
    setName("");
    setOrder(rows.length + 1);
    setFormError(null);
    setModalOpen(true);
  }

  function openEdit(row: ExpenseCategory) {
    setEditing(row);
    setName(row.name);
    setOrder(row.order);
    setFormError(null);
    setModalOpen(true);
  }

  async function handleSave() {
    const trimmed = name.trim();
    if (!trimmed) return setFormError("Name is required.");
    if (isDuplicateName(rows, trimmed, editing?.id)) {
      return setFormError("A category with this name already exists.");
    }
    setSaving(true);
    try {
      const payload = { name: trimmed, order };
      if (editing) {
        await updateConfigDoc("expense_categories", editing.id, payload);
      } else {
        await createConfigDoc("expense_categories", payload);
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
    await setActive("expense_categories", confirmTarget.id, false);
    setConfirmTarget(null);
  }

  const filtered = rows.filter((r) => r.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Expense Categories</h1>
        <button onClick={openAdd} className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white">
          Add Category
        </button>
      </div>

      <SearchInput value={search} onChange={setSearch} placeholder="Search categories..." />

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-neutral-500">No categories found.</p>
      ) : (
        <table className="w-full border-collapse text-sm">
          <thead>
            <tr className="border-b text-left text-neutral-500">
              <th className="py-2">#</th>
              <th className="py-2">Name</th>
              <th className="py-2">Status</th>
              <th className="py-2 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((row) => (
              <tr key={row.id} className="border-b last:border-0">
                <td className="py-2 text-neutral-400">{row.order}</td>
                <td className="py-2 font-medium">
                  <Link href={`/settings/expense-categories/${row.id}`} className="text-emerald-700 hover:underline">
                    {row.name}
                  </Link>
                  <span className="ml-2 text-xs text-neutral-400">manage subcategories →</span>
                </td>
                <td className="py-2"><StatusBadge active={row.active} /></td>
                <td className="py-2 text-right space-x-3">
                  <button onClick={() => openEdit(row)} className="text-emerald-700 hover:underline">Edit</button>
                  <button
                    onClick={() => (row.active ? setConfirmTarget(row) : setActive("expense_categories", row.id, true))}
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

      <Modal open={modalOpen} title={editing ? "Edit Category" : "Add Category"} onClose={() => setModalOpen(false)}>
        <div className="space-y-3">
          <div>
            <label className="text-sm font-medium">Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          </div>
          <div>
            <label className="text-sm font-medium">Display Order</label>
            <input type="number" value={order} onChange={(e) => setOrder(Number(e.target.value))} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
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
        title="Deactivate Category"
        message={`"${confirmTarget?.name}" and its subcategories will no longer be selectable for new transactions. Historical records are unaffected.`}
        confirmLabel="Deactivate"
        onConfirm={confirmDeactivate}
        onCancel={() => setConfirmTarget(null)}
      />
    </div>
  );
}
