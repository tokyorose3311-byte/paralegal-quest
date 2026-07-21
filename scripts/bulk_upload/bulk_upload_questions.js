/**
 * bulk_upload_questions.js
 *
 * One-time script to bulk-upload a practice-area question bank into your
 * Firestore "questions" collection for Paralegal Quest.
 *
 * WHAT THIS DOES:
 *   - Reads a question-bank JSON file (see family_law_questions.json format)
 *   - Flattens it into individual question documents
 *   - Tags every document with a `practiceArea` field
 *   - Writes them into Firestore in batches (safe, fast, avoids quota issues)
 *
 * REQUIREMENTS BEFORE RUNNING:
 *   1. Node.js installed on your computer (nodejs.org)
 *   2. A Firebase service account key (see "GETTING YOUR SERVICE ACCOUNT KEY" below)
 *   3. `npm install firebase-admin` run once in this folder
 *
 * USAGE:
 *   node bulk_upload_questions.js family_law_questions.json family_law
 *
 *   (first argument = path to your question bank JSON file)
 *   (second argument = the practiceArea value to tag every question with)
 *
 * ============================================================
 * GETTING YOUR SERVICE ACCOUNT KEY (one-time setup):
 *   1. Go to console.firebase.google.com and open your Paralegal Quest project
 *   2. Click the gear icon (top left) -> Project settings
 *   3. Go to the "Service accounts" tab
 *   4. Click "Generate new private key" -> confirms a JSON file downloads
 *   5. Rename that file to serviceAccountKey.json and place it in this
 *      same folder as this script
 *
 *   IMPORTANT: This file grants full admin access to your Firebase project.
 *   - NEVER commit it to GitHub (add it to .gitignore)
 *   - NEVER share it or paste its contents anywhere
 *   - Delete it from your computer once you're done running this script,
 *     or keep it somewhere private and offline
 * ============================================================
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// ---- Parse command-line arguments ----
const jsonFilePath = process.argv[2];
const practiceAreaArg = process.argv[3];

if (!jsonFilePath || !practiceAreaArg) {
  console.error(
    "\nUsage: node bulk_upload_questions.js <path-to-json-file> <practiceArea>\n" +
    "Example: node bulk_upload_questions.js family_law_questions.json family_law\n"
  );
  process.exit(1);
}

const serviceAccountPath = path.join(__dirname, "serviceAccountKey.json");
if (!fs.existsSync(serviceAccountPath)) {
  console.error(
    "\nERROR: serviceAccountKey.json not found in this folder.\n" +
    "See the instructions at the top of this script for how to get one.\n"
  );
  process.exit(1);
}

// ---- Initialize Firebase Admin ----
const serviceAccount = require(serviceAccountPath);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ---- Load and flatten the question bank ----
function loadQuestions(filePath, practiceArea) {
  const raw = fs.readFileSync(filePath, "utf8");
  const data = JSON.parse(raw);

  if (!data.stages || !Array.isArray(data.stages)) {
    throw new Error(
      "Expected the JSON file to have a top-level 'stages' array. " +
      "Check the file format matches family_law_questions.json."
    );
  }

  const flatQuestions = [];
  for (const stageBlock of data.stages) {
    const stage = stageBlock.stage;
    for (const q of stageBlock.questions) {
      flatQuestions.push({
        // Use the id from the JSON as the Firestore document ID too,
        // so re-running this script updates rather than duplicates.
        id: q.id,
        practiceArea: practiceArea,
        stage: stage,
        question: q.question,
        choices: q.choices,
        correctAnswer: q.correctAnswer,
        explanation: q.explanation,
      });
    }
  }
  return flatQuestions;
}

// ---- Upload in batches (Firestore max batch size is 500) ----
async function uploadInBatches(questions) {
  const BATCH_SIZE = 400; // safely under the 500 limit
  const collectionRef = db.collection("questions");

  let uploaded = 0;
  for (let i = 0; i < questions.length; i += BATCH_SIZE) {
    const chunk = questions.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const q of chunk) {
      // Use the question's own id as the doc ID -> re-running this
      // script is safe and will just overwrite the same docs (upsert),
      // rather than creating duplicates every time you run it.
      const docRef = collectionRef.doc(q.id);
      batch.set(docRef, q, { merge: true });
    }

    await batch.commit();
    uploaded += chunk.length;
    console.log(`  Uploaded ${uploaded} / ${questions.length}...`);
  }
}

// ---- Main ----
(async () => {
  try {
    console.log(`\nReading questions from: ${jsonFilePath}`);
    const questions = loadQuestions(jsonFilePath, practiceAreaArg);
    console.log(`Found ${questions.length} questions tagged as practiceArea="${practiceAreaArg}".`);

    console.log("\nUploading to Firestore 'questions' collection...");
    await uploadInBatches(questions);

    console.log(
      `\nDone! ${questions.length} questions uploaded/updated under practiceArea="${practiceAreaArg}".\n`
    );
    process.exit(0);
  } catch (err) {
    console.error("\nUpload failed:", err.message);
    process.exit(1);
  }
})();
