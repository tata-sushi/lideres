// agente-whatsapp — Sam, assistente do RH num grupo de WhatsApp.
//
// Fluxo: uazapi (instância do Sam) → n8n (fluxo próprio do agente, repassa só grupo) → POST aqui
// → grupo autorizado (dp_rh.agente_grupos)? → chamaram o Sam ("Sam, …", @Sam ou
// reply a uma mensagem dele)? → Claude via OpenRouter com a ferramenta
// `consultar_banco` (tata_plus.agente_sql: só-leitura, só as visões do schema
// `agente`) → responde no grupo citando a pergunta → grava tudo (auditoria).
//
// Decisões (28/10): só em grupo (privado é ignorado); todos do grupo podem
// perguntar; grupo novo nasce pendente e é liberado no banco.
//
// Banco (dp_rh.agente_config): webhook_secret (URL ?k=), teste_secret (modo
// teste), uazapi_token (instância do Sam), prompt_estilo (persona/jeito de
// responder — editável sem publicar), bot_ids (número e LID do Sam p/
// reconhecer @menção, separados por vírgula).
// Secrets (Supabase → Edge Functions → Secrets), todos opcionais:
//   SAM_UAZAPI_TOKEN       sobrepõe o uazapi_token do banco
//   SAM_UAZAPI_URL         base da uazapi; padrão https://tatasushi.uazapi.com
//   LLM_API_URL / LLM_API_KEY  já existem (gerar-cardapio) — OpenRouter
//   AGENTE_LLM_MODEL       (opcional) padrão anthropic/claude-sonnet-5.5
// (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY são injetados.)
//
// Teste sem WhatsApp: POST …?teste=<teste_secret> com {"texto":"…"} → devolve a
// resposta no corpo, não envia nada. Senha separada porque a URL do webhook
// fica visível no n8n/uazapi.
import { createClient } from "jsr:@supabase/supabase-js@2";

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

const UAZ_BASE = (Deno.env.get("SAM_UAZAPI_URL") || "https://tatasushi.uazapi.com").replace(/\/+$/, "");
const UAZ_TOKEN_ENV = Deno.env.get("SAM_UAZAPI_TOKEN") ?? "";
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

const erroTxt = (err: unknown) => String((err as Error)?.message ?? err);

// ── leitura do webhook (tolerante ao formato da uazapi) ─────────────────────
type Entrada = {
  grupo: boolean;
  chatId: string;          // id da conversa (…@g.us no grupo)
  grupoNome: string;
  autorId: string;         // número ou id de quem mandou
  autorNome: string;
  texto: string;
  msgId: string | null;
  citadoId: string | null;        // id da mensagem respondida (reply)
  citadoAutor: string;            // dígitos de quem escreveu a mensagem respondida
  mencoes: string[];              // dígitos dos @mencionados
  dono: string;                   // dígitos do número do Sam (owner da instância)
};

const soDigitos = (v: unknown) => String(v ?? "").split("@")[0].split(":")[0].replace(/\D/g, "");

function lerWebhook(p: any): { ok: true; e: Entrada } | { ok: false; motivo: string } {
  const evento = String(p?.EventType ?? p?.event ?? p?.type ?? "");
  if (evento && !/message/i.test(evento)) return { ok: false, motivo: "evento:" + evento };
  const m = p?.message ?? p?.data?.message ?? p?.data ?? {};
  if (m.fromMe === true || m.key?.fromMe === true || m.wasSentByApi === true) return { ok: false, motivo: "proprio" };

  const chatId = String(m.chatid ?? m.key?.remoteJid ?? p?.chat?.wa_chatid ?? "");
  const grupo = m.isGroup === true || chatId.endsWith("@g.us");
  const c = typeof m.content === "object" && m.content ? m.content : {};
  const ctx = c.contextInfo ?? m.contextInfo ?? {};
  const texto = String(
    m.text ?? (typeof m.content === "string" ? m.content : c.text ?? c.conversation) ?? m.body ?? m.conversation ?? "",
  ).trim();
  if (!texto) return { ok: false, motivo: "sem_texto:" + String(m.messageType ?? m.type ?? "") };

  const citado = m.quoted ?? m.quotedMsg ?? null;
  const mencoes = [ctx.mentionedJid, m.mentionedJid, m.mentions, c.mentionedJid]
    .find((a) => Array.isArray(a)) as unknown[] | undefined;

  return {
    ok: true,
    e: {
      grupo,
      chatId,
      grupoNome: String(p?.chat?.name ?? p?.chat?.wa_name ?? m.groupName ?? m.chatName ?? ""),
      autorId: String(m.sender_pn ?? m.sender ?? m.participant ?? m.key?.participant ?? chatId),
      autorNome: String(m.senderName ?? m.pushName ?? ""),
      texto,
      msgId: m.messageid ?? m.id ?? m.key?.id ?? null,
      citadoId: (typeof citado === "string" ? citado : citado?.messageid ?? citado?.id ?? null) ??
        ctx.stanzaId ?? null,
      citadoAutor: soDigitos(citado?.sender ?? citado?.participant ?? ctx.participant ?? ""),
      mencoes: (mencoes ?? []).map(soDigitos).filter(Boolean),
      dono: soDigitos(p?.owner ?? p?.instance?.owner ?? ""),
    },
  };
}

