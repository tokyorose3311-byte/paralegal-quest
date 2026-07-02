// Shared Firebase Admin initialization for Netlify Functions.
// Expects the FIREBASE_SERVICE_ACCOUNT_JSON environment variable to contain
// the full Firebase service account JSON (as a single-line string).
const admin = require('firebase-admin');

let app;

function getDb() {
  if (!app) {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!raw) {
      throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_JSON env var');
    }
    const serviceAccount = JSON.parse(raw);
    app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  return admin.firestore();
}

module.exports = { getDb, admin };
