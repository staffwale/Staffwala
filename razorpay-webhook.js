// Backup: user payment ke baad tab band kar de to bhi subscription activate ho. Razorpay Dashboard > Webhooks mein is URL ko daalein.
const { E, out, hmac, safeEq, applyPayment } = require('../lib/pay');

exports.handler = async (event) => {
  const sig = event.headers['x-razorpay-signature'];
  const raw = event.isBase64Encoded ? Buffer.from(event.body || '', 'base64').toString('utf8') : (event.body || '');
  if (!E.RAZORPAY_WEBHOOK_SECRET || !sig || !safeEq(hmac(E.RAZORPAY_WEBHOOK_SECRET, raw), sig)) return out(400, { error: 'bad signature' });
  let ev;
  try { ev = JSON.parse(raw); } catch (e) { return out(400, { error: 'bad body' }); }
  const p = ev.payload && ev.payload.payment && ev.payload.payment.entity;
  if ((ev.event === 'payment.captured' || ev.event === 'order.paid') && p && p.order_id) {
    try { await applyPayment(p.order_id, p.id); } catch (e) { return out(500, { error: 'retry' }); }
  }
  return out(200, { ok: true });
};
