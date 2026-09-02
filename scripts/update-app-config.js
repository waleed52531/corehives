const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require('./crud-a8dfc-firebase-adminsdk-bilyv-273980b78b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function main() {
  const args = process.argv.slice(2);
  const docRef = db.collection('app_config').doc('android_update');

  if (args.length === 0 || args[0] === 'get') {
    const doc = await docRef.get();
    if (!doc.exists) {
      console.log('No android_update document found in app_config.');
      console.log('\nInitializing default config...');
      const defaultConfig = {
        latestVersion: '0.2.0',
        latestVersionCode: 2,
        minimumVersionCode: 1,
        forceUpdate: true,
        apkUrl: 'https://example.com/corehives.apk',
        releaseNotes: '• Initial release and performance improvements',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await docRef.set(defaultConfig);
      console.log('Default config initialized:', defaultConfig);
    } else {
      console.log('Current Android Update Config in Firestore:');
      console.log(JSON.stringify(doc.data(), null, 2));
    }
    return;
  }

  if (args[0] === 'set') {
    // Usage: node update-app-config.js set <version> <versionCode> <minVersionCode> <forceUpdate(true/false)> <apkUrl> <releaseNotes>
    const version = args[1] || '1.0.0';
    const versionCode = parseInt(args[2] || '1', 10);
    const minVersionCode = parseInt(args[3] || '1', 10);
    const forceUpdate = (args[4] || 'false').toLowerCase() === 'true';
    const apkUrl = args[5] || '';
    const releaseNotes = args.slice(6).join(' ') || '• Performance improvements and bug fixes.';

    const payload = {
      latestVersion: version,
      latestVersionCode: versionCode,
      minimumVersionCode: minVersionCode,
      forceUpdate: forceUpdate,
      apkUrl: apkUrl,
      releaseNotes: releaseNotes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await docRef.set(payload, { merge: true });
    console.log('Successfully updated android_update config in Firestore:');
    console.log(JSON.stringify(payload, null, 2));
  }
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
