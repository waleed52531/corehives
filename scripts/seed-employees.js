const admin = require("firebase-admin");

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS && !process.env.FIRESTORE_EMULATOR_HOST) {
  console.warn("WARNING: Neither GOOGLE_APPLICATION_CREDENTIALS nor FIRESTORE_EMULATOR_HOST is set.");
  console.warn("If this fails, please run with proper credentials or emulator host.");
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "crud-a8dfc"
});
const db = admin.firestore();

const SYSTEM_UID = "seed-script";
const now = () => admin.firestore.FieldValue.serverTimestamp();

function slug(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

const EMPLOYEES_TO_SEED = [
  { name: "Zain", salary: 220000, code: "CH-001", bankName: "Meezan Bank", bankAccountOrIban: "PK12MEZN0000123456789012" },
  { name: "Hanzalah", salary: 220000, code: "CH-002", bankName: "Habib Bank Limited (HBL)", bankAccountOrIban: "PK34HABB0000987654321098" },
  { name: "Ishtiaq", salary: 60000, code: "CH-003", bankName: "United Bank Limited (UBL)", bankAccountOrIban: "PK56UNIL0000456123789456" },
  { name: "Raja", salary: 35000, code: "CH-004", bankName: "Easypaisa Bank", bankAccountOrIban: "03001234567" },
  { name: "Taha", salary: 100000, code: "CH-005", bankName: "Bank Alfalah", bankAccountOrIban: "PK78ALFA0000321654987123" },
  { name: "Hamza", salary: 30000, code: "CH-006", bankName: "Meezan Bank", bankAccountOrIban: "PK12MEZN0000654321098765" },
  { name: "IzzatUllah", salary: 65000, code: "CH-007", bankName: "National Bank of Pakistan (NBP)", bankAccountOrIban: "PK90NAPB0000111222333444" },
  { name: "Areeba", salary: 80000, code: "CH-008", bankName: "Standard Chartered Pakistan", bankAccountOrIban: "PK21SCBL0000555666777888" },
  { name: "Simran", salary: 75000, code: "CH-009", bankName: "Askari Bank", bankAccountOrIban: "PK43ASKB0000999888777666" }
];

async function main() {
  let createdEmp = 0;
  let createdComp = 0;

  for (const emp of EMPLOYEES_TO_SEED) {
    const id = slug(emp.name);
    const empRef = db.collection("employees").doc(id);
    const compRef = db.collection("employee_compensation").doc(id);

    const empSnap = await empRef.get();
    if (!empSnap.exists) {
      await empRef.set({
        fullName: emp.name,
        employeeCode: emp.code,
        jobTitle: "Software Engineer",
        departmentId: "development",
        employmentType: "Full-Time",
        employmentStatus: "Active",
        joiningDate: "2026-01-01",
        workLocation: "Office",
        bankName: emp.bankName,
        bankAccountOrIban: emp.bankAccountOrIban,
        createdAt: now(),
        createdByUserId: SYSTEM_UID,
        updatedAt: now(),
        updatedByUserId: SYSTEM_UID
      });
      createdEmp++;
    } else {
      // Update existing records with bank details if missing
      await empRef.set({
        bankName: emp.bankName,
        bankAccountOrIban: emp.bankAccountOrIban,
        updatedAt: now(),
        updatedByUserId: SYSTEM_UID
      }, { merge: true });
    }

    const compSnap = await compRef.get();
    if (!compSnap.exists) {
      await compRef.set({
        employeeId: id,
        baseSalaryPaisa: emp.salary * 100,
        currency: "PKR",
        compensationType: "Salary",
        effectiveFrom: "2026-01-01",
        updatedAt: now(),
        updatedBy: SYSTEM_UID
      });
      createdComp++;
    }
  }

  console.log(`Employees: ${createdEmp} created/updated, ${EMPLOYEES_TO_SEED.length - createdEmp} already existed`);
  console.log(`Compensations: ${createdComp} created, ${EMPLOYEES_TO_SEED.length - createdComp} already existed`);
  process.exit(0);
}

main().catch(err => {
  console.error("Seeding failed:", err);
  process.exit(1);
});
