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
  console.error("Failed to initialize Firebase Admin SDK. Make sure the service account JSON is in the scripts directory.");
  process.exit(1);
}

const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

rl.question("Enter FCM Server Key: ", async (serverKey) => {
  rl.close();
  if (!serverKey || !serverKey.trim()) {
    console.error("Error: FCM Server Key is required.");
    process.exit(1);
  }

  try {
    console.log("\nWriting Server Key to Firestore (/app_settings/fcm)...");
    await db.collection("app_settings").doc("fcm").set({
      serverKey: serverKey.trim(),
    }, { merge: true });
    console.log("✓ Server Key saved successfully using the Service Account!");
    process.exit(0);
  } catch (error) {
    console.error("✗ Firestore write failed:", error.message);
    process.exit(1);
  }
});
