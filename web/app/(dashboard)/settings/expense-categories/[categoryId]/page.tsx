"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { collection, doc, getDoc, onSnapshot, query, where, orderBy } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import {
  createConfigDoc,
  updateConfigDoc,
  setActive,
  isDuplicateName,
} from "@/lib/firebase/config-repo";
import { StatusBadge } from "@/components/ui/status-badge";
import { Modal } from "@/components/ui/modal";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import type { ExpenseCategory, ExpenseSubcategory } from "@/lib/types/config";

export default function SubcategoriesPage() {
  const params = useParams<{ categoryId: string }>();
  const categoryId = params.categoryId;

  const [category, setCategory] = useState<ExpenseCategory | null>(null);
  const [rows, setRows] = useState<ExpenseSubcategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<ExpenseSubcategory | null>(null);
  const [name, setName] = useState("");
  const [order, setOrder] = useState(0);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmTarget, setConfirmTarget] = useState<ExpenseSubcategory | null>(null);

  useEffect(() => {
    getDoc(doc(db, "expense_categories", categoryId)).then((snap) => {
      if (snap.exists()) setCategory({ ...(snap.data() as ExpenseCategory), id: snap.id });
    });
  }, [categoryId]);

  useEffect(() => {
    const q = query(
      collection(db, "expense_subcategories"),
      where("categoryId", "==", categoryId),
      orderBy("order")
    );
    const unsub = onSnapshot(q, (snap) => {
      setRows(snap.docs.map((d) => ({ ...(d.data() as ExpenseSubcategory), id: d.id })));
      setLoading(false);
    });
    return unsub;
  }, [categoryId]);

  function openAdd() {
    setEditing(null);
    setName("");
    setOrder(rows.length + 1);
    setFormError(null);
    setModalOpen(true);
  }

  function openEdit(row: ExpenseSubcategory) {
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
      return setFormError("A subcategory with this name already exists in this category.");
    }
    setSaving(true);
    try {
      const payload = { name: trimmed, order, categoryId };
      if (editing) {
        await updateConfigDoc("expense_subcategories", editing.id, payload);
      } else {
        await createConfigDoc("expense_subcategories", payload);
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
    await setActive("expense_subcategories", confirmTarget.id, false);
    setConfirmTarget(null);
  }

  return (
    <div className="space-y-4">
      <Link href="/settings/expense-categories" className="text-sm text-emerald-700 hover:underline">
        ← All Categories
      </Link>
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">
          Subcategories {category ? `— ${category.name}` : ""}
        </h1>
        <button onClick={openAdd} className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white">
          Add Subcategory
        </button>
      </div>

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-neutral-500">No subcategories yet.</p>
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
            {rows.map((row) => (
              <tr key={row.id} className="border-b last:border-0">
                <td className="py-2 text-neutral-400">{row.order}</td>
                <td className="py-2 font-medium">{row.name}</td>
                <td className="py-2"><StatusBadge active={row.active} /></td>
                <td className="py-2 text-right space-x-3">
                  <button onClick={() => openEdit(row)} className="text-emerald-700 hover:underline">Edit</button>
                  <button
                    onClick={() => (row.active ? setConfirmTarget(row) : setActive("expense_subcategories", row.id, true))}
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

      <Modal open={modalOpen} title={editing ? "Edit Subcategory" : "Add Subcategory"} onClose={() => setModalOpen(false)}>
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
        title="Deactivate Subcategory"
        message={`"${confirmTarget?.name}" will no longer be selectable for new transactions. Historical records are unaffected.`}
        confirmLabel="Deactivate"
        onConfirm={confirmDeactivate}
        onCancel={() => setConfirmTarget(null)}
      />
    </div>
  );
}
