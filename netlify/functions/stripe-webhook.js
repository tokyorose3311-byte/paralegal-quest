// Stripe webhook handler — listens for `checkout.session.completed` and
// automatically generates a Firestore license code for the purchase.
//
// Required Netlify environment variables:
//   STRIPE_SECRET_KEY           sk_live_... or sk_test_...
//   STRIPE_WEBHOOK_SECRET       whsec_... (from the Stripe webhook endpoint)
//   FIREBASE_SERVICE_ACCOUNT_JSON   full service-account JSON, one line
//
// Configure in Stripe Dashboard -> Developers -> Webhooks -> Add endpoint:
//   URL:    https://YOUR-SITE.netlify.app/.netlify/functions/stripe-webhook
//   Events: checkout.session.completed

const Stripe = require('stripe');
const { getDb, admin } = require('./_firebase');

const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I/L ambiguity

function randomSuffix(len = 6) {
  let out = '';
  for (let i = 0; i < len; i++) {
    out += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
  }
  return out;
}

/** Decide plan type + code prefix from the Checkout Session. */
function planFromSession(session) {
  if (session.mode === 'subscription') {
    return { type: 'season', prefix: 'SEASON' };
  }
  // One-time payments: School License ($2,500) vs Classroom License ($850)
  const amount = session.amount_total || 0;
  if (amount >= 200000) {
    return { type: 'school', prefix: 'SCHOOL' };
  }
  return { type: 'classroom', prefix: 'CLASS' };
}

async function generateUniqueCode(db, prefix) {
  const year = new Date().getFullYear();
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = `${prefix}-${year}-${randomSuffix()}`;
    const doc = await db.collection('license_codes').doc(code).get();
    if (!doc.exists) return code;
  }
  throw new Error('Could not generate a unique license code after 8 attempts');
}

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const sig = event.headers['stripe-signature'] || event.headers['Stripe-Signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let stripeEvent;
  try {
    stripeEvent = stripe.webhooks.constructEvent(event.body, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return { statusCode: 400, body: `Webhook Error: ${err.message}` };
  }

  if (stripeEvent.type !== 'checkout.session.completed') {
    return { statusCode: 200, body: 'ignored (not checkout.session.completed)' };
  }

  const session = stripeEvent.data.object;
  const db = getDb();

  try {
    // Idempotency: Stripe may retry the same webhook event more than once.
    const existing = await db
      .collection('license_codes')
      .where('stripe_session_id', '==', session.id)
      .limit(1)
      .get();
    if (!existing.empty) {
      const code = existing.docs[0].id;
      console.log(`Session ${session.id} already processed -> ${code}`);
      return { statusCode: 200, body: JSON.stringify({ received: true, code }) };
    }

    const { type, prefix } = planFromSession(session);
    const code = await generateUniqueCode(db, prefix);

    await db
      .collection('license_codes')
      .doc(code)
      .set({
        school: '',
        type,
        used: false,
        customer_email:
          session.customer_details?.email || session.customer_email || null,
        stripe_session_id: session.id,
        stripe_customer_id: session.customer || null,
        amount_total: session.amount_total ?? null,
        currency: session.currency ?? null,
        source: 'stripe',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`Generated license code ${code} (${type}) for session ${session.id}`);
    return { statusCode: 200, body: JSON.stringify({ received: true, code }) };
  } catch (err) {
    console.error('Error handling checkout.session.completed:', err);
    // Return 500 so Stripe retries the webhook automatically.
    return { statusCode: 500, body: 'Internal error generating license code' };
  }
};
