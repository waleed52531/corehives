import { TransactionTable } from "@/components/transactions/transaction-table";

export default function LateEntriesPage() {
  return <TransactionTable title="Late Entries" lateOnly />;
}
