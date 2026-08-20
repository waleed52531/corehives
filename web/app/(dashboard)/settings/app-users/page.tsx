"use client";

import { useEffect, useState } from "react";
import { collection, doc, onSnapshot, orderBy, query, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import type { AppUser, AppUserPermissions } from "@/lib/types/user";

const PERMISSION_KEYS: (keyof AppUserPermissions)[] = [
  "viewPayroll", "managePayroll", "viewEmployees", "manageEmployees", "viewReports",
];

export default function AppUsersPage() {
  const [users, setUsers] = useState<AppUser[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "users"), orderBy("name"));
    const unsub = onSnapshot(q, (snap) => {
      setUsers(snap.docs.map((d) => ({ ...(d.data() as Omit<AppUser, "uid">), uid: d.id })));
      setLoading(false);
    });
    return unsub;
  }, []);

  async function toggleActive(u: AppUser) {
    await updateDoc(doc(db, "users", u.uid), { active: !u.active });
  }

  async function setRole(u: AppUser, role: "admin" | "member") {
    await updateDoc(doc(db, "users", u.uid), { role });
  }

  async function togglePermission(u: AppUser, key: keyof AppUserPermissions) {
    const next = { ...u.permissions, [key]: !u.permissions[key] };
    await updateDoc(doc(db, "users", u.uid), { permissions: next });
  }

  return (
    <div className="space-y-4">
      <h1 className="text-lg font-semibold">App Users</h1>
      <p className="text-sm text-neutral-500">
        No public sign-up — accounts are created directly in Firebase Authentication / via an admin script,
        then appear here for role and permission management.
      </p>

      {loading ? (
        <p className="text-sm text-neutral-500">Loading...</p>
      ) : users.length === 0 ? (
        <p className="text-sm text-neutral-500">No users found.</p>
      ) : (
        <div className="space-y-3">
          {users.map((u) => (
            <div key={u.uid} className="rounded-lg border border-neutral-200 bg-white p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium">{u.name}</p>
                  <p className="text-sm text-neutral-500">{u.email}</p>
                </div>
                <div className="flex items-center gap-3">
                  <select
                    value={u.role}
                    onChange={(e) => setRole(u, e.target.value as "admin" | "member")}
                    className="rounded-md border border-neutral-300 px-2 py-1 text-sm"
                  >
                    <option value="admin">Admin</option>
                    <option value="member">Member</option>
                  </select>
                  <button
                    onClick={() => toggleActive(u)}
                    className={`rounded-full px-2 py-0.5 text-xs ${
                      u.active ? "bg-emerald-100 text-emerald-700" : "bg-neutral-200 text-neutral-600"
                    }`}
                  >
                    {u.active ? "Active" : "Inactive"}
                  </button>
                </div>
              </div>
              {u.role === "member" && (
                <div className="mt-3 flex flex-wrap gap-3 border-t pt-3 text-sm">
                  {PERMISSION_KEYS.map((key) => (
                    <label key={key} className="flex items-center gap-1.5">
                      <input
                        type="checkbox"
                        checked={u.permissions?.[key] ?? false}
                        onChange={() => togglePermission(u, key)}
                      />
                      {key}
                    </label>
                  ))}
                </div>
              )}
              {u.role === "admin" && (
                <p className="mt-2 text-xs text-neutral-400">Admins have all permissions implicitly.</p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
