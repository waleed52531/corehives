import { paisaToDisplay } from "@/lib/utils/money";

export function SummaryCard({
  label,
  paisa,
  tone = "neutral",
}: {
  label: string;
  paisa: number;
  tone?: "cashIn" | "cashOut" | "neutral";
}) {
  const color =
    tone === "cashIn" ? "text-emerald-700" : tone === "cashOut" ? "text-red-600" : "text-neutral-900";
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4">
      <p className="text-xs text-neutral-500">{label}</p>
      <p className={`mt-1 text-xl font-semibold ${color}`}>{paisaToDisplay(paisa)}</p>
    </div>
  );
}
