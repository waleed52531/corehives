const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const serviceAccountPath = path.join(__dirname, "crud-a8dfc-firebase-adminsdk-bilyv-273980b78b.json");

let saContent;
try {
  saContent = fs.readFileSync(serviceAccountPath, "utf8");
} catch (e) {
  console.error("Error: Could not read service account file. Make sure it is in the scripts directory.");
  process.exit(1);
}

try {
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(saContent))
  });
} catch (e) {
  console.error("Failed to initialize Firebase Admin SDK:", e.message);
  process.exit(1);
}

const db = admin.firestore();

async function main() {
  try {
    console.log("Reading service account details...");
    console.log("Uploading Service Account JSON to Firestore (/app_settings/fcm) -> serviceAccountJson...");
    
    await db.collection("app_settings").doc("fcm").set({
      serviceAccountJson: saContent
    }, { merge: true });

    console.log("✓ Service Account JSON uploaded successfully to your live Firestore database!");
    process.exit(0);
  } catch (error) {
    console.error("✗ Firestore upload failed:", error.message);
    process.exit(1);
  }
}

main();
