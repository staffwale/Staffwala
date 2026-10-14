// POST { mobile, otp, token } -> { ok: true } agar OTP sahi aur 5 minute ke andar hai.
const crypto = require('crypto');
const H = { 'Content-Type': 'application/json' };
const out = (c, b) => ({ statusCode: c, headers: H, body: JSON.stringify(b) });

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  let b;
  try { b = JSON.parse(event.body || '{}'); } catch (e) { return out(400, { error: 'Bad request' }); }
  const mobile = String(b.mobile || ''), otp = String(b.otp || '');
  const [exp, sig] = String(b.token || '').split('.');
  const secret = process.env.OTP_SECRET;
  if (!secret) return out(500, { error: 'Server configure nahi hai.' });
  if (!/^[6-9]\d{9}$/.test(mobile) || !/^\d{6}$/.test(otp) || !exp || !sig) return out(400, { ok: false, error: 'Bad request' });
  if (Date.now() > Number(exp)) return out(400, { ok: false, error: 'OTP expire ho gaya.' });
  const calc = crypto.createHmac('sha256', secret).update(`${mobile}.${otp}.${exp}`).digest('hex');
  const A = Buffer.from(calc), B = Buffer.from(sig);
  const ok = A.length === B.length && crypto.timingSafeEqual(A, B);
  return ok ? out(200, { ok: true }) : out(400, { ok: false, error: 'OTP galat hai.' });
};
