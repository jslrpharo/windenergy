/**
 * Cloudflare Worker – ACM SL Contact Form Mailer
 *
 * DESPLIEGUE (una sola vez, cuenta gratuita):
 * ─────────────────────────────────────────────
 * 1. Ir a https://workers.cloudflare.com  → Sign up (gratis)
 * 2. Dashboard → Workers & Pages → Create application → Create Worker
 * 3. Pegar todo este archivo en el editor online y pulsar "Deploy"
 * 4. En Settings → Variables and Secrets crear estos secrets:
 *      SMTP2GO_API_KEY   = tu API key de SMTP2GO
 *      HCAPTCHA_SECRET   = tu secret de hCaptcha (opcional pero recomendado)
 * 5. Copiar la URL que aparece (ej. https://acmsl-mailer.TU_USUARIO.workers.dev)
 * 6. Pegar esa URL en formulario.html → constante WORKER_URL
 *
 * Plan gratuito: 100.000 peticiones/día, más que suficiente.
 */

const RECIPIENT       = 'support@acm-sl.com';
const SENDER          = 'Formulario ACM SL <support@acm-sl.com>';
const ALLOWED_ORIGINS = new Set([
  'https://www.acm-sl.com',
  'https://acm-sl.com',
]);

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';

    /* ── Preflight CORS ─────────────────────────────────────── */
    if (request.method === 'OPTIONS') {
      if (!isAllowedOrigin(origin)) {
        return new Response(null, { status: 403, headers: corsHeaders('') });
      }
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    if (origin && !isAllowedOrigin(origin)) {
      return json({ ok: false, error: 'Origin not allowed' }, 403, origin);
    }

    if (!env.SMTP2GO_API_KEY) {
      return json({ ok: false, error: 'Cloudflare secret SMTP2GO_API_KEY is not configured' }, 500, origin);
    }

    /* ── Parse body ─────────────────────────────────────────── */
    let data;
    try {
      data = await request.json();
    } catch {
      return json({ ok: false, error: 'Invalid JSON body' }, 400, origin);
    }

    const {
      nombre,
      apellidos,
      email,
      telefono,
      direccion,
      ciudad,
      pais,
      mensaje,
      hcaptchaToken,
      website,
      elapsedMs,
      dlpkg,
      dlurl,
    } = data;

    if (!nombre || !apellidos || !email || !telefono || !ciudad || !pais || (!mensaje && !dlpkg)) {
      return json({ ok: false, error: 'Missing required fields' }, 422, origin);
    }

    if (website) {
      return json({ ok: false, error: 'Spam detected' }, 422, origin);
    }

    if (!Number.isFinite(Number(elapsedMs)) || Number(elapsedMs) < 3000) {
      return json({ ok: false, error: 'Form submitted too quickly' }, 429, origin);
    }

    if (!dlpkg && mensaje.trim().length < 20) {
      return json({ ok: false, error: 'Message is too short' }, 422, origin);
    }

    if (env.HCAPTCHA_SECRET) {
      if (!hcaptchaToken) {
        return json({ ok: false, error: 'Missing hCaptcha token' }, 422, origin);
      }

      const verification = await verifyHCaptcha(env.HCAPTCHA_SECRET, hcaptchaToken, request.headers.get('CF-Connecting-IP') || '');
      if (!verification.success) {
        return json({ ok: false, error: 'hCaptcha verification failed' }, 403, origin);
      }
    }

    /* ── Build HTML email ───────────────────────────────────── */
    const isDownload = !!(dlpkg || dlurl);
    const visitorName = `${nombre.trim()} ${apellidos.trim()}`;

    const subject = isDownload
      ? `Solicitud de descarga: ${dlpkg ? dlpkg.slice(0, 60) : 'software'} – ${visitorName}`
      : `Contacto web: ${visitorName}`;

    // Strip the 'Descarga: <pkg>\nNotas: ' prefix injected by formulario-descarga.html
    let userNotes = mensaje || '';
    if (dlpkg && userNotes.startsWith(`Descarga: ${dlpkg}`)) {
      userNotes = userNotes.slice(`Descarga: ${dlpkg}`.length).replace(/^\nNotas: /, '').trim();
    }
    const notesSection = userNotes
      ? `<tr><td colspan="2" style="padding:10px 20px;font-weight:600;border-top:1px solid #d0dce6">Notas adicionales</td></tr>
         <tr><td colspan="2" style="padding:10px 20px;background:#f3f7fb;white-space:pre-wrap">${esc(userNotes)}</td></tr>`
      : '';

    const downloadBlock = isDownload ? `
        <tr style="background:#e3f4ff">
          <td style="padding:10px 20px;font-weight:600;color:#006699" colspan="2">&#128230; Descarga solicitada</td>
        </tr>
        <tr>
          <td style="padding:10px 20px;font-weight:600;width:160px">Descarga</td>
          <td style="padding:10px 20px"><a href="${esc(dlurl || '')}" style="color:#006699;font-weight:700">${esc(dlpkg || dlurl || '—')}</a></td>
        </tr>
` : '';

    const contactBlock = `
        <tr style="border-top:1px solid #d0dce6">
          <td style="padding:10px 20px;font-weight:600;width:160px">Nombre</td>
          <td style="padding:10px 20px">${esc(nombre)} ${esc(apellidos)}</td>
        </tr>
        <tr style="background:#f3f7fb">
          <td style="padding:10px 20px;font-weight:600">Email</td>
          <td style="padding:10px 20px">${esc(email)}</td>
        </tr>
        <tr>
          <td style="padding:10px 20px;font-weight:600">Teléfono</td>
          <td style="padding:10px 20px">${esc(telefono)}</td>
        </tr>
        <tr style="background:#f3f7fb">
          <td style="padding:10px 20px;font-weight:600">Ciudad / País</td>
          <td style="padding:10px 20px">${esc(ciudad)}, ${esc(pais)}</td>
        </tr>`;

    const html = `
      <table style="font-family:sans-serif;font-size:15px;color:#123047;border-collapse:collapse;width:100%;max-width:640px">
        <tr><td colspan="2" style="background:#006699;color:#fff;padding:14px 20px;font-size:18px;font-weight:700">
          ${isDownload ? 'Solicitud de descarga – ACM SL' : 'Nuevo mensaje de contacto – ACM SL'}
        </td></tr>
        ${downloadBlock}
        ${notesSection}
        ${contactBlock}
        <tr><td colspan="2" style="padding:14px 20px;font-size:13px;color:#516272">
          ACM SL &middot; support@acm-sl.com &middot; www.acm-sl.com
        </td></tr>
      </table>`;

    /* ── Send single email to both support and visitor ──────── */
    const toList = [RECIPIENT];
    if (email) toList.push(`${visitorName} <${email}>`);

    let smtpRes, smtpJson;
    try {
      smtpRes  = await fetch('https://api.smtp2go.com/v3/email/send', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({
          api_key:   env.SMTP2GO_API_KEY,
          sender:    SENDER,
          to:        toList,
          subject,
          html_body: html,
        }),
      });
      smtpJson = await smtpRes.json();
    } catch (err) {
      return json({ ok: false, error: `Network error: ${err.message}` }, 502, origin);
    }

    if (!smtpRes.ok || smtpJson.data?.error) {
      return json({ ok: false, error: smtpJson.data?.error || `SMTP2GO HTTP ${smtpRes.status}` }, 502, origin);
    }

    return json({ ok: true, email_id: smtpJson.data?.email_id }, 200, origin);
  },
};

/* ── Helpers ────────────────────────────────────────────────── */
function json(body, status = 200, origin = '') {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
  });
}

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': isAllowedOrigin(origin) ? origin : 'https://www.acm-sl.com',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin',
  };
}

function isAllowedOrigin(origin) {
  return ALLOWED_ORIGINS.has(origin);
}

async function verifyHCaptcha(secret, token, remoteIp) {
  try {
    const body = new URLSearchParams({
      secret,
      response: token,
      remoteip: remoteIp,
    });

    const response = await fetch('https://hcaptcha.com/siteverify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });

    return await response.json();
  } catch {
    return { success: false };
  }
}

function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
