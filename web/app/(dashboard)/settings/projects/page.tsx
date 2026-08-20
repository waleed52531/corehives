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
import type { Project, ProjectType } from "@/lib/types/config";

const PROJECT_TYPES: ProjectType[] = ["Company", "Internal Product", "Client Project", "Other"];

export default function ProjectsPage() {
  const [rows, setRows] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Project | null>(null);
  const [name, setName] = useState("");
  const [type, setType] = useState<ProjectType>("Client Project");
  const [notes, setNotes] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmTarget, setConfirmTarget] = useState<Project | null>(null);

  useEffect(() => {
    const unsub = listenAll<Project>("projects", (r) => {
      setRows(r);
      setLoading(false);
    });
    return unsub;
  }, []);

  function openAdd() {
    setEditing(null);
    setName("");
    setType("Client Project");
    setNotes("");
    setFormError(null);
    setModalOpen(true);
  }

  function openEdit(row: Project) {
    setEditing(row);
    setName(row.name);
    setType(row.type);
    setNotes(row.notes ?? "");
    setFormError(null);
    setModalOpen(true);
  }

  async function handleSave() {
    const trimmed = name.trim();
    if (!trimmed) return setFormError("Name is required.");
    if (isDuplicateName(rows, trimmed, editing?.id)) {
      return setFormError("A project with this name already exists.");
    }
    setSaving(true);
    try {
      const payload = { name: trimmed, type, notes: notes.trim() };
      if (editing) {
        await updateConfigDoc("projects", editing.id, payload);
      } else {
        await createConfigDoc("projects", payload);
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
    await setActive("projects", confirmTarget.id, false);
    setConfirmTarget(null);
  }

  const filtered = rows.filter((r) => r.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">Projects</h1>
        <button onClick={openAdd} className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white">
          Add Project
        </button>
      </div>

      <SearchInput value={search} onChange={setSearch} placeholder="Search projects..." />

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-neutral-500">No projects found.</p>
      ) : (
        <table className="w-full border-collapse text-sm">
          <thead>
            <tr className="border-b text-left text-neutral-500">
              <th className="py-2">Name</th>
              <th className="py-2">Type</th>
              <th className="py-2">Status</th>
              <th className="py-2 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((row) => (
              <tr key={row.id} className="border-b last:border-0">
                <td className="py-2 font-medium">{row.name}</td>
                <td className="py-2 text-neutral-500">{row.type}</td>
                <td className="py-2"><StatusBadge active={row.active} /></td>
                <td className="py-2 text-right space-x-3">
                  <button onClick={() => openEdit(row)} className="text-emerald-700 hover:underline">Edit</button>
                  <button
                    onClick={() => (row.active ? setConfirmTarget(row) : setActive("projects", row.id, true))}
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

      <Modal open={modalOpen} title={editing ? "Edit Project" : "Add Project"} onClose={() => setModalOpen(false)}>
        <div className="space-y-3">
          <div>
            <label className="text-sm font-medium">Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
          </div>
          <div>
            <label className="text-sm font-medium">Type</label>
            <select value={type} onChange={(e) => setType(e.target.value as ProjectType)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
              {PROJECT_TYPES.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm font-medium">Notes</label>
            <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={2} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm" />
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
        title="Deactivate Project"
        message={`"${confirmTarget?.name}" will no longer be selectable for new transactions. Historical records are unaffected.`}
        confirmLabel="Deactivate"
        onConfirm={confirmDeactivate}
        onCancel={() => setConfirmTarget(null)}
      />
    </div>
  );
}
