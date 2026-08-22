/**
 * Idempotent seed script for CoreHives configuration collections.
 *
 * Usage:
 *   node seed-config.js
 *
 * Requires a service account key. Set env var:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
 *
 * Safe to re-run: uses deterministic slug IDs derived from each record's
 * name, and only creates a doc if it does not already exist. Existing
 * docs are left untouched (never overwritten), so manual edits made in
 * the admin UI after seeding are never clobbered by re-running this script.
 */
const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

const SYSTEM_UID = "seed-script";
const now = () => admin.firestore.FieldValue.serverTimestamp();

function slug(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

async function seedCollection(collectionName, items, extraFieldsFn = () => ({})) {
  let created = 0;
  for (const item of items) {
    const id = slug(item.name);
    const ref = db.collection(collectionName).doc(id);
    const snap = await ref.get();
    if (snap.exists) continue;
    await ref.set({
      name: item.name,
      active: true,
      ...extraFieldsFn(item),
      createdAt: now(),
      createdByUserId: SYSTEM_UID,
      updatedAt: now(),
      updatedByUserId: SYSTEM_UID,
    });
    created++;
  }
  console.log(`${collectionName}: ${created} created, ${items.length - created} already existed`);
}

async function main() {
  await seedCollection("departments", [
    { name: "Management" },
    { name: "Development" },
    { name: "Design" },
    { name: "Sales" },
    { name: "Business Development" },
    { name: "Marketing" },
    { name: "HR / Operations" },
    { name: "Finance" },
    { name: "Support" },
    { name: "Other" },
  ]);

  await seedCollection("upwork_accounts", [
    { name: "Zain ID" },
    { name: "Hanzalah ID" },
    { name: "Alina ID" },
    { name: "Abiha ID" },
  ]);

  await seedCollection("revenue_sources", [
    { name: "Upwork" },
    { name: "Front Sale" },
    { name: "PayPal" },
    { name: "Direct Client" },
    { name: "Fiverr" },
    { name: "Other" },
  ], (item, i) => ({}));

  await seedCollection(
    "projects",
    [
      { name: "CoreHives", type: "Company" },
      { name: "ZihuBridge", type: "Internal Product" },
      { name: "Curelia", type: "Internal Product" },
      { name: "CoreClinicSolutions", type: "Internal Product" },
      { name: "Ascendra", type: "Internal Product" },
      { name: "General Company", type: "Company" },
    ],
    (item) => ({ type: item.type, notes: "" })
  );

  const categories = [
    { name: "Office & Facilities", order: 1, subcategories: [
      "Office Rent", "Office Maintenance", "Electricity", "Internet", "Drinking Water",
      "Cleaning / Fumigation", "Gardener", "Office Supplies", "Kitchen / Pantry", "Other Office Expense",
    ]},
    { name: "Development & Project Costs", order: 2, subcategories: [
      "Developer Payment", "Designer Payment", "UI/UX", "Project Contractor",
      "API / Credits", "Project Expense", "Other Development Cost",
    ]},
    { name: "Software & Subscriptions", order: 3, subcategories: [
      "AI Tools", "Communication Tools", "Zoom", "Hosting", "VPS / Servers", "Domains",
      "Social Media / Verification", "General Software", "Other Software",
    ]},
    { name: "Freelancing Platform Costs", order: 4, subcategories: [
      "Upwork Connects", "Upwork Subscription", "Freelancer Subscription",
      "Fiverr Expense", "Platform Fees", "Other Platform Cost",
    ]},
    { name: "Sales & Business Development", order: 5, subcategories: [
      "Sales Commission", "Lead Generation", "Sales Tools",
      "Client Acquisition", "Business Development Expense", "Other Sales Expense",
    ]},
    { name: "Banking & Payment Fees", order: 6, subcategories: [
      "Wise Fees", "Stripe Fees", "Bank Charges", "Withdrawal Fees",
      "Currency Conversion Fees", "Payment Processing", "Other Financial Fees",
    ]},
    { name: "Food & Refreshments", order: 7, subcategories: [
      "Office Dinner", "Team Meal", "Office Pantry", "Celebration Food", "Client Meal", "Other Food",
    ]},
    { name: "Team Activities & Entertainment", order: 8, subcategories: [
      "Team Outing", "Movie", "Trip", "Celebration", "Event", "Other Entertainment",
    ]},
    { name: "Transport & Delivery", order: 9, subcategories: [
      "Bykea", "Courier", "Fuel", "Ride / Taxi", "Delivery", "Other Transport",
    ]},
    { name: "Legal & Company Administration", order: 10, subcategories: [
      "Company Registration", "Legal Fees", "Government Fees", "Licenses",
      "Documentation", "Professional Fees", "Other Administrative Cost",
    ]},
    { name: "Charity / Donations", order: 11, subcategories: [
      "Sadqa", "Donation", "Charity", "Other",
    ]},
    { name: "Payroll & Compensation", order: 12, subcategories: [
      "Salary", "Partner Compensation", "Contractor Payment", "Stipend",
      "Bonus", "Allowance", "Other Compensation",
    ]},
    { name: "Miscellaneous", order: 13, subcategories: ["Miscellaneous"] },
  ];

  await seedCollection(
    "expense_categories",
    categories,
    (item) => ({ order: item.order })
  );

  let subCreated = 0, subTotal = 0;
  for (const cat of categories) {
    const categoryId = slug(cat.name);
    for (let i = 0; i < cat.subcategories.length; i++) {
      subTotal++;
      const subName = cat.subcategories[i];
      const subId = `${categoryId}__${slug(subName)}`;
      const ref = db.collection("expense_subcategories").doc(subId);
      const snap = await ref.get();
      if (snap.exists) continue;
      await ref.set({
        categoryId,
        name: subName,
        order: i + 1,
        active: true,
        createdAt: now(),
        createdByUserId: SYSTEM_UID,
        updatedAt: now(),
        updatedByUserId: SYSTEM_UID,
      });
      subCreated++;
    }
  }
  console.log(`expense_subcategories: ${subCreated} created, ${subTotal - subCreated} already existed`);

  console.log("Seed complete.");
}

main().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
