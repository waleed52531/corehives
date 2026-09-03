const admin = require('firebase-admin');
admin.initializeApp({
  projectId: 'crud-a8dfc'
});
const db = admin.firestore();
db.listCollections().then(collections => {
  console.log('Collections:', collections.map(c => c.id));
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
