// Shared helpers for Razorpay functions. Secrets sirf Netlify environment variables mein rehte hain.
const crypto = require('crypto');
const E = process.env;
const out = (c, b) => ({ statusCode: c, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) });

async function sbFetch(path, opt = {}) {
  const key = E.SUPABASE_SERVICE_ROLE_KEY;
  const r = await fetch(E.SUPABASE_URL + path, {
    ...opt,
    headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', ...(opt.headers || {}) },
  });
  const t = await r.text();
  if (!r.ok) throw new Error('Supabase ' + r.status + ': ' + t.slice(0, 200));
  try { return t ? JSON.parse(t) : null; } catch (e) { return t; }
}
async function userFromToken(token) {
  const r = await fetch(E.SUPABASE_URL + '/auth/v1/user', {
    headers: { apikey: E.SUPABASE_SERVICE_ROLE_KEY, Authorization: 'Bearer ' + token },
  });
  return r.ok ? r.json() : null;
}
const hmac = (secret, data) => crypto.createHmac('sha256', secret).update(data).digest('hex');
function safeEq(a, b) {
  const A = Buffer.from(String(a)), B = Buffer.from(String(b));
  return A.length === B.length && crypto.timingSafeEqual(A, B);
}
// Order paid mark + subscription grant, ek hi database transaction mein (dobara chalane par double nahi hota)
const applyPayment = (order, payment) =>
  sbFetch('/rest/v1/rpc/apply_payment', { method: 'POST', body: JSON.stringify({ p_order: order, p_payment: payment }) });

// Razorpay se refund (customer ne jitna diya utna). Fail ho to 'pending' (admin panel se dobara try hota hai).
async function refundJob(jobId) {
  const rows = await sbFetch('/rest/v1/jobs?id=eq.' + encodeURIComponent(jobId) + '&select=pay_status,payment_id,customer_pays');
  const j = rows && rows[0];
  if (!j || j.pay_status !== 'refund_due' || !j.payment_id) return 'none';
  try {
    const r = await fetch('https://api.razorpay.com/v1/payments/' + encodeURIComponent(j.payment_id) + '/refund', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Basic ' + Buffer.from(E.RAZORPAY_KEY_ID + ':' + E.RAZORPAY_KEY_SECRET).toString('base64') },
      body: JSON.stringify({ amount: j.customer_pays * 100, speed: 'normal', notes: { job_id: jobId } }),
    });
    const d = await r.json();
    if (!r.ok || !d.id) return 'pending';
    await sbFetch('/rest/v1/rpc/mark_refunded', { method: 'POST', body: JSON.stringify({ p_job: jobId, p_refund: d.id }) });
    return 'done';
  } catch (e) { return 'pending'; }
}
const dbMsg = (e, d) => { const m = /"message":"([^"]+)"/.exec(String(e && e.message)); return m ? m[1] : d; };

module.exports = { E, out, sbFetch, userFromToken, hmac, safeEq, applyPayment, refundJob, dbMsg };
