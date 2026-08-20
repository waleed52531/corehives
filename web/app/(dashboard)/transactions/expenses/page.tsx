import { TransactionTable } from "@/components/transactions/transaction-table";

export default function ExpensesPage() {
  return <TransactionTable title="Expenses" typeFilter="expense" />;
}
