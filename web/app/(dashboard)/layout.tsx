import Link from "next/link";

const navItems = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/transactions", label: "Transactions" },
  { href: "/employees", label: "Employees" },
  { href: "/payroll/current", label: "Payroll" },
  { href: "/reports/cash-flow", label: "Reports" },
  { href: "/settings/expense-categories", label: "Settings" },
];

export default function DashboardRootLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-neutral-50">
      <header className="border-b bg-white">
        <div className="mx-auto flex max-w-6xl items-center gap-6 px-6 py-3">
          <span className="font-semibold text-emerald-800">CoreHives</span>
          <nav className="flex gap-4 text-sm">
            {navItems.map((item) => (
              <Link key={item.href} href={item.href} className="text-neutral-600 hover:text-emerald-700">
                {item.label}
              </Link>
            ))}
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-6xl">{children}</main>
    </div>
  );
}
