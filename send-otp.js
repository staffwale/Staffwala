// POST { mobile } -> SMS par OTP bhejta hai, { token } return karta hai (OTP kabhi return nahi hota).
const crypto = require('crypto');
const H = { 'Content-Type': 'application/json' };
const out = (c, b) => ({ statusCode: c, headers: H, body: JSON.stringify(b) });

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  let mobile;
  try { mobile = String(JSON.parse(event.body || '{}').mobile || ''); }
  catch (e) { return out(400, { error: 'Bad request' }); }
  if (!/^[6-9]\d{9}$/.test(mobile)) return out(400, { error: 'Sahi 10 digit mobile number daalein.' });

  const { MSG91_AUTHKEY, MSG91_TEMPLATE_ID, OTP_SECRET } = process.env;
  if (!MSG91_AUTHKEY || !MSG91_TEMPLATE_ID || !OTP_SECRET)
    return out(500, { error: 'SMS service configure nahi hai.' });

  const otp = String(crypto.randomInt(100000, 1000000));
  const exp = Date.now() + 5 * 60 * 1000; // 5 minute
  const sig = crypto.createHmac('sha256', OTP_SECRET).update(`${mobile}.${otp}.${exp}`).digest('hex');

  const url = 'https://control.msg91.com/api/v5/otp'
    + `?template_id=${encodeURIComponent(MSG91_TEMPLATE_ID)}`
    + `&mobile=91${mobile}&authkey=${encodeURIComponent(MSG91_AUTHKEY)}&otp=${otp}`;
  try {
    const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    const d = await r.json().catch(() => ({}));
    if (!r.ok || d.type === 'error') return out(502, { error: 'SMS nahi bheja ja saka.' });
  } catch (e) {
    return out(502, { error: 'SMS service se connect nahi ho paya.' });
  }
  return out(200, { token: `${exp}.${sig}` });
};
