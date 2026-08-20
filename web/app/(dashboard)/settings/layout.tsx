import Link from "next/link";

const links = [
  { href: "/settings/expense-categories", label: "Expense Categories" },
  { href: "/settings/projects", label: "Projects" },
  { href: "/settings/payees", label: "Payees" },
  { href: "/settings/upwork-accounts", label: "Upwork Accounts" },
  { href: "/settings/revenue-sources", label: "Cash-In Sources" },
  { href: "/settings/departments", label: "Departments" },
  { href: "/settings/app-users", label: "App Users" },
];

export default function SettingsLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex max-w-5xl gap-8 p-6">
      <nav className="w-48 shrink-0 space-y-1">
        <h2 className="mb-2 text-xs font-semibold uppercase text-neutral-400">Settings</h2>
        {links.map((l) => (
          <Link key={l.href} href={l.href} className="block rounded-md px-2 py-1.5 text-sm text-neutral-600 hover:bg-neutral-100">
            {l.label}
          </Link>
        ))}
      </nav>
      <div className="flex-1">{children}</div>
    </div>
  );
}
