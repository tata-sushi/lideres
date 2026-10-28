// agente-whatsapp — Sam, assistente do RH no WhatsApp.
//
// Fluxo: uazapi (instância do Sam) → POST aqui (webhook) → confere a lista fixa
// (dp_rh.agente_usuarios) → Claude via OpenRouter com a ferramenta
// `consultar_banco` (tata_plus.agente_sql: só-leitura, só as visões do schema
// `agente`) → responde pela uazapi → grava pergunta/consultas/resposta.
//
// Senhas em dp_rh.agente_config: 'webhook_secret' vai na URL do webhook
// (…/agente-whatsapp?k=<senha>); 'teste_secret' só no modo teste.
// Secrets (Supabase → Edge Functions → Secrets):
//   SAM_UAZAPI_TOKEN       token da instância uazapi do Sam
//   SAM_UAZAPI_URL         (opcional) base da uazapi; padrão https://tatasushi.uazapi.com
//   LLM_API_URL / LLM_API_KEY  já existem (gerar-cardapio) — OpenRouter
//   AGENTE_LLM_MODEL       (opcional) padrão anthropic/claude-sonnet-5.5
// (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY são injetados.)
//
// Teste sem WhatsApp: POST …?teste=<teste_secret> com {"texto":"…"} → devolve a
// resposta no corpo, não envia nada e não exige número cadastrado. Senha
// separada porque a URL do webhook fica visível no painel da uazapi.
import { createClient } from "jsr:@supabase/supabase-js@2";

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

const UAZ_BASE = (Deno.env.get("SAM_UAZAPI_URL") || "https://tatasushi.uazapi.com").replace(/\/+$/, "");
const UAZ_TOKEN = Deno.env.get("SAM_UAZAPI_TOKEN") ?? "";
const LLM_URL = Deno.env.get("LLM_API_URL") || "https://openrouter.ai/api/v1/chat/completions";
const LLM_KEY = Deno.env.get("LLM_API_KEY") ?? "";
const MODELOS = [...new Set([
  Deno.env.get("AGENTE_LLM_MODEL") || "anthropic/claude-sonnet-5.5",
  "anthropic/claude-sonnet-5.5",
  "anthropic/claude-sonnet-5",
])];
const MAX_PASSOS = 8;

const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
  db: { schema: "tata_plus" },
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });

// ── leitura do webhook (tolerante ao formato da uazapi) ─────────────────────
type Entrada = { telefone: string; texto: string; msgId: string | null; nome: string };

function digitos(v: unknown): string {
  const s = String(v ?? "");
  if (/@(g\.us|lid|broadcast|newsletter)/.test(s)) return "";
  return s.split("@")[0].split(":")[0].replace(/\D/g, "");
}

function lerWebhook(p: any): { ok: true; e: Entrada } | { ok: false; motivo: string; telefone?: string } {
  const evento = String(p?.EventType ?? p?.event ?? p?.type ?? "");
  if (evento && !/message/i.test(evento)) return { ok: false, motivo: "evento:" + evento };
  const m = p?.message ?? p?.data?.message ?? p?.data ?? {};
  if (m.fromMe === true || m.key?.fromMe === true || m.wasSentByApi === true) return { ok: false, motivo: "proprio" };
  const chat = String(m.chatid ?? m.key?.remoteJid ?? p?.chat?.wa_chatid ?? "");
  if (m.isGroup === true || chat.endsWith("@g.us")) return { ok: false, motivo: "grupo" };

  const telefone = [m.sender_pn, chat, m.sender, p?.chat?.phone, p?.chat?.wa_chatid]
    .map(digitos).find((d) => d.length >= 10) ?? "";
  if (!telefone) return { ok: false, motivo: "sem_telefone" };

  const c = m.content;
  const texto = String(
    m.text ?? (typeof c === "string" ? c : c?.text ?? c?.conversation) ?? m.body ?? m.conversation ?? "",
  ).trim();
  const tipo = String(m.messageType ?? m.type ?? "");
  if (!texto) return { ok: false, motivo: "sem_texto:" + tipo, telefone };

  return {
    ok: true,
    e: { telefone, texto, msgId: m.messageid ?? m.id ?? m.key?.id ?? null, nome: String(m.senderName ?? "") },
  };
}

