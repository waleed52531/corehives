export function StatusBadge({ active }: { active: boolean }) {
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
        active ? "bg-emerald-100 text-emerald-700" : "bg-neutral-200 text-neutral-600"
      }`}
    >
      {active ? "Active" : "Inactive"}
    </span>
  );
}
