# Bulk Upload Questions to Firestore — Step by Step

This uploads a full question bank (like Family Law) into your Firestore
`questions` collection in one shot, tagged with the correct `practiceArea`,
instead of typing all 60 questions into the Admin panel by hand.

## One-time setup (do this once)

1. **Install Node.js** if you don't already have it: go to nodejs.org,
   download the "LTS" version, and install it like any other program.

2. **Get your Firebase service account key:**
   - Go to console.firebase.google.com and open your Paralegal Quest project
   - Click the gear icon (top left, next to "Project Overview") -> **Project settings**
   - Click the **Service accounts** tab
   - Click **Generate new private key** -> a JSON file will download
   - Rename that downloaded file to exactly: `serviceAccountKey.json`
   - Move it into this same folder (next to `bulk_upload_questions.js`)

   ⚠️ **This file gives full admin access to your Firebase project.**
   - Never upload it to GitHub
   - Never share it or paste its contents anywhere
   - This folder already includes a `.gitignore` so it won't accidentally
     get committed if you keep this folder inside your repo

3. **Open a terminal in this folder** and run:
   ```
   npm install
   ```
   This downloads the one library the script needs (`firebase-admin`).
   You only have to do this once.

## Every time you want to upload a question bank

Run this command (replace the filename and practice area as needed):

```
node bulk_upload_questions.js family_law_questions.json family_law
```

- First argument: the path to your question bank JSON file
- Second argument: the `practiceArea` value to tag every question with
  (use short, consistent, lowercase-with-underscores names, e.g.
  `civil_litigation`, `family_law`, `estate_law`, `criminal_law`, `consumer_law`)

You'll see progress printed in the terminal, ending with something like:
```
Done! 60 questions uploaded/updated under practiceArea="family_law".
```

## Re-running is safe

Each question's `id` (e.g. `fl_intake_01`) is used as its Firestore document
ID. Running the script again with the same file will **update** those same
documents rather than creating duplicates — so if you fix a typo in a
question and re-run it, it just overwrites the old version.

## Your existing Civil Litigation questions

Your original 20 questions don't have a `practiceArea` field yet, since
they were created before this system existed. You have two options:

- **Add the field once, manually, in the Admin panel** — edit each of
  the 20 existing questions and set `practiceArea` to `civil_litigation`
- **Or** build a small JSON file for them in this same format (stage +
  question + choices + correctAnswer + explanation) and run this same
  script with `civil_litigation` as the practice area — this will
  overwrite/update those 20 by their existing IDs (only works cleanly if
  their current Firestore document IDs match what you put in the JSON)

If you're not sure which existing IDs your 20 Civil Litigation questions
have in Firestore, the safest route is the manual Admin panel edit for
those 20 — then use this script going forward for every new practice area.
