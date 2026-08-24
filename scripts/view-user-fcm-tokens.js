const admin = require("firebase-admin");
const path = require("path");

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

const email = process.argv[2];

if (!email || !email.trim()) {
  console.log("Usage: node scripts/view-user-fcm-tokens.js <email>");
  process.exit(1);
}

async function main() {
  try {
    const usersSnap = await db.collection("users").where("email", "==", email.trim().toLowerCase()).get();

    if (usersSnap.empty) {
      console.log(`✗ No user found with email: ${email}`);
      process.exit(0);
    }

    const data = usersSnap.docs[0].data();
    console.log(`\nUser Profile: ${data.name} (${data.email})`);
    console.log("-----------------------------------------");
    if (Array.isArray(data.fcmTokens)) {
      console.log(`Total Tokens: ${data.fcmTokens.length}`);
      data.fcmTokens.forEach((token, index) => {
        console.log(`[${index + 1}] ${token}`);
      });
    } else {
      console.log("FCM Tokens: No tokens registered yet (field is empty or not an array).");
    }
    process.exit(0);
  } catch (error) {
    console.error("Error reading from Firestore:", error.message);
    process.exit(1);
  }
}

main();
