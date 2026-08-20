"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import type { Transaction } from "@/lib/types/transaction";

export function useMonthTransactions(monthKey: string) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    const q = query(collection(db, "transactions"), where("monthKey", "==", monthKey));
    const unsub = onSnapshot(q, (snap) => {
      const rows = snap.docs
        .map((d) => ({ ...(d.data() as Omit<Transaction, "id">), id: d.id }))
        .filter((t) => !t.deletedAt)
        .sort((a, b) => (a.transactionDateKey < b.transactionDateKey ? 1 : -1));
      setTransactions(rows);
      setLoading(false);
    });
    return unsub;
  }, [monthKey]);

  return { transactions, loading };
}

export function currentMonthKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}
