// POST (Authorization: Bearer <supabase access token>) -> Razorpay order banata hai (Rs 99 subscription)
const { E, out, sbFetch, userFromToken } = require('../lib/pay');
const PRICE_PAISE = 9900; // Rs 99 (price server par fixed hai)

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  const { RAZORPAY_KEY_ID: kid, RAZORPAY_KEY_SECRET: ks, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = E;
  if (!kid || !ks || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return out(500, { error: 'Server configure nahi hai.' });

  const token = (event.headers.authorization || '').replace(/^Bearer /i, '');
  const u = token ? await userFromToken(token) : null;
  if (!u || !u.id) return out(401, { error: 'Login zaroori hai.' });

  try {
    const prof = await sbFetch('/rest/v1/profiles?id=eq.' + encodeURIComponent(u.id) + '&select=role');
    if (!prof || !prof[0] || !['Customer', 'Owner'].includes(prof[0].role))
      return out(403, { error: 'Subscription sirf Customer ya Owner ke liye hai.' });

    const rr = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Basic ' + Buffer.from(kid + ':' + ks).toString('base64') },
      body: JSON.stringify({ amount: PRICE_PAISE, currency: 'INR', receipt: 'sub_' + Date.now(), notes: { user_id: u.id, purpose: 'subscription' } }),
    });
    const o = await rr.json();
    if (!rr.ok || !o.id) return out(502, { error: 'Razorpay order nahi ban paya.' });

    await sbFetch('/rest/v1/payments', {
      method: 'POST', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ user_id: u.id, purpose: 'subscription', amount: PRICE_PAISE, order_id: o.id }),
    });
    return out(200, { order_id: o.id, amount: PRICE_PAISE, key_id: kid });
  } catch (e) {
    return out(500, { error: 'Server error. Thodi der baad try karein.' });
  }
};
