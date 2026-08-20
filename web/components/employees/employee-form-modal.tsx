"use client";

import { useEffect, useState } from "react";
import { doc, addDoc, collection, updateDoc, serverTimestamp } from "firebase/firestore";
import { db, auth } from "@/lib/firebase/client";
import { Modal } from "@/components/ui/modal";
import type { Employee } from "@/lib/types/employee";

const EMPLOYMENT_TYPES = ["Full-Time", "Part-Time", "Contract", "Intern", "Partner", "Freelancer"];
const EMPLOYMENT_STATUSES = ["Active", "Inactive", "On Leave", "Resigned", "Terminated"];

export function EmployeeFormModal({
  open,
  onClose,
  editing,
}: {
  open: boolean;
  onClose: () => void;
  editing: Employee | null;
}) {
  const [fullName, setFullName] = useState("");
  const [employeeCode, setEmployeeCode] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [employmentType, setEmploymentType] = useState("Full-Time");
  const [employmentStatus, setEmploymentStatus] = useState("Active");
  const [companyEmail, setCompanyEmail] = useState("");
  const [phoneNumber, setPhoneNumber] = useState("");
  const [whatsappNumber, setWhatsappNumber] = useState("");
  const [joiningDate, setJoiningDate] = useState("");
  const [workLocation, setWorkLocation] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (editing) {
      setFullName(editing.fullName);
      setEmployeeCode(editing.employeeCode);
      setJobTitle(editing.jobTitle);
      setEmploymentType(editing.employmentType);
      setEmploymentStatus(editing.employmentStatus);
      setCompanyEmail(editing.companyEmail ?? "");
      setPhoneNumber(editing.phoneNumber ?? "");
      setWhatsappNumber(editing.whatsappNumber ?? "");
      setJoiningDate(editing.joiningDate ?? "");
      setWorkLocation(editing.workLocation ?? "");
    } else {
      setFullName(""); setEmployeeCode(""); setJobTitle("");
      setEmploymentType("Full-Time"); setEmploymentStatus("Active");
      setCompanyEmail(""); setPhoneNumber(""); setWhatsappNumber("");
      setJoiningDate(""); setWorkLocation("");
    }
    setError(null);
  }, [editing, open]);

  async function handleSave() {
    if (!fullName.trim()) return setError("Full name is required.");
    const uid = auth.currentUser?.uid;
    if (!uid) return setError("Not signed in.");

    setSaving(true);
    try {
      const payload = {
        fullName: fullName.trim(),
        employeeCode: employeeCode.trim(),
        jobTitle: jobTitle.trim(),
        employmentType,
        employmentStatus,
        companyEmail: companyEmail.trim(),
        phoneNumber: phoneNumber.trim(),
        whatsappNumber: whatsappNumber.trim(),
        joiningDate: joiningDate || null,
        workLocation: workLocation.trim(),
      };
      if (editing) {
        await updateDoc(doc(db, "employees", editing.id), {
          ...payload,
          updatedAt: serverTimestamp(),
          updatedByUserId: uid,
        });
      } else {
        await addDoc(collection(db, "employees"), {
          ...payload,
          createdAt: serverTimestamp(),
          createdByUserId: uid,
          updatedAt: serverTimestamp(),
          updatedByUserId: uid,
        });
      }
      onClose();
    } catch {
      setError("Could not save employee. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} title={editing ? "Edit Employee" : "Add Employee"} onClose={onClose}>
      <div className="max-h-[70vh] space-y-3 overflow-y-auto pr-1">
        <Field label="Full Name" value={fullName} onChange={setFullName} />
        <Field label="Employee Code" value={employeeCode} onChange={setEmployeeCode} />
        <Field label="Job Title" value={jobTitle} onChange={setJobTitle} />
        <div>
          <label className="text-sm font-medium">Employment Type</label>
          <select value={employmentType} onChange={(e) => setEmploymentType(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
            {EMPLOYMENT_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
        </div>
        <div>
          <label className="text-sm font-medium">Employment Status</label>
          <select value={employmentStatus} onChange={(e) => setEmploymentStatus(e.target.value)} className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm">
            {EMPLOYMENT_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>
        <Field label="Company Email" value={companyEmail} onChange={setCompanyEmail} type="email" />
        <Field label="Phone Number" value={phoneNumber} onChange={setPhoneNumber} />
        <Field label="WhatsApp Number" value={whatsappNumber} onChange={setWhatsappNumber} />
        <Field label="Joining Date" value={joiningDate} onChange={setJoiningDate} type="date" />
        <Field label="Work Location" value={workLocation} onChange={setWorkLocation} />
        {error && <p className="text-sm text-red-600">{error}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm">Cancel</button>
          <button onClick={handleSave} disabled={saving} className="rounded-md bg-emerald-700 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-60">
            {saving ? "Saving..." : "Save"}
          </button>
        </div>
      </div>
    </Modal>
  );
}

function Field({
  label, value, onChange, type = "text",
}: { label: string; value: string; onChange: (v: string) => void; type?: string }) {
  return (
    <div>
      <label className="text-sm font-medium">{label}</label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
      />
    </div>
  );
}
