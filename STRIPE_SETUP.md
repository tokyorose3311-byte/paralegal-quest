# Automatic License Code Generation — Setup Guide

This connects your existing Stripe Payment Links to Firestore so that a
license code is generated **automatically** the moment someone pays —
no more manually typing codes into the admin panel.

## How it works

1. Customer clicks "Subscribe" / "Get License" on the app → goes to your
   Stripe Payment Link → pays.
2. Stripe redirects them to `https://YOUR-SITE.netlify.app/success.html`.
3. In the background, Stripe also sends a `checkout.session.completed`
   webhook event to a Netlify Function
   (`/.netlify/functions/stripe-webhook`).
4. That function generates a unique code (e.g. `CLASS-2026-7QX4M9`) and
   writes it straight into the same Firestore `license_codes` collection
   the app already reads from — so it works instantly, on any device,
   with zero app update needed.
5. `success.html` polls a second function
   (`/.netlify/functions/get-license`) and shows the customer their new
   code with a "Copy code" button.

Code prefixes are chosen automatically:
- `SEASON-2026-XXXXXX` — Season Pass (subscription)
- `SCHOOL-2026-XXXXXX` — School License ($2,500 one-time)
- `CLASS-2026-XXXXXX`  — Classroom License ($850 one-time)

## One-time setup (you'll need to do this — I don't have access to your
## Stripe or Netlify accounts)

### 1. Get your Stripe Secret Key
Stripe Dashboard → **Developers** → **API keys** → copy the
**Secret key** (`sk_live_...` for real payments, or `sk_test_...` while
testing).

### 2. Add a Stripe webhook endpoint
Stripe Dashboard → **Developers** → **Webhooks** → **Add endpoint**
- Endpoint URL: `https://YOUR-SITE.netlify.app/.netlify/functions/stripe-webhook`
  (replace `YOUR-SITE` with your actual Netlify site name/domain)
- Events to send: select **`checkout.session.completed`**
- Click **Add endpoint**, then copy the **Signing secret** (`whsec_...`)
  shown on that endpoint's page.

### 3. Set the redirect URL on each Payment Link
For **each** of your 3 Stripe Payment Links (Season Pass, School
License, Classroom License):
Stripe Dashboard → **Payment Links** → open the link → **Edit** →
**After payment** → choose **"Redirect to a website"** and set the URL to:
```
https://YOUR-SITE.netlify.app/success.html?session_id={CHECKOUT_SESSION_ID}
```
(Stripe automatically fills in `{CHECKOUT_SESSION_ID}` — type it exactly
like that, including the curly braces.)

### 4. Add environment variables in Netlify
Netlify Dashboard → your site → **Site configuration** →
**Environment variables** → add:

| Key | Value |
|---|---|
| `STRIPE_SECRET_KEY` | the secret key from step 1 |
| `STRIPE_WEBHOOK_SECRET` | the signing secret from step 2 |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | see below |

For `FIREBASE_SERVICE_ACCOUNT_JSON`, you need the **entire contents** of
your Firebase service account JSON file, minified to one line. If you
still have the JSON file you downloaded from Firebase Console →
Project Settings → Service Accounts → Generate new private key, you can
minify it with this command (run in any terminal with Python installed):
```bash
python3 -c "import json; print(json.dumps(json.load(open('serviceAccountKey.json'))))"
```
Paste the single-line output as the value of `FIREBASE_SERVICE_ACCOUNT_JSON`.

### 5. Redeploy
After adding the environment variables, trigger a new deploy in Netlify
(Deploys → Trigger deploy → Deploy site) so the functions pick up the
new variables.

## Testing it

1. Use a Stripe **test mode** secret key + test webhook first, and pay
   with Stripe's test card `4242 4242 4242 4242` (any future expiry,
   any CVC).
2. After paying, you should land on `success.html` and see a generated
   code within a couple seconds.
3. Check Firebase Console → Firestore → `license_codes` collection —
   a new document should appear with `source: "stripe"`.
4. Check the admin panel in the app — the new code should appear in the
   "LICENSE CODES" list automatically.
5. Once confirmed working, switch to your **live** secret key + live
   webhook endpoint for real payments.

## Troubleshooting

- **No code appears on success.html**: Check Netlify → Functions →
  `stripe-webhook` → logs, and Stripe Dashboard → Webhooks → your
  endpoint → recent deliveries, for error details.
- **"Webhook Error: No signatures found matching..."**: The
  `STRIPE_WEBHOOK_SECRET` env var doesn't match the endpoint's actual
  signing secret — re-copy it from Stripe.
- **Firebase permission errors**: Double check
  `FIREBASE_SERVICE_ACCOUNT_JSON` was pasted correctly as valid,
  single-line JSON (no line breaks).