// ── WhatsApp ────────────────────────────────────────────────────────────────
function paraWhatsApp(t: string): string {
  return t
    .replace(/\*\*(.+?)\*\*/g, "*$1*")
    .replace(/^#{1,6}\s*(.+)$/gm, "*$1*")
    .replace(/^\s*[-*]\s+/gm, "• ")
    .trim();
}

function partes(t: string, max = 3500): string[] {
  const out: string[] = [];
  let resto = t;
  while (resto.length > max) {
    let corte = resto.lastIndexOf("\n\n", max);
    if (corte < max / 2) corte = resto.lastIndexOf("\n", max);
    if (corte < max / 2) corte = max;
    out.push(resto.slice(0, corte).trim());
    resto = resto.slice(corte).trim();
  }
  if (resto) out.push(resto);
  return out;
}

async function enviar(numero: string, texto: string) {
  if (!UAZ_TOKEN) throw new Error("sem SAM_UAZAPI_TOKEN");
  for (const parte of partes(texto)) {
    const r = await fetch(UAZ_BASE + "/send/text", {
      method: "POST",
      headers: { "Content-Type": "application/json", token: UAZ_TOKEN },
      body: JSON.stringify({ number: numero, text: parte, delay: 0, linkPreview: false }),
    });
    if (!r.ok) throw new Error("uazapi " + r.status + ": " + (await r.text().catch(() => "")).slice(0, 300));
  }
}

// ── contexto do banco ───────────────────────────────────────────────────────
const segredos: Record<string, string> = {};

async function segredo(chave: "webhook_secret" | "teste_secret"): Promise<string> {
  if (segredos[chave] === undefined) {
    const { data, error } = await supa.rpc("agente_segredo", { p_chave: chave });
    if (error) throw new Error("segredo: " + error.message);
    segredos[chave] = String(data ?? "");
  }
  return segredos[chave];
}

let catalogoCache: string | null = null;

async function catalogo(): Promise<string> {
  if (catalogoCache) return catalogoCache;
  const { data, error } = await supa.rpc("agente_catalogo");
  if (error) throw new Error("catalogo: " + error.message);
  catalogoCache = (data as any[]).map((v) =>
    `agente.${v.visao}${v.descricao ? " — " + v.descricao : ""}\n` +
    (v.colunas as any[]).map((c) => `  · ${c.nome} (${c.tipo})${c.descricao ? ": " + c.descricao : ""}`).join("\n")
  ).join("\n\n");
  return catalogoCache;
}

function agoraSP(): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo", weekday: "long", day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  }).format(new Date());
}

function sistema(nomeUsuario: string, mapa: string): any[] {
  const regras = `Você é o Sam, assistente do RH do TATÁ Sushi / TATÁ Poke, conversando pelo WhatsApp com ${nomeUsuario || "alguém do RH"}.
Você responde perguntas sobre colaboradores, recrutamento, escalas, ausências, férias, exames, desligamentos etc., SEMPRE consultando o banco com a ferramenta consultar_banco. Nunca invente número, nome ou data: se não achou, diga que não achou.

Agora: ${agoraSP()} (horário de São Paulo).

COMO CONSULTAR
• Só existem as visões do schema agente listadas abaixo. Uma consulta por chamada, só SELECT/WITH, sem ponto e vírgula e sem comentários.
• Use agente.hoje() para "hoje" (current_date do banco está em UTC).
• Nomes: busque sem acento e por parte do nome — agente.sem_acento(nome) ilike agente.sem_acento('%jessica%'). Se aparecer mais de uma pessoa possível, pergunte qual antes de responder.
• Prefira agregar no banco (count, group by) em vez de trazer linhas soltas. O resultado vem com no máximo 200 linhas.
• Se der erro, corrija a consulta e tente de novo. Se a pergunta for ambígua (período, unidade), assuma o mais provável e diga o critério que usou.
• Você só lê dados. Se pedirem para alterar algo, explique que isso é feito no portal.
• Dados que não estão disponíveis aqui (CPF, telefone, e-mail, salários e valores, respostas confidenciais de clima/desligamento/ouvidoria): diga que não tem acesso.

COMO RESPONDER (WhatsApp)
• Português, direto e curto: a resposta primeiro, depois o detalhe que ajuda.
• Formatação do WhatsApp: *negrito* com um asterisco, listas com "• ". Nada de tabelas, títulos com # ou **.
• Datas em DD/MM (com ano só se não for o atual). Números com separador brasileiro.
• Para listas longas, mostre os principais e diga quantos faltam.
• Não mostre SQL a menos que peçam.

MAPA DO BANCO (visões disponíveis)
${mapa}`;
  return [{ role: "system", content: [{ type: "text", text: regras, cache_control: { type: "ephemeral" } }] }];
}

