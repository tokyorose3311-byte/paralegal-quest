/**
 * bulk_upload_questions.js
 *
 * One-time script to bulk-upload a practice-area question bank into your
 * Firestore "questions" collection for Paralegal Quest.
 *
 * WHAT THIS DOES:
 *   - Reads a question-bank JSON file (see family_law_questions.json format)
 *   - Flattens it into individual question documents
 *   - Shuffles each question's answer choices into a random order (see
 *     "ANSWER SHUFFLING" below) so the correct answer isn't predictably
 *     sitting in the same slot across the question bank
 *   - Tags every document with a `practiceArea` field
 *   - Writes them into Firestore in batches (safe, fast, avoids quota issues)
 *
 * ANSWER SHUFFLING (automatic, every run):
 *   Every question's `choices` array is shuffled before upload, and
 *   `correctAnswer` is remapped to match wherever the right answer landed.
 *   The shuffle is *seeded from the question's own id* (a simple string
 *   hash), not from Math.random(), so:
 *     - Re-running this script on the same file always produces the same
 *       shuffle -> upload stays idempotent/stable (safe to re-run).
 *     - Different questions get independent, unpredictable orderings ->
 *       no learnable "correct answer is always position 2" pattern.
 *   You do NOT need to pre-shuffle your source JSON files by hand anymore
 *   -- just write questions with the correct answer in whatever position
 *   is natural, and this script randomizes it on upload.
 *
 * FIRESTORE FIELD NAMES (must match lib/models/question.dart exactly):
 *   options (list of answer strings) -- the source JSON's "choices" field
 *     is renamed to "options" on upload
 *   correctIndex (0-based index) -- the source JSON's "correctAnswer" field
 *     is renamed to "correctIndex" on upload (after shuffling, see above)
 *   category (string, defaults to the stage name) and type ("mountain" or
 *     "cave", defaults to "mountain") -- required by the in-game question
 *     dialog UI. If these don't match, the app's QuizQuestion.fromDoc()
 *     silently falls back to an empty options list, which freezes the
 *     question dialog (no tappable answers) instead of throwing an error.
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

// ---- Deterministic seeded shuffle helpers ----

// Simple, fast string hash (djb2 variant) -> 32-bit unsigned int.
// Used only to seed the shuffle RNG per-question, so the same question id
// always shuffles the same way (idempotent re-runs) while different ids
// get independent, unpredictable orderings.
function hashStringToSeed(str) {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash + str.charCodeAt(i)) >>> 0;
  }
  return hash;
}

// Mulberry32 seeded PRNG -- tiny, deterministic, good enough for a shuffle.
function mulberry32(seed) {
  let a = seed;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Fisher-Yates shuffle of `choices`, tracking where `correctAnswer` lands.
// Returns { choices: shuffledChoices, correctAnswer: newIndex }.
function shuffleChoices(choices, correctAnswer, seedStr) {
  const rng = mulberry32(hashStringToSeed(seedStr));
  const indices = choices.map((_, i) => i);

  for (let i = indices.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [indices[i], indices[j]] = [indices[j], indices[i]];
  }

  const shuffledChoices = indices.map((i) => choices[i]);
  const newCorrectAnswer = indices.indexOf(correctAnswer);
  return { choices: shuffledChoices, correctAnswer: newCorrectAnswer };
}

// ---- Load, flatten, and shuffle the question bank ----
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
      // Shuffle answer order (seeded by question id -> stable on re-run).
      const shuffled = shuffleChoices(q.choices, q.correctAnswer, q.id);

      flatQuestions.push({
        // Use the id from the JSON as the Firestore document ID too,
        // so re-running this script updates rather than duplicates.
        id: q.id,
        practiceArea: practiceArea,
        stage: stage,
        // NOTE: field names below MUST match what QuizQuestion.fromDoc()
        // in lib/models/question.dart reads from Firestore:
        //   options (not "choices"), correctIndex (not "correctAnswer"),
        //   plus category + type which the app's question dialog UI
        //   requires (category label + mountain/cave badge). Getting
        //   these names wrong silently produces an empty answer list in
        //   the app (frozen question dialog) since QuizQuestion.fromDoc
        //   defaults missing fields instead of throwing.
        question: q.question,
        options: shuffled.choices,
        correctIndex: shuffled.correctAnswer,
        explanation: q.explanation,
        category: q.category || stage,
        type: q.type || "mountain",
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
    console.log("Answer choices shuffled (seeded per-question id -- stable on re-run).");

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
