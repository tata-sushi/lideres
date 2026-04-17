// api/proxy.js
// Vercel Function — proxy entre o React e o Apps Script
// Resolve o CORS: o browser chama /api/proxy, a função chama o Apps Script

export default async function handler(req, res) {
  // Headers CORS — permite chamadas do domínio próprio
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const APPS_SCRIPT_URL = process.env.APPS_SCRIPT_URL;
  if (!APPS_SCRIPT_URL) {
    return res.status(500).json({ ok: false, error: 'APPS_SCRIPT_URL não configurada' });
  }

  try {
    let response;

    if (req.method === 'GET') {
      // Repassa todos os query params para o Apps Script
      const qs = new URLSearchParams(req.query).toString();
      response = await fetch(`${APPS_SCRIPT_URL}?${qs}`);

    } else if (req.method === 'POST') {
      response = await fetch(APPS_SCRIPT_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain' },
        body: JSON.stringify(req.body),
      });
    } else {
      return res.status(405).json({ ok: false, error: 'Método não permitido' });
    }

    const data = await response.json();
    return res.status(200).json(data);

  } catch (err) {
    console.error('[proxy]', err.message);
    return res.status(502).json({ ok: false, error: err.message });
  }
}
