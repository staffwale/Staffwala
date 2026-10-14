// POST { job_id } -> admin panel se pending refund dobara bhejna
const { E, out, sbFetch, userFromToken, refundJob } = require('../lib/pay');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return out(405, { error: 'POST only' });
  const token = (event.headers.authorization || '').replace(/^Bearer /i, '');
  const u = token ? await userFromToken(token) : null;
  if (!u || !u.id) return out(401, { error: 'Login zaroori hai.' });
  let b; try { b = JSON.parse(event.body || '{}'); } catch (e) { return out(400, { error: 'Bad request' }); }
  const jid = String(b.job_id || '');
  if (!/^[0-9a-f-]{36}$/i.test(jid)) return out(400, { error: 'Bad request' });
  try {
    const p = await sbFetch('/rest/v1/profiles?id=eq.' + encodeURIComponent(u.id) + '&select=is_admin');
    if (!p || !p[0] || !p[0].is_admin) return out(403, { error: 'Sirf admin ke liye.' });
    const status = await refundJob(jid);
    await sbFetch('/rest/v1/admin_log', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ admin_id: u.id, action: 'refund', detail: jid + ' ' + status }) });
    return out(200, { status });
  } catch (e) { return out(500, { error: 'Server error.' }); }
};
