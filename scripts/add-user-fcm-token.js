const admin = require("firebase-admin");
const readline = require("readline");
const path = require("path");

// Load the local service account key file
const serviceAccountPath = path.join(__dirname, "crud-a8dfc-firebase-adminsdk-bilyv-273980b78b.json");

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath)
  });
} catch (e) {
  console.error("Failed to initialize Firebase Admin SDK.");
  process.exit(1);
}

const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function ask(query) {
  return new Promise((resolve) => rl.question(query, resolve));
}

async function main() {
  console.log("=== Add FCM Token to User Profile ===");
  const email = await ask("Enter User Email: ");
  const token = await ask("Enter Device FCM Token to Add: ");
  rl.close();

  if (!email || !token) {
    console.error("Error: Email and Token are required.");
    process.exit(1);
  }

  try {
    console.log(`\n1. Finding user with email: ${email}...`);
    const usersSnap = await db.collection("users").where("email", "==", email.trim().toLowerCase()).get();

    if (usersSnap.empty) {
      console.error(`✗ User not found with email: ${email}`);
      process.exit(1);
    }

    const userDoc = usersSnap.docs[0];
    const userRef = userDoc.ref;
    
    console.log(`2. Adding token to user: ${userDoc.data().name}...`);
    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayUnion(token.trim()),
    });

    console.log("✓ Device FCM Token added successfully to user profile!");
    process.exit(0);
  } catch (error) {
    console.error("✗ Firestore update failed:", error.message);
    process.exit(1);
  }
}

main();
