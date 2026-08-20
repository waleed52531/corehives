"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { currentMonthKey } from "@/lib/firebase/use-month-transactions";

export default function PayrollCurrentPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace(`/payroll/${currentMonthKey()}`);
  }, [router]);
  return <p className="p-6 text-sm text-neutral-500">Loading current month payroll...</p>;
}
