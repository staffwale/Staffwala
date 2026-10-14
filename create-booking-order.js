// POST { job_id } (Authorization: Bearer <token>) -> booking ke liye Razorpay order. Amount database se aata hai, client se nahi.
const { E, out, sbFetch, userFromToken } = require('../lib/pay');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  const { RAZORPAY_KEY_ID: kid, RAZORPAY_KEY_SECRET: ks, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = E;
  if (!kid || !ks || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return out(500, { error: 'Server configure nahi hai.' });
  const token = (event.headers.authorization || '').replace(/^Bearer /i, '');
  const u = token ? await userFromToken(token) : null;
  if (!u || !u.id) return out(401, { error: 'Login zaroori hai.' });
  let b; try { b = JSON.parse(event.body || '{}'); } catch (e) { return out(400, { error: 'Bad request' }); }
  const jid = String(b.job_id || '');
  if (!/^[0-9a-f-]{36}$/i.test(jid)) return out(400, { error: 'Bad request' });
  try {
    const rows = await sbFetch('/rest/v1/jobs?id=eq.' + jid + '&select=owner_id,status,pay_status,customer_pays,kind');
    const j = rows && rows[0];
    if (!j || j.owner_id !== u.id || j.kind !== 'home' || j.status !== 'Open' || j.pay_status !== 'unpaid')
      return out(400, { error: 'Is booking ka payment nahi ho sakta.' });
    const amount = j.customer_pays * 100;
    const rr = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Basic ' + Buffer.from(kid + ':' + ks).toString('base64') },
      body: JSON.stringify({ amount, currency: 'INR', receipt: 'job_' + jid.slice(0, 8) + '_' + Date.now(), notes: { user_id: u.id, job_id: jid, purpose: 'booking' } }),
    });
    const o = await rr.json();
    if (!rr.ok || !o.id) return out(502, { error: 'Razorpay order nahi ban paya.' });
    await sbFetch('/rest/v1/payments', {
      method: 'POST', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ user_id: u.id, purpose: 'booking', amount, order_id: o.id, job_id: jid }),
    });
    return out(200, { order_id: o.id, amount, key_id: kid });
  } catch (e) { return out(500, { error: 'Server error. Thodi der baad try karein.' }); }
};
