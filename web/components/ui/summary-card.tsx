import Link from "next/link";
import { paisaToDisplay } from "@/lib/utils/money";

export function SummaryCard({
  label,
  paisa,
  tone = "neutral",
  href,
}: {
  label: string;
  paisa: number;
  tone?: "cashIn" | "cashOut" | "neutral";
  href?: string;
}) {
  const color =
    tone === "cashIn" ? "text-emerald-700" : tone === "cashOut" ? "text-red-600" : "text-neutral-900";
  
  const content = (
    <div className={`rounded-lg border border-neutral-200 bg-white p-4 transition ${href ? "hover:border-emerald-300 hover:shadow-sm" : ""}`}>
      <div className="flex items-center justify-between">
        <p className="text-xs text-neutral-500">{label}</p>
        {href && <span className="text-[10px] text-neutral-400">View &rarr;</span>}
      </div>
      <p className={`mt-1 text-xl font-semibold ${color}`}>{paisaToDisplay(paisa)}</p>
    </div>
  );

  if (href) {
    return <Link href={href}>{content}</Link>;
  }

  return content;
}
