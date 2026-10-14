// POST (Authorization: Bearer <admin token>) -> go-live check: keys test/live, Razorpay keys kaam karte hain ya nahi, webhook secret.
// Koi secret wapas nahi bhejta, sirf haan/na.
const { E, out, sbFetch, userFromToken } = require('../lib/pay');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  if (!E.SUPABASE_URL || !E.SUPABASE_SERVICE_ROLE_KEY) return out(500, { error: 'Server configure nahi hai.' });
  const token = ((event.headers && event.headers.authorization) || '').replace(/^Bearer /i, '');
  const u = token ? await userFromToken(token) : null;
  if (!u || !u.id) return out(401, { error: 'Login zaroori hai.' });
  try {
    const a = await sbFetch('/rest/v1/profiles?id=eq.' + encodeURIComponent(u.id) + '&select=is_admin');
    if (!(a && a[0] && a[0].is_admin)) return out(403, { error: 'Sirf admin ke liye.' });
  } catch (e) { return out(500, { error: 'Server error.' }); }

  const kid = E.RAZORPAY_KEY_ID || '';
  const mode = kid.startsWith('rzp_live_') ? 'live' : kid.startsWith('rzp_test_') ? 'test' : 'missing';
  let keys = 'missing';
  if (kid && E.RAZORPAY_KEY_SECRET) {
    try {
      const r = await fetch('https://api.razorpay.com/v1/orders?count=1', {
        headers: { Authorization: 'Basic ' + Buffer.from(kid + ':' + E.RAZORPAY_KEY_SECRET).toString('base64') } });
      keys = r.ok ? 'ok' : 'rejected';
    } catch (e) { keys = 'unreachable'; }
  }
  return out(200, { mode, keys, webhook_secret: !!E.RAZORPAY_WEBHOOK_SECRET });
};
