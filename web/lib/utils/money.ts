/** PKR amounts are always stored/passed as integer paisa (1 PKR = 100 paisa). */
export function paisaToDisplay(paisa: number): string {
  const rupees = paisa / 100;
  return new Intl.NumberFormat("en-PK", {
    style: "currency",
    currency: "PKR",
    maximumFractionDigits: 0,
  }).format(rupees);
}

export function rupeesToPaisa(rupees: number): number {
  return Math.round(rupees * 100);
}
