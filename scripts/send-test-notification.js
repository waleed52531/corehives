const admin = require("firebase-admin");
const path = require("path");

const sa = path.join(__dirname, "crud-a8dfc-firebase-adminsdk-bilyv-273980b78b.json");

try {
  admin.initializeApp({
    credential: admin.credential.cert(sa)
  });
} catch (e) {
  console.error("Failed to initialize Firebase Admin SDK.");
  process.exit(1);
}

const db = admin.firestore();
const email = process.argv[2] || 'zain@corehives.com';

async function main() {
  try {
    console.log(`Finding user: ${email}...`);
    const usersSnap = await db.collection("users").where("email", "==", email.trim().toLowerCase()).get();
    
    if (usersSnap.empty) {
      console.error(`✗ User not found with email: ${email}`);
      process.exit(1);
    }
    
    const userDoc = usersSnap.docs[0];
    console.log(`Sending test notification to ${userDoc.data().name}...`);
    
    await userDoc.ref.collection("notifications").add({
      title: 'Test Notification',
      body: 'This is a test notification to verify your in-app notification center is working!',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      transactionId: '',
      type: 'pending_withdrawal'
    });
    
    console.log("✓ Test notification created in database successfully!");
    process.exit(0);
  } catch (error) {
    console.error("✗ Failed to send notification:", error.message);
    process.exit(1);
  }
}

main();
