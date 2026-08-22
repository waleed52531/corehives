/** transactionDateKey = YYYY-MM-DD, monthKey = YYYY-MM — business dates, Asia/Karachi. */
export function monthKeyFromDate(d: Date): string {
  if (d.getDate() >= 10) {
    const next = new Date(d.getFullYear(), d.getMonth() + 1, 1);
    const y = next.getFullYear().toString().padStart(4, "0");
    const m = (next.getMonth() + 1).toString().padStart(2, "0");
    return `${y}-${m}`;
  } else {
    const y = d.getFullYear().toString().padStart(4, "0");
    const m = (d.getMonth() + 1).toString().padStart(2, "0");
    return `${y}-${m}`;
  }
}

export function dateKeyFromDate(d: Date): string {
  const y = d.getFullYear().toString().padStart(4, "0");
  const m = (d.getMonth() + 1).toString().padStart(2, "0");
  const day = d.getDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function currentMonthKey(): string {
  return monthKeyFromDate(new Date());
}
