// POST { job_id } -> booking cancel + (agar paid thi) automatic Razorpay refund
const { E, out, sbFetch, userFromToken, refundJob, dbMsg } = require('../lib/pay');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  if (!E.SUPABASE_URL || !E.SUPABASE_SERVICE_ROLE_KEY) return out(500, { error: 'Server configure nahi hai.' });
  const token = (event.headers.authorization || '').replace(/^Bearer /i, '');
  const u = token ? await userFromToken(token) : null;
  if (!u || !u.id) return out(401, { error: 'Login zaroori hai.' });
  let b; try { b = JSON.parse(event.body || '{}'); } catch (e) { return out(400, { error: 'Bad request' }); }
  const jid = String(b.job_id || '');
  if (!/^[0-9a-f-]{36}$/i.test(jid)) return out(400, { error: 'Bad request' });
  try {
    const r = await sbFetch('/rest/v1/rpc/cancel_booking_server', { method: 'POST', body: JSON.stringify({ p_job: jid, p_uid: u.id }) });
    const refund = r && r.pay_status === 'refund_due' ? await refundJob(jid) : 'none';
    return out(200, { ok: true, refund });
  } catch (e) { return out(400, { error: dbMsg(e, 'Cancel nahi ho saka.') }); }
};
