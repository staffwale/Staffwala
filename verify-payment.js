// POST { razorpay_order_id, razorpay_payment_id, razorpay_signature } -> signature verify karke subscription activate
const { E, out, hmac, safeEq, applyPayment } = require('../lib/pay');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  let b;
  try { b = JSON.parse(event.body || '{}'); } catch (e) { return out(400, { error: 'Bad request' }); }
  const o = b.razorpay_order_id, p = b.razorpay_payment_id, s = b.razorpay_signature;
  if (!o || !p || !s || !E.RAZORPAY_KEY_SECRET) return out(400, { error: 'Bad request' });
  if (!safeEq(hmac(E.RAZORPAY_KEY_SECRET, o + '|' + p), s)) return out(400, { error: 'Payment verify nahi hui.' });
  try { await applyPayment(o, p); return out(200, { ok: true }); }
  catch (e) { return out(500, { error: 'Payment mili, par activate nahi ho paya. Support se sampark karein.' }); }
};
