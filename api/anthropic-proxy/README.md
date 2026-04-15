# Anthropic Proxy — Cloudflare Worker

Proxy seguro entre o front (`lideres.tatasushi.tech`) e a API da Anthropic.
Existe para que **a chave da API nunca seja exposta no navegador**.

---

## 1. Pré-requisitos

- Conta Cloudflare (qualquer plano, inclusive Free)
- Domínio `tatasushi.tech` no Cloudflare (já está, pois `lideres.tatasushi.tech` aponta para o GitHub Pages)
- Chave da Anthropic em https://console.anthropic.com — defina **um budget mensal** antes de gerar a chave

---

## 2. Deploy via Dashboard (mais simples — 5 min)

1. Entre no Cloudflare → **Workers & Pages** → **Create application** → **Create Worker**
2. Nome sugerido: `lideres-api`
3. Cole o conteúdo de `worker.js` no editor e clique em **Save and deploy**
4. Em **Settings → Variables**:
   - **Add variable** (Secret) → Name: `ANTHROPIC_API_KEY` → Value: sua chave (`sk-ant-...`)
   - (Opcional) **Add variable** (Plain) → Name: `ALLOWED_ORIGIN` → Value: `https://lideres.tatasushi.tech`
5. Em **Settings → Triggers → Custom Domains** → **Add Custom Domain** → `lideres-api.tatasushi.tech`
   (o Cloudflare cria o registro DNS automaticamente)
6. Pegue a URL final: `https://lideres-api.tatasushi.tech`

---

## 3. Deploy via Wrangler (CLI — opcional)

```bash
npm install -g wrangler
wrangler login
wrangler deploy worker.js --name lideres-api
wrangler secret put ANTHROPIC_API_KEY   # cola a chave quando pedir
```

---

## 4. Conectar o front

Edite `compliance/areas/rh/sancoes.html` e troque a constante no topo do bloco IA:

```js
var AI_PROXY_URL = 'https://lideres-api.tatasushi.tech/sancao';
```

Pelo endpoint do seu Worker (sem `/sancao` se você não criou rota — o Worker aceita qualquer path):

```js
var AI_PROXY_URL = 'https://lideres-api.tatasushi.tech';
```

Commit, push, GitHub Pages publica em ~1 min.

---

## 5. Limites e segurança embutidos

| Camada                  | Limite                           |
|-------------------------|----------------------------------|
| Rate limit por IP       | 30 req/h (em memória do isolate) |
| Origem permitida (CORS) | `https://lideres.tatasushi.tech` |
| Métodos aceitos         | `POST` (e `OPTIONS` p/ CORS)     |
| `max_tokens` máximo     | 2000                             |
| Modelos permitidos      | `claude-sonnet-4-5`, `claude-opus-4-6`, `claude-haiku-4-5-20251001` |

> Para rate limit persistente entre regiões/isolates, migrar a `rateMap` para um KV namespace ou Durable Object. Para o uso atual (ferramenta interna do RH) o limite em memória é suficiente.

---

## 6. Testando

```bash
curl -X POST https://lideres-api.tatasushi.tech \
  -H "Origin: https://lideres.tatasushi.tech" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "max_tokens": 100,
    "messages": [{"role":"user","content":"Diga olá em uma linha."}]
  }'
```

Resposta esperada: JSON com `content[0].text`. Se aparecer `"error"`, conferir:
- Variável `ANTHROPIC_API_KEY` configurada como **Secret** (não Plain)
- Origem do request bate com `ALLOWED_ORIGIN`

---

## 7. Custos

Cada geração da sanção (~1.200 tokens de entrada + ~600 de saída) custa cerca de **US$ 0,012 com Sonnet 4.5** ou **US$ 0,002 com Haiku 4.5**.
Definir budget mensal de **US$ 10–20** no console é mais que suficiente para o volume previsto (centenas de sanções/mês).

Para reduzir custo, trocar `AI_MODEL` no front para `claude-haiku-4-5-20251001`.