const FERRAMENTAS = [{
  type: "function",
  function: {
    name: "consultar_banco",
    description: "Executa UMA consulta SQL somente-leitura (SELECT/WITH) nas visões do schema agente e devolve as linhas em JSON (máx. 200).",
    parameters: {
      type: "object",
      properties: {
        sql: { type: "string", description: "Consulta PostgreSQL. Ex.: select count(*) from agente.recrutamento_candidaturas where ..." },
      },
      required: ["sql"],
    },
  },
}];

// ── LLM (OpenAI-compatible / OpenRouter) ────────────────────────────────────
let modeloOk: string | null = null;

async function chamarLLM(messages: any[]): Promise<{ msg: any; modelo: string; uso: any }> {
  const fila = modeloOk ? [modeloOk] : MODELOS;
  let ultimoErro = "";
  for (const modelo of fila) {
    const r = await fetch(LLM_URL, {
      method: "POST",
      signal: AbortSignal.timeout(90_000),
      headers: {
        Authorization: `Bearer ${LLM_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://lideres.tatasushi.tech",
        "X-Title": "Tata Agente RH",
      },
      body: JSON.stringify({ model: modelo, messages, tools: FERRAMENTAS, temperature: 0.2, max_tokens: 2000 }),
    });
    const txt = await r.text();
    if (r.ok) {
      const out = JSON.parse(txt);
      const msg = out.choices?.[0]?.message;
      if (msg) {
        modeloOk = modelo;
        return { msg, modelo: out.model ?? modelo, uso: out.usage ?? null };
      }
    }
    ultimoErro = `LLM ${r.status} (${modelo}): ${txt.slice(0, 300)}`;
    // só tenta o próximo modelo se o problema parece ser o nome do modelo
    if (!(r.status === 400 || r.status === 404) || !/model/i.test(txt)) break;
  }
  throw new Error(ultimoErro);
}

type Consulta = { sql: string; linhas?: number; erro?: string; ms: number };

async function consultar(sql: string): Promise<{ conteudo: string; reg: Consulta }> {
  const t0 = Date.now();
  const { data, error } = await supa.rpc("agente_sql", { p_sql: sql, p_limite: 200 });
  const ms = Date.now() - t0;
  if (error) return { conteudo: "ERRO: " + error.message, reg: { sql, erro: error.message, ms } };
  let conteudo = JSON.stringify(data);
  if (conteudo.length > 40_000) conteudo = conteudo.slice(0, 40_000) + "… (cortado — agregue mais a consulta)";
  return { conteudo, reg: { sql, linhas: (data as any)?.linhas, ms } };
}

async function responder(nomeUsuario: string, historico: { papel: string; texto: string }[]) {
  const messages: any[] = sistema(nomeUsuario, await catalogo());
  // a conversa precisa começar por mensagem do usuário
  const ini = historico.findIndex((h) => h.papel !== "assistant");
  for (const h of ini < 0 ? [] : historico.slice(ini)) {
    const role = h.papel === "assistant" ? "assistant" : "user";
    const ult = messages[messages.length - 1];
    if (ult.role === role && typeof ult.content === "string") ult.content += "\n\n" + h.texto;
    else messages.push({ role, content: h.texto });
  }

  const consultas: Consulta[] = [];
  let modelo = "";
  const uso = { entrada: 0, saida: 0 };
  for (let passo = 0; passo < MAX_PASSOS; passo++) {
    const r = await chamarLLM(messages);
    modelo = r.modelo;
    uso.entrada += r.uso?.prompt_tokens ?? 0;
    uso.saida += r.uso?.completion_tokens ?? 0;
    const chamadas = r.msg.tool_calls ?? [];
    if (!chamadas.length) {
      return { texto: paraWhatsApp(String(r.msg.content ?? "")), consultas, modelo, uso };
    }
    messages.push({ role: "assistant", content: r.msg.content ?? "", tool_calls: chamadas });
    for (const tc of chamadas) {
      let sql = "";
      try { sql = String(JSON.parse(tc.function?.arguments || "{}").sql ?? ""); } catch { /* argumento inválido */ }
      const { conteudo, reg } = await consultar(sql);
      consultas.push(reg);
      messages.push({ role: "tool", tool_call_id: tc.id, content: conteudo });
    }
  }
  return {
    texto: "Não consegui fechar essa resposta. Tenta perguntar de um jeito mais específico (período, unidade ou pessoa)?",
    consultas, modelo, uso,
  };
}

// ── processamento de uma mensagem ───────────────────────────────────────────
async function processar(e: Entrada, usuario: { telefone: string; nome: string }) {
  const { data: reg, error: eReg } = await supa.rpc("agente_registrar", {
    p_telefone: usuario.telefone, p_papel: "user", p_texto: e.texto, p_msg_id: e.msgId,
  });
  if (eReg) throw new Error("registrar: " + eReg.message);
  if ((reg as any)?.duplicado) return; // webhook reenviado

  let texto: string;
  let meta: Record<string, unknown> = {};
  try {
    const { data: hist } = await supa.rpc("agente_historico", { p_telefone: usuario.telefone });
    const r = await responder(usuario.nome, (hist as any[]) ?? [{ papel: "user", texto: e.texto }]);
    texto = r.texto || "Não encontrei uma resposta para isso.";
    meta = { consultas: r.consultas, modelo: r.modelo, tokens: r.uso };
  } catch (err) {
    texto = "Tive um problema para consultar agora. Tenta de novo em alguns minutos?";
    meta = { erro: String((err as Error)?.message ?? err) };
  }

  try {
    await enviar(e.telefone, texto);
  } catch (err) {
    meta.erro_envio = String((err as Error)?.message ?? err);
  }
  await supa.rpc("agente_registrar", {
    p_telefone: usuario.telefone, p_papel: "assistant", p_texto: texto, p_msg_id: null, p_meta: meta,
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ ok: true });
  const url = new URL(req.url);
  const payload = await req.json().catch(() => null);

  // modo teste: responde no corpo, não envia nem grava
  if (url.searchParams.has("teste")) {
    const t = await segredo("teste_secret");
    if (!t || url.searchParams.get("teste") !== t) return json({ ok: false, erro: "nao_autorizado" }, 401);
    try {
      const r = await responder(String(payload?.nome ?? "Teste"), [{ papel: "user", texto: String(payload?.texto ?? "") }]);
      return json({ ok: true, ...r });
    } catch (err) {
      return json({ ok: false, erro: String((err as Error)?.message ?? err) }, 500);
    }
  }

  const k = await segredo("webhook_secret");
  if (!k || url.searchParams.get("k") !== k) return json({ ok: false, erro: "nao_autorizado" }, 401);

  const lido = lerWebhook(payload);
  if (!lido.ok) {
    if (lido.motivo === "sem_telefone") {
      await supa.rpc("agente_ignorado", { p_motivo: lido.motivo, p_telefone: null, p_payload: payload });
    } else if (lido.motivo.startsWith("sem_texto") && lido.telefone) {
      // áudio, foto etc. — só avisa quem está na lista
      const { data: u } = await supa.rpc("agente_usuario", { p_telefone: lido.telefone });
      await supa.rpc("agente_ignorado", { p_motivo: lido.motivo, p_telefone: lido.telefone, p_payload: u ? payload : null });
      if (u) await enviar(lido.telefone, "Por enquanto eu só entendo mensagem de texto. Pode escrever a pergunta?").catch(() => {});
    }
    return json({ ok: true, ignorado: lido.motivo });
  }

  const { data: usuario } = await supa.rpc("agente_usuario", { p_telefone: lido.e.telefone });
  if (!usuario) {
    await supa.rpc("agente_ignorado", { p_motivo: "nao_cadastrado", p_telefone: lido.e.telefone, p_payload: null });
    return json({ ok: true, ignorado: "nao_cadastrado" });
  }

  // responde já ao webhook e processa em segundo plano (a IA pode levar ~10–40s)
  EdgeRuntime.waitUntil(
    processar(lido.e, usuario as any).catch((err) =>
      supa.rpc("agente_ignorado", { p_motivo: "falha:" + String(err?.message ?? err).slice(0, 200), p_telefone: lido.e.telefone })
    ),
  );
  return json({ ok: true });
});