// chamaram o Sam? devolve o texto da pergunta (sem o chamado) ou null
async function chamado(e: Entrada, botIds: string[]): Promise<string | null> {
  const ids = [e.dono, ...botIds].filter(Boolean);
  const semMencaoDoSam = (t: string) =>
    ids.reduce((s, id) => s.replaceAll("@" + id, " "), t).replace(/\s+/g, " ").trim();

  // 1) começa com "Sam" ou "@Sam"
  const porNome = e.texto.match(/^\s*@?sam\b[\s,:;!.\-–—]*/i);
  if (porNome) return semMencaoDoSam(e.texto.slice(porNome[0].length)) || e.texto;
  // 2) @menção ao número do Sam (lista de menções ou "@<número>" no texto) ou "@Sam" no meio
  if (ids.some((id) => e.mencoes.includes(id) || e.texto.includes("@" + id)) || /(^|\s)@sam\b/i.test(e.texto)) {
    return semMencaoDoSam(e.texto.replace(/(^|\s)@sam\b/gi, " ")) || e.texto;
  }
  // 3) reply a uma mensagem do Sam
  if (e.citadoAutor && ids.includes(e.citadoAutor)) return e.texto;
  if (e.citadoId) {
    const { data } = await supa.rpc("agente_msg_do_sam", { p_msg_id: e.citadoId });
    if (data === true) return e.texto;
  }
  return null;
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

// envia (citando a pergunta na 1ª parte) e devolve os ids das mensagens enviadas
async function enviar(destino: string, texto: string, citarId: string | null): Promise<string[]> {
  const token = UAZ_TOKEN_ENV || await segredo("uazapi_token");
  if (!token) throw new Error("sem token da uazapi (agente_config.uazapi_token)");
  const ids: string[] = [];
  for (const [i, parte] of partes(texto).entries()) {
    const corpo: Record<string, unknown> = { number: destino, text: parte, delay: 0, linkPreview: false };
    if (i === 0 && citarId) corpo.replyid = citarId;
    const r = await fetch(UAZ_BASE + "/send/text", {
      method: "POST",
      headers: { "Content-Type": "application/json", token },
      body: JSON.stringify(corpo),
    });
    const txt = await r.text().catch(() => "");
    if (!r.ok) throw new Error("uazapi " + r.status + ": " + txt.slice(0, 300));
    try {
      const out = JSON.parse(txt);
      const id = out?.messageid ?? out?.id ?? out?.key?.id ?? out?.message?.messageid;
      if (id) ids.push(String(id));
    } catch { /* resposta sem JSON */ }
  }
  return ids;
}

// ── configuração no banco ───────────────────────────────────────────────────
const segredos: Record<string, string> = {};

async function segredo(chave: "webhook_secret" | "teste_secret" | "uazapi_token"): Promise<string> {
  if (segredos[chave] === undefined) {
    const { data, error } = await supa.rpc("agente_segredo", { p_chave: chave });
    if (error) throw new Error("segredo: " + error.message);
    segredos[chave] = String(data ?? "");
  }
  return segredos[chave];
}

// prompt_estilo e bot_ids — relidos a cada minuto (editar no banco vale sem publicar)
let params: { estilo: string; botIds: string[]; em: number } | null = null;

async function parametros() {
  if (!params || Date.now() - params.em > 60_000) {
    const { data, error } = await supa.rpc("agente_parametros");
    if (error) throw new Error("parametros: " + error.message);
    const d = (data ?? {}) as Record<string, string>;
    params = {
      estilo: d.prompt_estilo || "Você é o Sam, assistente do RH do TATÁ. Responda em português, curto, no formato do WhatsApp.",
      botIds: String(d.bot_ids ?? "").split(",").map(soDigitos).filter(Boolean),
      em: Date.now(),
    };
  }
  return params;
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

// prompt = estilo (editável no banco) + regras técnicas de consulta (fixas aqui)
function sistema(estilo: string, grupoNome: string, mapa: string): any[] {
  const tecnico = `Agora: ${agoraSP()} (horário de São Paulo).${grupoNome ? ` Grupo: ${grupoNome}.` : ""}

FONTE DOS DADOS
Responda SEMPRE consultando o banco com a ferramenta consultar_banco. Nunca invente número, nome ou data: se não achou, diga que não achou. Todos do grupo leem a resposta.

COMO CONSULTAR
• Só existem as visões do schema agente listadas abaixo. Uma consulta por chamada, só SELECT/WITH, sem ponto e vírgula e sem comentários.
• Use agente.hoje() para "hoje" (current_date do banco está em UTC).
• Nomes: busque sem acento e por parte do nome — agente.sem_acento(nome) ilike agente.sem_acento('%jessica%'). Se aparecer mais de uma pessoa possível, pergunte qual antes de responder.
• Prefira agregar no banco (count, group by) em vez de trazer linhas soltas. O resultado vem com no máximo 200 linhas.
• Se der erro, corrija a consulta e tente de novo. Se a pergunta for ambígua (período, unidade), assuma o mais provável e diga o critério que usou.
• Você só lê dados. Se pedirem para alterar algo, explique que isso é feito no portal.
• Dados que não estão disponíveis aqui (CPF, telefone, e-mail, salários e valores, respostas confidenciais de clima/desligamento/ouvidoria): diga que não tem acesso.

MAPA DO BANCO (visões disponíveis)
${mapa}`;
  return [{ role: "system", content: [{ type: "text", text: estilo + "\n\n" + tecnico, cache_control: { type: "ephemeral" } }] }];
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

type Fala = { papel: string; texto: string; autor?: string | null };

async function responder(grupoNome: string, historico: Fala[]) {
  const { estilo } = await parametros();
  const messages: any[] = sistema(estilo, grupoNome, await catalogo());
  // a conversa precisa começar por mensagem de usuário
  const ini = historico.findIndex((h) => h.papel !== "assistant");
  for (const h of ini < 0 ? [] : historico.slice(ini)) {
    const role = h.papel === "assistant" ? "assistant" : "user";
    const texto = role === "user" && h.autor ? `${h.autor}: ${h.texto}` : h.texto;
    const ult = messages[messages.length - 1];
    if (ult.role === role && typeof ult.content === "string") ult.content += "\n\n" + texto;
    else messages.push({ role, content: texto });
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

// ── processamento de uma pergunta ───────────────────────────────────────────
async function processar(e: Entrada, pergunta: string, grupoNome: string) {
  const autor = { autor_id: e.autorId, autor_nome: e.autorNome.split(" ")[0] || e.autorNome };
  const { data: reg, error: eReg } = await supa.rpc("agente_registrar", {
    p_telefone: e.chatId, p_papel: "user", p_texto: pergunta, p_msg_id: e.msgId, p_meta: autor,
  });
  if (eReg) throw new Error("registrar: " + eReg.message);
  if ((reg as any)?.duplicado) return; // webhook reenviado

  let texto: string;
  let meta: Record<string, unknown> = {};
  try {
    const { data: hist } = await supa.rpc("agente_historico", { p_telefone: e.chatId });
    const r = await responder(grupoNome, (hist as Fala[]) ?? [{ papel: "user", texto: pergunta, autor: autor.autor_nome }]);
    texto = r.texto || "Não encontrei uma resposta para isso.";
    meta = { consultas: r.consultas, modelo: r.modelo, tokens: r.uso, pergunta_id: e.msgId };
  } catch (err) {
    texto = "Tive um problema para consultar agora. Tenta de novo em alguns minutos?";
    meta = { erro: erroTxt(err), pergunta_id: e.msgId };
  }

  let enviados: string[] = [];
  try {
    enviados = await enviar(e.chatId, texto, e.msgId);
  } catch (err) {
    meta.erro_envio = erroTxt(err);
  }
  // msg_id = id da resposta enviada → reconhece reply ao Sam
  await supa.rpc("agente_registrar", {
    p_telefone: e.chatId, p_papel: "assistant", p_texto: texto, p_msg_id: enviados[0] ?? null,
    p_meta: { ...meta, enviados },
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
      const autor = String(payload?.nome ?? "Teste");
      const r = await responder(String(payload?.grupo ?? "Teste"), [{ papel: "user", texto: String(payload?.texto ?? ""), autor }]);
      return json({ ok: true, ...r });
    } catch (err) {
      return json({ ok: false, erro: erroTxt(err) }, 500);
    }
  }

  const k = await segredo("webhook_secret");
  if (!k || url.searchParams.get("k") !== k) return json({ ok: false, erro: "nao_autorizado" }, 401);

  const lido = lerWebhook(payload);
  if (!lido.ok) return json({ ok: true, ignorado: lido.motivo });
  const e = lido.e;
  if (!e.grupo) return json({ ok: true, ignorado: "privado" }); // decisão: só em grupo

  const pergunta = await chamado(e, (await parametros()).botIds);
  if (!pergunta) return json({ ok: true, ignorado: "nao_chamado" }); // conversa normal do grupo: nada é gravado

  const { data: g, error: eG } = await supa.rpc("agente_grupo", { p_chat_id: e.chatId, p_nome: e.grupoNome });
  if (eG) return json({ ok: false, erro: eG.message }, 500);
  if (!(g as any)?.ativo) {
    // grupo novo: fica pendente até liberar no banco; guarda o payload p/ conferir o formato
    await supa.rpc("agente_ignorado", { p_motivo: "grupo_pendente", p_telefone: e.chatId, p_payload: payload });
    return json({ ok: true, ignorado: "grupo_pendente" });
  }

  // responde já ao webhook e processa em segundo plano (a IA pode levar ~10–40s)
  EdgeRuntime.waitUntil(
    processar(e, pergunta, (g as any)?.nome || e.grupoNome).catch((err) =>
      supa.rpc("agente_ignorado", { p_motivo: "falha:" + erroTxt(err).slice(0, 200), p_telefone: e.chatId })
    ),
  );
  return json({ ok: true });
});
