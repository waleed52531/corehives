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

interface Row {
  id: string;
  name: string;
  notes?: string;
  active: boolean;
}

/**
 * Reusable list/CRUD page for collections shaped as { name, notes?, active }.
 * Used by: departments, revenue_sources, upwork_accounts.
 * Not intended as a generic framework — extend with a dedicated page
 * (see projects/payees/expense-categories) once a collection needs
 * fields beyond name/notes.
 */
export function SimpleConfigManager({
  collectionName,
  title,
  hasNotes = false,
  singularLabel,
}: {
  collectionName: string;
  title: string;
  hasNotes?: boolean;
  singularLabel: string;
}) {
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Row | null>(null);
  const [name, setName] = useState("");
  const [notes, setNotes] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmTarget, setConfirmTarget] = useState<Row | null>(null);

  useEffect(() => {
    const unsub = listenAll<Row>(collectionName, (r) => {
      setRows(r);
      setLoading(false);
    });
    return unsub;
  }, [collectionName]);

  function openAdd() {
    setEditing(null);
    setName("");
    setNotes("");
    setFormError(null);
    setModalOpen(true);
  }

  function openEdit(row: Row) {
    setEditing(row);
    setName(row.name);
    setNotes(row.notes ?? "");
    setFormError(null);
    setModalOpen(true);
  }

  async function handleSave() {
    const trimmed = name.trim();
    if (!trimmed) {
      setFormError("Name is required.");
      return;
    }
    if (isDuplicateName(rows, trimmed, editing?.id)) {
      setFormError("A record with this name already exists.");
      return;
    }
    setSaving(true);
    try {
      const payload: Record<string, unknown> = { name: trimmed };
      if (hasNotes) payload.notes = notes.trim();
      if (editing) {
        await updateConfigDoc(collectionName, editing.id, payload);
      } else {
        await createConfigDoc(collectionName, payload);
      }
      setModalOpen(false);
    } catch {
      setFormError("Could not save. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(row: Row) {
    if (row.active) {
      setConfirmTarget(row);
    } else {
      await setActive(collectionName, row.id, true);
    }
  }

  async function confirmDeactivate() {
    if (!confirmTarget) return;
    await setActive(collectionName, confirmTarget.id, false);
    setConfirmTarget(null);
  }

  const filtered = rows.filter((r) =>
    r.name.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">{title}</h1>
        <button
          onClick={openAdd}
          className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white"
        >
          Add {singularLabel}
        </button>
      </div>

      <SearchInput value={search} onChange={setSearch} placeholder={`Search ${title.toLowerCase()}...`} />

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-neutral-500">No {title.toLowerCase()} found.</p>
      ) : (
        <table className="w-full border-collapse text-sm">
          <thead>
            <tr className="border-b text-left text-neutral-500">
              <th className="py-2">Name</th>
              {hasNotes && <th className="py-2">Notes</th>}
              <th className="py-2">Status</th>
              <th className="py-2 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((row) => (
              <tr key={row.id} className="border-b last:border-0">
                <td className="py-2 font-medium">{row.name}</td>
                {hasNotes && <td className="py-2 text-neutral-500">{row.notes || "—"}</td>}
                <td className="py-2">
                  <StatusBadge active={row.active} />
                </td>
                <td className="py-2 text-right space-x-3">
                  <button onClick={() => openEdit(row)} className="text-emerald-700 hover:underline">
                    Edit
                  </button>
                  <button
                    onClick={() => toggleActive(row)}
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

      <Modal open={modalOpen} title={editing ? `Edit ${singularLabel}` : `Add ${singularLabel}`} onClose={() => setModalOpen(false)}>
        <div className="space-y-3">
          <div>
            <label className="text-sm font-medium">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
            />
          </div>
          {hasNotes && (
            <div>
              <label className="text-sm font-medium">Notes</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
                rows={2}
              />
            </div>
          )}
          {formError && <p className="text-sm text-red-600">{formError}</p>}
          <div className="flex justify-end gap-2 pt-2">
            <button onClick={() => setModalOpen(false)} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-60"
            >
              {saving ? "Saving..." : "Save"}
            </button>
          </div>
        </div>
      </Modal>

      <ConfirmDialog
        open={!!confirmTarget}
        title={`Deactivate ${singularLabel}`}
        message={`"${confirmTarget?.name}" will no longer be selectable for new transactions. Historical records are unaffected.`}
        confirmLabel="Deactivate"
        onConfirm={confirmDeactivate}
        onCancel={() => setConfirmTarget(null)}
      />
    </div>
  );
}
