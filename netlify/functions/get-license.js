// Looks up the license code generated for a completed Stripe Checkout
// session. Used by success.html to display the code right after payment.
//
// GET /.netlify/functions/get-license?session_id=cs_test_...
//
// Returns 202 (not ready yet) if the webhook hasn't processed the session
// yet -- the success page polls this a few times before giving up.

const { getDb } = require('./_firebase');

exports.handler = async (event) => {
  const sessionId = event.queryStringParameters?.session_id;
  if (!sessionId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing session_id' }) };
  }

  try {
    const db = getDb();
    const snap = await db
      .collection('license_codes')
      .where('stripe_session_id', '==', sessionId)
      .limit(1)
      .get();

    if (snap.empty) {
      return {
        statusCode: 202,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ready: false }),
      };
    }

    const doc = snap.docs[0];
    const data = doc.data();
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ready: true,
        code: doc.id,
        type: data.type,
        email: data.customer_email || null,
      }),
    };
  } catch (err) {
    console.error('get-license error:', err);
    return { statusCode: 500, body: JSON.stringify({ error: 'Internal error' }) };
  }
};
