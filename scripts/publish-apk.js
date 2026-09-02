const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('./crud-a8dfc-firebase-adminsdk-bilyv-273980b78b.json');

const BUCKET_NAME = 'crud-a8dfc.firebasestorage.app';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: BUCKET_NAME,
  });
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

function getPubspecVersion() {
  const pubspecPath = path.join(__dirname, '../mobile/pubspec.yaml');
  if (!fs.existsSync(pubspecPath)) {
    return { version: '1.0.0', versionCode: 1 };
  }
  const content = fs.readFileSync(pubspecPath, 'utf8');
  const match = content.match(/version:\s*([0-9\.]+)\+([0-9]+)/);
  if (match) {
    return { version: match[1], versionCode: parseInt(match[2], 10) };
  }
  return { version: '1.0.0', versionCode: 1 };
}

async function publishApk() {
  const args = process.argv.slice(2);
  const apkFilePath = args[0] || path.join(__dirname, '../mobile/build/app/outputs/flutter-apk/app-release.apk');
  const releaseNotes = args[1] || '• Bug fixes and performance improvements\n• In-app update support';
  const forceUpdate = (args[2] || 'false').toLowerCase() === 'true';

  if (!fs.existsSync(apkFilePath)) {
    console.error(`\n❌ APK file not found at: ${apkFilePath}`);
    console.log(`Please build your release APK first by running:`);
    console.log(`  cd mobile && flutter build apk --release\n`);
    process.exit(1);
  }

  const { version, versionCode } = getPubspecVersion();
  const remoteFileName = `updates/corehives-v${version}.apk`;

  console.log(`\n📦 Uploading CoreHives v${version} (build ${versionCode}) to Firebase Storage...`);
  console.log(`Source APK: ${apkFilePath}`);
  console.log(`Destination: gs://${BUCKET_NAME}/${remoteFileName}`);

  // Generate a permanent download token
  const downloadToken = require('crypto').randomUUID();

  await bucket.upload(apkFilePath, {
    destination: remoteFileName,
    metadata: {
      contentType: 'application/vnd.android.package-archive',
      metadata: {
        firebaseStorageDownloadTokens: downloadToken,
      },
    },
  });

  const encodedPath = encodeURIComponent(remoteFileName);
  const publicDownloadUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET_NAME}/o/${encodedPath}?alt=media&token=${downloadToken}`;

  console.log(`\n✅ Upload complete!`);
  console.log(`Public APK URL: ${publicDownloadUrl}`);

  // Update Firestore config
  console.log(`\n📝 Updating Firestore app_config/android_update...`);
  const payload = {
    latestVersion: version,
    latestVersionCode: versionCode,
    minimumVersionCode: 1,
    forceUpdate: forceUpdate,
    apkUrl: publicDownloadUrl,
    releaseNotes: releaseNotes,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('app_config').doc('android_update').set(payload, { merge: true });

  console.log(`🎉 CoreHives v${version} is now LIVE for all users!`);
  console.log(JSON.stringify(payload, null, 2));
}

publishApk().catch((err) => {
  console.error('\n❌ Publish failed:', err);
  process.exit(1);
});
