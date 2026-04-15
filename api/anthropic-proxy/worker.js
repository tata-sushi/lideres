/**
 * Cloudflare Worker — proxy seguro para a API da Anthropic.
 *
 * Recebe requisições do front (lideres.tatasushi.tech) e encaminha
 * para api.anthropic.com adicionando os headers de autenticação.
 *
 * Configuração necessária no Cloudflare:
 *   - Variável (Secret): ANTHROPIC_API_KEY
 *   - Variável (Plain) opcional: ALLOWED_ORIGIN (default: https://lideres.tatasushi.tech)
 *
 * Limites embutidos:
 *   - Rate limit por IP: 30 req / hora (em memória — para produção usar KV/D1)
 *   - Apenas POST
 *   - Apenas requisições vindas da origem permitida (CORS)
 */

const ANTHROPIC_URL    = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VER    = '2023-06-01';
const RATE_WINDOW_MS   = 60 * 60 * 1000; // 1 hora
const RATE_MAX         = 30;             // 30 req/h por IP
const MAX_TOKENS_LIMIT = 2000;
const ALLOWED_MODELS   = new Set([
  'claude-sonnet-4-5',
  'claude-opus-4-6',
  'claude-haiku-4-5-20251001'
]);

// rate limit em memória (reseta a cada deploy / migração de isolate).
// Para garantia entre regiões, migrar para KV ou Durable Object.
const rateMap = new Map();

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin'
  };
}

function json(body, status, extraHeaders) {
  return new Response(JSON.stringify(body), {
    status: status || 200,
    headers: Object.assign(
      { 'Content-Type': 'application/json' },
      extraHeaders || {}
    )
  });
}

function checkRate(ip) {
  const now = Date.now();
  const arr = (rateMap.get(ip) || []).filter(t => now - t < RATE_WINDOW_MS);
  if (arr.length >= RATE_MAX) {
    return { ok: false, retryAfter: Math.ceil((RATE_WINDOW_MS - (now - arr[0])) / 1000) };
  }
  arr.push(now);
  rateMap.set(ip, arr);
  return { ok: true };
}

export default {
  async fetch(request, env) {
    const allowedOrigin = env.ALLOWED_ORIGIN || 'https://lideres.tatasushi.tech';
    const origin = request.headers.get('Origin') || '';
    const cors = corsHeaders(allowedOrigin);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    // só aceita POST
    if (request.method !== 'POST') {
      return json({ error: 'Método não permitido' }, 405, cors);
    }

    // valida origem (defesa em profundidade — não basta CORS)
    if (origin !== allowedOrigin) {
      return json({ error: 'Origem não autorizada' }, 403, cors);
    }

    // valida API key configurada
    if (!env.ANTHROPIC_API_KEY) {
      return json({ error: 'Servidor não configurado: ANTHROPIC_API_KEY ausente' }, 500, cors);
    }

    // rate limit por IP
    const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
    const rate = checkRate(ip);
    if (!rate.ok) {
      return json(
        { error: 'Rate limit excedido. Tente novamente em ' + Math.ceil(rate.retryAfter / 60) + ' min.' },
        429,
        Object.assign({}, cors, { 'Retry-After': String(rate.retryAfter) })
      );
    }

    // parse e validação do payload
    let payload;
    try {
      payload = await request.json();
    } catch (e) {
      return json({ error: 'JSON inválido' }, 400, cors);
    }

    const model = payload.model || 'claude-sonnet-4-5';
    if (!ALLOWED_MODELS.has(model)) {
      return json({ error: 'Modelo não permitido: ' + model }, 400, cors);
    }

    const maxTokens = Math.min(payload.max_tokens || 1000, MAX_TOKENS_LIMIT);
    const messages = payload.messages;
    if (!Array.isArray(messages) || messages.length === 0) {
      return json({ error: 'Campo "messages" obrigatório' }, 400, cors);
    }

    // encaminha pra Anthropic
    try {
      const upstream = await fetch(ANTHROPIC_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': ANTHROPIC_VER
        },
        body: JSON.stringify({
          model: model,
          max_tokens: maxTokens,
          messages: messages
        })
      });

      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: Object.assign({}, cors, { 'Content-Type': 'application/json' })
      });
    } catch (e) {
      return json({ error: 'Falha ao contatar Anthropic: ' + e.message }, 502, cors);
    }
  }
};
