// agente-whatsapp — Sam, assistente do RH num grupo de WhatsApp.
//
// Fluxo: uazapi (instância do Sam) → n8n (fluxo próprio do agente, repassa) → POST aqui
// → grupo autorizado (dp_rh.agente_grupos) e chamaram o Sam ("Sam, …", @Sam ou
// reply a uma mensagem dele)? ou privado de número cadastrado (dp_rh.agente_usuarios)?
// → Claude via OpenRouter com a ferramenta
// `consultar_banco` (tata_plus.agente_consultar: só-leitura, só as visões dos
// schemas `agente`/`agente_restrito`) → responde no grupo citando a pergunta →
// grava tudo (auditoria).
//
// Decisões (28/10): em grupo autorizado todos podem perguntar (grupo novo nasce
// pendente e é liberado no banco). No privado (02/11) só números cadastrados em
// dp_rh.agente_usuarios; os demais são ignorados. Grupo e pessoa têm nível:
// básico (schema `agente`) ou completo (+ `agente_restrito`: atas, avaliações,
// valores, reclamações).
// Pergunta sem resposta (02/11) vira aviso (#id) no privado do responsável
// (agente_config.responsavel_telefone): número não cadastrado, grupo não
// liberado, a IA chamou `sem_resposta`, ou erro. Ele resolve no privado com o
// Sam: "responde 27", "libera 27", "27: texto", "ignora 27".
//
// Conhecimento (07/11): além do banco, o Sam lê o Portal Líderes — dp_rh.agente_conhecimento,
// alimentada pela edge agente-portal (diário + "atualiza portal"). Identidade do TATÁ e o que o
// responsável ensinou ("aprende: …" / "esquece 12") vão sempre nas instruções; o resto ele busca
// com a ferramenta `buscar_portal` (regras, benefícios, Código de Ética, EPIs, manuais, logos).
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
// Reunião (07/11): POST …?reuniao=<portal_secret> {texto, contexto, nome, titulo} → resposta curta para ser
// falada na sala (usada pela edge agente-reuniao; página compliance/kpis/rh/sam.html).
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

  // reação (👍 numa mensagem), edição, apagar: não é pergunta
  const tipo = String(m.messageType ?? m.type ?? "");
  if (/reaction|protocol|revoke|edited/i.test(tipo) || m.reaction || m.content?.reactionMessage) return { ok: false, motivo: "reacao:" + tipo };

  const chatId = String(m.chatid ?? m.key?.remoteJid ?? p?.chat?.wa_chatid ?? "");
  const grupo = m.isGroup === true || chatId.endsWith("@g.us");
  const c = typeof m.content === "object" && m.content ? m.content : {};
  const ctx = c.contextInfo ?? m.contextInfo ?? {};
  const texto = String(
    m.text ?? (typeof m.content === "string" ? m.content : c.text ?? c.conversation) ?? m.body ?? m.conversation ?? "",
  ).trim();
  if (!texto) return { ok: false, motivo: "sem_texto:" + String(m.messageType ?? m.type ?? "") };
  // só emoji/pontuação ("👍🏽", "!!"): agradecimento ou reação mandada como mensagem — o Sam não responde
  if (!/[\p{L}\p{N}]/u.test(texto)) return { ok: false, motivo: "so_emoji" };

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

// fotos: linhas "Nome: <link>" na resposta viram imagem no WhatsApp (até 10) — avatar do app
// ou imagem publicada no portal (logos, comunicados)
const AVATAR_RE = new RegExp(
  "(?:" + (Deno.env.get("SUPABASE_URL") ?? "").replace(/[.*+?^${}()|[\]\\/]/g, "\\$&") +
    "/storage/v1/object/public/avatares/[^\\s)>\\]]+" +
    "|https://lideres\\.tatasushi\\.tech/[^\\s)>\\]]+\\.(?:png|jpe?g|webp))",
  "i",
);
type Foto = { url: string; legenda: string };

function separarFotos(t: string): { texto: string; fotos: Foto[] } {
  const fotos: Foto[] = [];
  const linhas = t.split("\n").filter((l) => {
    const m = l.match(AVATAR_RE);
    if (!m || fotos.length >= 10) return true;
    const legenda = l.replace(m[0], "").replace(/^[\s•*\-–]+|[\s:*\-–()]+$/g, "").replace(/\*/g, "").trim();
    fotos.push({ url: m[0], legenda });
    return false;
  });
  return { texto: linhas.join("\n").replace(/\n{3,}/g, "\n\n").trim(), fotos };
}

async function enviarImagem(destino: string, foto: Foto): Promise<string | null> {
  const token = UAZ_TOKEN_ENV || await segredo("uazapi_token");
  const r = await fetch(UAZ_BASE + "/send/media", {
    method: "POST",
    headers: { "Content-Type": "application/json", token },
    body: JSON.stringify({ number: destino, type: "image", file: foto.url, text: foto.legenda, delay: 0 }),
  });
  const txt = await r.text().catch(() => "");
  if (!r.ok) throw new Error("uazapi media " + r.status + ": " + txt.slice(0, 200));
  try {
    const out = JSON.parse(txt);
    return String(out?.messageid ?? out?.id ?? out?.key?.id ?? "") || null;
  } catch {
    return null;
  }
}

// ── configuração no banco ───────────────────────────────────────────────────
const segredos: Record<string, string> = {};

async function segredo(chave: "webhook_secret" | "teste_secret" | "uazapi_token" | "portal_secret"): Promise<string> {
  if (segredos[chave] === undefined) {
    const { data, error } = await supa.rpc("agente_segredo", { p_chave: chave });
    if (error) throw new Error("segredo: " + error.message);
    segredos[chave] = String(data ?? "");
  }
  return segredos[chave];
}

// prompt_estilo, bot_ids e responsável pelos avisos — relidos a cada minuto (editar no banco vale sem publicar)
let params: { estilo: string; botIds: string[]; responsavel: { telefone: string; nome: string }; em: number } | null =
  null;

async function parametros() {
  if (!params || Date.now() - params.em > 60_000) {
    const { data, error } = await supa.rpc("agente_parametros");
    if (error) throw new Error("parametros: " + error.message);
    const d = (data ?? {}) as Record<string, string>;
    params = {
      estilo: d.prompt_estilo || "Você é o Sam, assistente do RH do TATÁ. Responda em português, curto, no formato do WhatsApp.",
      botIds: String(d.bot_ids ?? "").split(",").map(soDigitos).filter(Boolean),
      responsavel: { telefone: soDigitos(d.responsavel_telefone), nome: d.responsavel_nome || "o RH" },
      em: Date.now(),
    };
  }
  return params;
}

// mapa das visões por nível — relido a cada 10 min (visão/comentário novo vale sem publicar)
const mapas: Record<string, { texto: string; em: number }> = {};

async function catalogo(completo: boolean): Promise<string> {
  const k = completo ? "completo" : "basico";
  if (!mapas[k] || Date.now() - mapas[k].em > 600_000) {
    const { data, error } = await supa.rpc("agente_mapa", { p_completo: completo });
    if (error) throw new Error("mapa: " + error.message);
    const texto = (data as any[]).map((v) =>
      `${v.schema}.${v.visao}${v.descricao ? " — " + v.descricao : ""}\n` +
      (v.colunas as any[]).map((c) => `  · ${c.nome} (${c.tipo})${c.descricao ? ": " + c.descricao : ""}`).join("\n")
    ).join("\n\n");
    mapas[k] = { texto, em: Date.now() };
  }
  return mapas[k].texto;
}

// base de conhecimento (dp_rh.agente_conhecimento): o que vai SEMPRE nas instruções — identidade do
// TATÁ (página idconceitual do portal) e o que o responsável ensinou ("aprende: …") — e o catálogo do
// que dá para buscar (páginas, documentos, arquivos). Relido a cada 10 min; "aprende"/"esquece" limpam.
const saberes: Record<string, { texto: string; em: number }> = {};
const esquecerSaberes = () => { for (const k of Object.keys(saberes)) delete saberes[k]; };

async function conhecimento(completo: boolean): Promise<string> {
  const k = completo ? "completo" : "basico";
  if (!saberes[k] || Date.now() - saberes[k].em > 600_000) {
    const [{ data: sempre, error: e1 }, { data: cat, error: e2 }] = await Promise.all([
      supa.rpc("agente_conhecimento_sempre", { p_completo: completo }),
      supa.rpc("agente_conhecimento_catalogo", { p_completo: completo }),
    ]);
    if (e1 || e2) throw new Error("conhecimento: " + (e1 ?? e2)!.message);
    const itens = (sempre ?? []) as any[];
    const identidade = itens.filter((i) => i.fonte !== "victor").map((i) => i.texto).join("\n\n");
    const ensinado = itens.filter((i) => i.fonte === "victor").map((i) => `• [${i.id}, ${i.em}] ${i.texto}`).join("\n");
    const c = (cat ?? {}) as any;
    const paginas = ((c.paginas ?? []) as any[]).map((p) => p.titulo).filter(Boolean).join(" · ");
    const docs = ((c.pdfs ?? []) as string[]).join(" · ");
    const arquivos = ((c.arquivos ?? []) as any[]).map((a) => `${a.nome}: ${a.url}`).join("\n");
    const texto = [
      identidade && `IDENTIDADE DO TATÁ (do Portal Líderes — é a base do seu jeito de agir)\n${identidade}`,
      `O QUE O RESPONSÁVEL TE ENSINOU (vale mais que o portal e que qualquer suposição)\n${ensinado || "• (nada ainda)"}`,
      `PORTAL DOS LÍDERES — conteúdo escrito que você encontra com buscar_portal\n• Páginas: ${paginas || "(nenhuma)"}` +
        (docs ? `\n• Documentos: ${docs}` : "") +
        (arquivos ? `\n• Arquivos publicados (para mandar, use o link):\n${arquivos}` : ""),
    ].filter(Boolean).join("\n\n");
    saberes[k] = { texto, em: Date.now() };
  }
  return saberes[k].texto;
}

function agoraSP(): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo", weekday: "long", day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  }).format(new Date());
}

// onde a conversa acontece: grupo (todos leem), privado (só a pessoa) ou reunião presencial (resposta falada)
type Local = { grupo: string } | { privadoCom: string } | { reuniao: string };

// prompt = estilo (editável no banco) + identidade e regras técnicas de consulta (fixas aqui)
// avisar = nome de quem recebe as perguntas sem resposta ("" quando a conversa já é com essa pessoa)
// chefe = a quem o Sam se reporta (responsável do RH)
function sistema(
  estilo: string, local: Local, mapa: string, completo: boolean, avisar: string, chefe: string, saber: string,
): any[] {
  const foraDoAlcance = completo
    ? "CPF, telefone, e-mail, dados pessoais da ficha de admissão, ouvidoria e respostas confidenciais de clima/desligamento"
    : "CPF, telefone, e-mail, salários e valores em R$, atas de reunião, avaliações, reclamações trabalhistas, ouvidoria e respostas confidenciais de clima/desligamento";
  const onde = "reuniao" in local
    ? ` Você está numa REUNIÃO presencial de RH (${local.reuniao}), ouvindo pelo microfone; a sua resposta vai ser FALADA em voz alta para todos na sala (ignore a menção a WhatsApp/grupo no estilo).`
    : "grupo" in local
    ? `${local.grupo ? ` Grupo: ${local.grupo}.` : ""} Todos do grupo leem a resposta.`
    : ` Conversa PRIVADA com ${local.privadoCom} (só essa pessoa lê; ignore a menção a grupo no estilo).`;
  const falada = "reuniao" in local
    ? `

RESPOSTA FALADA (reunião — vale mais que as regras de formato)
• Fale como um colega na mesa: 1 a 3 frases curtas. Nada de listas, emojis, asteriscos, links, tabelas ou fotos.
• Números e datas do jeito que se fala ("doze vagas", "trinta de novembro").
• A pergunta vem de transcrição automática: se uma palavra parecer errada, entenda pelo contexto; se não der para entender, peça para repetirem.
• A transcrição recente vem junto só como contexto (do que estão falando, quem disse o quê). Não leia nem resuma a transcrição se não pedirem.
• Se pedirem detalhe longo (lista de nomes, tabela), diga o principal e ofereça mandar o resto no WhatsApp.`
    : "";
  const tecnico = `Agora: ${agoraSP()} (horário de São Paulo).${onde}

QUEM VOCÊ É (não anuncie — use só se perguntarem)
• Você é o assistente virtual do RH do TATÁ, não uma pessoa. Não se apresente nem comente isso por conta própria.
• Se perguntarem quem você é, se é robô ou pessoa, ou a quem responde: diga, curto e natural, que é o assistente virtual do RH e que se reporta ao ${chefe} — o que você não resolver, você alinha com ele.
• Nunca diga que é uma pessoa.

SEJA SUCINTO (vale mais que qualquer orientação de estilo acima)
• Responda só o que foi perguntado, em 1 a 3 linhas: o número ou a informação principal.
• Não explique o critério, não detalhe e não ofereça "se quiser, separo por…". Exceção: se a pergunta for ambígua de verdade, diga em poucas palavras o que considerou.
• Só se aprofunde quando pedirem ("detalha", "explica", "lista", "quem são", "por unidade", "em tópicos" etc.). Aí pode trazer listas e quebras.
• Assunto longo (ex.: pautas de reunião): poucos tópicos curtos; a íntegra só se pedirem.${falada}

COMO AGIR (os valores do TATÁ, na prática)
• Ética: não invente nem chute. Se não achou o dado ou a regra, diga que não encontrou${avisar ? " e avise o responsável (sem_resposta)" : ""}.
• Respeito pelos colaboradores: fale das pessoas com respeito, sem julgamento; não exponha ninguém além do necessário para a pergunta (o Código de Ética veda passar dados pessoais de colegas).
• Excelência e bons resultados: confira o número antes de responder; prefira a fonte oficial (banco ou portal) ao "acho que".
• Harmonia entre equipes: tom cordial e calmo; em conflito ou reclamação entre pessoas, oriente a procurar a liderança imediata ou o RH.
• Não desperdício: resposta curta, sem rodeios.

FONTES
• Números, nomes, datas e situação das pessoas (escala, férias, faltas, vagas, sanções…) → banco, com consultar_banco.
• Como o TATÁ funciona (regras, políticas, benefícios e quem tem direito, processos, prazos, conduta, Código de Ética, uniformes/EPIs, conceitos, manuais, identidade, logos e documentos) → buscar_portal, e responda com o que o portal diz. Busque com palavras-chave e sinônimos (ex.: "plano de saúde assistência médica elegibilidade"); se não vier, tente outras palavras.
• O que o responsável te ensinou (abaixo) vale primeiro. Pergunta que mistura regra e dado (ex.: "quando acaba a experiência do Diogo") → regra (ensinado/portal) + data (banco).
• Nunca use "padrão de mercado" ou regra genérica de CLT no lugar da regra do TATÁ. Se a regra do TATÁ não estiver no que foi ensinado nem no portal, diga que não encontrou a regra${avisar ? " e chame sem_resposta" : ""}. Nunca invente número, nome, data ou regra.
• Pode mandar o link da página ou do documento quando ajudar. Para mandar uma imagem do portal (ex.: logo), escreva numa linha "Nome: <link>" — vira imagem.

COMO CONSULTAR
• Só existem as visões listadas abaixo — escreva o nome com o schema (agente.x${completo ? " ou agente_restrito.x" : ""}). Uma consulta por chamada, só SELECT/WITH, sem ponto e vírgula e sem comentários.
• matricula é texto e liga quase tudo a agente.colaboradores. Unidades são texto livre com grafias diferentes entre visões: compare com ilike/sem_acento.
• Use agente.hoje() para "hoje" (current_date do banco está em UTC).
• Nomes: busque sem acento e por parte do nome — agente.sem_acento(nome) ilike agente.sem_acento('%jessica%'). Se aparecer mais de uma pessoa possível, pergunte qual antes de responder.
• Prefira agregar no banco (count, group by) em vez de trazer linhas soltas. O resultado vem com no máximo 200 linhas.
• Se der erro, corrija a consulta e tente de novo. Se a pergunta for ambígua (período, unidade), assuma o mais provável.
• Você só lê dados. Se pedirem para alterar algo, explique que isso é feito no portal.
• Fora do seu alcance nesta conversa (${foraDoAlcance}): diga que não tem acesso.${avisar ? `
• Se não der para responder de verdade (o dado não existe no mapa nem no portal, está fora do seu alcance, ou a pergunta pede ação/decisão de alguém do RH), chame a ferramenta sem_resposta com o motivo em poucas palavras e diga à pessoa que passou para ${avisar}. Não chame quando conseguiu responder.` : ""}

${saber}

MAPA DO BANCO (visões disponíveis)
${mapa}`;
  return [{ role: "system", content: [{ type: "text", text: estilo + "\n\n" + tecnico, cache_control: { type: "ephemeral" } }] }];
}

const FERRAMENTAS = [{
  type: "function",
  function: {
    name: "consultar_banco",
    description: "Executa UMA consulta SQL somente-leitura (SELECT/WITH) nas visões do mapa (agente / agente_restrito) e devolve as linhas em JSON (máx. 200).",
    parameters: {
      type: "object",
      properties: {
        sql: { type: "string", description: "Consulta PostgreSQL. Ex.: select count(*) from agente.recrutamento_candidaturas where ..." },
      },
      required: ["sql"],
    },
  },
}, {
  type: "function",
  function: {
    name: "buscar_portal",
    description: "Busca no conteúdo escrito do Portal Líderes (regras, políticas, benefícios, processos, Código de Ética, " +
      "uniformes/EPIs, conceitos, manuais, identidade do TATÁ) e nos arquivos publicados. Devolve os trechos mais " +
      "relevantes, com a página e o link.",
    parameters: {
      type: "object",
      properties: {
        busca: { type: "string", description: "Palavras-chave e sinônimos. Ex.: \"plano de saúde assistência médica elegibilidade\"" },
      },
      required: ["busca"],
    },
  },
}];

async function buscarPortal(busca: string, completo: boolean): Promise<{ conteudo: string; reg: Consulta }> {
  const t0 = Date.now();
  const { data, error } = await supa.rpc("agente_conhecimento_buscar", { p_busca: busca, p_completo: completo, p_limite: 6 });
  const ms = Date.now() - t0;
  const reg: Consulta = { sql: "portal: " + busca, ms };
  if (error) return { conteudo: "ERRO: " + error.message, reg: { ...reg, erro: error.message } };
  const itens = (data ?? []) as any[];
  reg.linhas = itens.length;
  if (!itens.length) return { conteudo: "Nada encontrado no portal com essas palavras. Tente sinônimos.", reg };
  let conteudo = itens.map((i) =>
    `### ${[i.pagina, i.secao].filter(Boolean).join(" › ")}${i.url ? `\nLink: ${i.url}` : ""}\n${i.texto}`
  ).join("\n\n");
  if (conteudo.length > 14_000) conteudo = conteudo.slice(0, 14_000) + "… (cortado)";
  return { conteudo, reg };
}

const SEM_RESPOSTA = {
  type: "function",
  function: {
    name: "sem_resposta",
    description: "Avisa o responsável do RH que esta pergunta ficou sem resposta (dado inexistente, fora do alcance ou depende de uma pessoa). Depois, responda à pessoa normalmente.",
    parameters: {
      type: "object",
      properties: { motivo: { type: "string", description: "Por que não deu para responder, em poucas palavras." } },
      required: ["motivo"],
    },
  },
};

// ── LLM (OpenAI-compatible / OpenRouter) ────────────────────────────────────
let modeloOk: string | null = null;

async function chamarLLM(messages: any[], tools: any[]): Promise<{ msg: any; modelo: string; uso: any }> {
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
      body: JSON.stringify({ model: modelo, messages, tools, temperature: 0.2, max_tokens: 2000 }),
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

async function consultar(sql: string, completo: boolean): Promise<{ conteudo: string; reg: Consulta }> {
  const t0 = Date.now();
  const { data, error } = await supa.rpc("agente_consultar", { p_sql: sql, p_limite: 200, p_completo: completo });
  const ms = Date.now() - t0;
  if (error) return { conteudo: "ERRO: " + error.message, reg: { sql, erro: error.message, ms } };
  let conteudo = JSON.stringify(data);
  if (conteudo.length > 40_000) conteudo = conteudo.slice(0, 40_000) + "… (cortado — agregue mais a consulta)";
  return { conteudo, reg: { sql, linhas: (data as any)?.linhas, ms } };
}

type Fala = { papel: string; texto: string; autor?: string | null };

async function responder(local: Local, historico: Fala[], completo: boolean, avisar: string) {
  const { estilo, responsavel } = await parametros();
  const [mapa, saber] = await Promise.all([catalogo(completo), conhecimento(completo)]);
  const messages: any[] = sistema(estilo, local, mapa, completo, avisar, responsavel.nome, saber);
  const tools = avisar ? [...FERRAMENTAS, SEM_RESPOSTA] : FERRAMENTAS;
  const semResposta: string[] = [];
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
    const r = await chamarLLM(messages, tools);
    modelo = r.modelo;
    uso.entrada += r.uso?.prompt_tokens ?? 0;
    uso.saida += r.uso?.completion_tokens ?? 0;
    const chamadas = r.msg.tool_calls ?? [];
    if (!chamadas.length) {
      return { texto: paraWhatsApp(String(r.msg.content ?? "")), consultas, modelo, uso, semResposta };
    }
    messages.push({ role: "assistant", content: r.msg.content ?? "", tool_calls: chamadas });
    for (const tc of chamadas) {
      let args: any = {};
      try { args = JSON.parse(tc.function?.arguments || "{}"); } catch { /* argumento inválido */ }
      if (tc.function?.name === "sem_resposta") {
        semResposta.push(String(args.motivo ?? "sem motivo"));
        messages.push({ role: "tool", tool_call_id: tc.id, content: `Ok, ${avisar} vai ser avisado. Agora responda à pessoa.` });
        continue;
      }
      const { conteudo, reg } = tc.function?.name === "buscar_portal"
        ? await buscarPortal(String(args.busca ?? ""), completo)
        : await consultar(String(args.sql ?? ""), completo);
      consultas.push(reg);
      messages.push({ role: "tool", tool_call_id: tc.id, content: conteudo });
    }
  }
  return {
    texto: "Não consegui fechar essa resposta. Tenta perguntar de um jeito mais específico (período, unidade ou pessoa)?",
    consultas, modelo, uso, semResposta: [...semResposta, "não fechou a resposta em " + MAX_PASSOS + " passos"],
  };
}

// ── entrega: texto + fotos (linhas "Nome: <link do avatar>" viram imagem) ────
async function entregar(destino: string, texto: string, citarId: string | null, meta: Record<string, unknown>) {
  let enviados: string[] = [];
  const { texto: textoSemFotos, fotos } = separarFotos(texto);
  try {
    if (textoSemFotos) enviados = await enviar(destino, textoSemFotos, citarId);
    const semImagem: Foto[] = [];
    for (const f of fotos) {
      try {
        const id = await enviarImagem(destino, f);
        if (id) enviados.push(id);
      } catch (err) {
        semImagem.push(f);
        meta.erro_imagem = erroTxt(err);
      }
    }
    // imagem falhou → manda o link como texto
    if (semImagem.length) {
      enviados.push(...await enviar(destino, semImagem.map((f) => `${f.legenda}: ${f.url}`).join("\n"), null));
    }
    if (fotos.length) meta.fotos = fotos.length;
  } catch (err) {
    meta.erro_envio = erroTxt(err);
  }
  return { enviados, textoSemFotos };
}

// ── avisos ao responsável (perguntas sem resposta) ──────────────────────────
// destino = para onde vai a resposta (número/LID no privado, id do grupo); registrado = já pode falar com o Sam
type Aviso = {
  de: string; onde: string; pergunta: string; motivo: string; resposta?: string;
  destino: string; tipo: "privado" | "grupo"; perguntaMsgId: string | null; nivel: string;
  registrado: boolean; nomeCurto: string; grupoNome?: string; naoLiberado?: boolean;
};

// manda o aviso (com número #id e os comandos) no privado do responsável e grava na conversa dele
// limite: origem → no máximo 10 avisos por hora (número desconhecido ou grupo não liberado)
async function avisarResponsavel(a: Aviso, limitarOrigem?: string) {
  const { responsavel } = await parametros();
  if (!responsavel.telefone) return;
  if (limitarOrigem) {
    const { data: ok } = await supa.rpc("agente_encaminhar_ok", { p_origem: limitarOrigem });
    if (ok === false) return;
  }
  const { data: id, error } = await supa.rpc("agente_aviso_criar", {
    p_responsavel: responsavel.telefone,
    p_meta: {
      motivo: a.motivo, de: a.de, onde: a.onde, pergunta: a.pergunta, destino: a.destino, tipo: a.tipo,
      pergunta_msg_id: a.perguntaMsgId, nivel: a.nivel, registrado: a.registrado, nome_curto: a.nomeCurto,
      grupo_nome: a.grupoNome ?? null, nao_liberado: a.naoLiberado === true,
    },
  });
  if (error) throw new Error("aviso: " + error.message);
  const linhas = [
    `🔔 *Sam — pergunta sem resposta* (#${id})`,
    `*De:* ${a.de} · ${a.onde}`,
    `*Pergunta:* ${a.pergunta}`,
    `*Motivo:* ${a.motivo}`,
  ];
  if (a.resposta) linhas.push(`*Sam respondeu:* ${a.resposta.length > 600 ? a.resposta.slice(0, 600) + "…" : a.resposta}`);
  linhas.push(
    "",
    `↩️ *responde ${id}* · ${a.registrado ? "" : `*libera ${id}* · `}*${id}: sua resposta* · *ignora ${id}*`,
  );
  const texto = linhas.join("\n");
  const ids = await enviar(responsavel.telefone, texto, null);
  await supa.rpc("agente_aviso_enviado", { p_id: id, p_texto: texto, p_msg_id: ids[0] ?? null });
}

// ── comandos do responsável (no privado dele com o Sam) ─────────────────────
//   responde 27 · libera 27 · 27: texto · ignora 27   (sem número = último aviso aberto; ou respondendo ao aviso)
const CMD_RE = /^\s*(responde|responder|libera|liberar|ignora|ignorar)\s*#?(\d+)?\s*[.!]?\s*$/i;
const MANUAL_RE = /^\s*#?(\d+)\s*:\s*([\s\S]+)$/;

// ensinar o Sam (vale em todas as conversas, sempre nas instruções):
//   aprende: <texto> · esquece 12 · atualiza portal (relê o Portal Líderes agora)
const APRENDE_RE = /^\s*(?:sam[,:]?\s*)?aprend[ae](?:\s*[:\-–]\s*|\s+)([\s\S]{3,})$/i;
const ESQUECE_RE = /^\s*(?:sam[,:]?\s*)?esquecer?\s*#?(\d+)\s*[.!]?\s*$/i;
const ATUALIZA_RE = /^\s*(?:sam[,:]?\s*)?atualiz[ae]r?\s+(?:o\s+)?portal\s*[.!]?\s*$/i;

async function comandoSaber(e: Entrada, responsavel: { telefone: string; nome?: string }): Promise<boolean> {
  const aprende = e.texto.match(APRENDE_RE);
  const esquece = aprende ? null : e.texto.match(ESQUECE_RE);
  const atualiza = aprende || esquece ? null : ATUALIZA_RE.test(e.texto);
  if (!aprende && !esquece && !atualiza) return false;
  const tel = responsavel.telefone;
  const dizer = async (t: string, meta: Record<string, unknown>) => {
    const ids = await enviar(tel, t, null);
    await supa.rpc("agente_registrar", { p_telefone: tel, p_papel: "assistant", p_texto: t, p_msg_id: ids[0] ?? null, p_meta: meta });
  };
  const trabalho = (async () => {
    if (aprende) {
      const texto = aprende[1].trim().replace(/^que\s+/i, "");
      const { data: id, error } = await supa.rpc("agente_aprender", { p_texto: texto, p_autor: responsavel.nome ?? null });
      if (error) throw new Error(error.message);
      esquecerSaberes();
      await dizer(`📚 Aprendi (#${id}): ${texto}\nVale a partir de agora, em todas as conversas. Para apagar: *esquece ${id}*`,
        { comando: "aprende", conhecimento_id: id });
    } else if (esquece) {
      const { data, error } = await supa.rpc("agente_esquecer", { p_id: Number(esquece[1]) });
      if (error) throw new Error(error.message);
      esquecerSaberes();
      await dizer((data as any)?.ok
        ? `🗑️ Esqueci o #${esquece[1]}: ${(data as any).texto}`
        : `Não achei o #${esquece[1]} entre o que você me ensinou.`, { comando: "esquece", conhecimento_id: Number(esquece[1]) });
    } else {
      await enviar(tel, "🔄 Lendo o Portal Líderes de novo… te aviso quando terminar.", null);
      const k = await segredo("portal_secret");
      const r = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/agente-portal?k=${encodeURIComponent(k)}`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: "{}", signal: AbortSignal.timeout(140_000),
      });
      const out = await r.json().catch(() => ({})) as any;
      if (!r.ok || !out?.ok) throw new Error(out?.erro ?? `HTTP ${r.status}`);
      const s = out.resumo ?? {};
      esquecerSaberes();
      await dizer(out.continua
        ? `🔄 Portal: ${s.processadas ?? 0} de ${s.paginas ?? "?"} páginas lidas; o resto termina em seguida.`
        : `✅ Portal atualizado: ${s.processadas ?? 0} páginas (${s.pedacos ?? 0} trechos), ${s.documentos ?? 0} trechos de documentos ` +
          `e ${s.arquivos ?? 0} arquivos.${s.erros?.length ? `\n⚠️ ${s.erros.length} com erro: ${s.erros.slice(0, 3).join("; ")}` : ""}`,
        { comando: "atualiza_portal", resumo: s });
    }
  })();
  EdgeRuntime.waitUntil(trabalho.catch((err) => enviar(tel, `Não consegui: ${erroTxt(err).slice(0, 200)}`, null)));
  return true;
}

async function comandoResponsavel(e: Entrada, responsavel: { telefone: string; nome?: string }): Promise<boolean> {
  if (await comandoSaber(e, responsavel)) return true;
  const cmd = e.texto.match(CMD_RE);
  const manual = cmd ? null : e.texto.match(MANUAL_RE);
  if (!cmd && !manual) return false;
  const num = cmd ? cmd[2] : manual![1];
  const { data: av } = await supa.rpc("agente_aviso", {
    p_id: num ? Number(num) : null, p_msg_id: num ? null : e.citadoId,
  });
  if (!av || (av as any).responsavel !== responsavel.telefone) {
    if (manual) return false; // "10: …" sem aviso 10 → é pergunta normal
    await enviar(responsavel.telefone, num ? `Não achei o aviso #${num}.` : "Não achei aviso aberto nas últimas 24h.", null);
    return true;
  }
  const a = av as any;
  const verbo = cmd ? cmd[1].toLowerCase().slice(0, 4) : "manual"; // resp | libe | igno | manual
  EdgeRuntime.waitUntil(executarComando(verbo, a, manual ? manual[2].trim() : "", responsavel.telefone)
    .catch((err) => enviar(responsavel.telefone, `Não consegui executar no aviso #${a.id}: ${erroTxt(err).slice(0, 200)}`, null)));
  return true;
}

async function executarComando(verbo: string, a: any, textoManual: string, responsavelTel: string) {
  const confirmar = async (t: string) => {
    const ids = await enviar(responsavelTel, t, null);
    await supa.rpc("agente_registrar", {
      p_telefone: responsavelTel, p_papel: "assistant", p_texto: t, p_msg_id: ids[0] ?? null, p_meta: { comando: verbo, aviso_id: a.id },
    });
  };
  const citar = a.tipo === "grupo" ? a.pergunta_msg_id : null;

  if (verbo === "igno") {
    await supa.rpc("agente_aviso_marcar", { p_id: a.id, p_status: "ignorado" });
    return confirmar(`👍 Aviso #${a.id} encerrado, sem resposta.`);
  }

  if (verbo === "manual") {
    const meta: Record<string, unknown> = { manual: true, aviso_id: a.id };
    const { enviados } = await entregar(a.destino, textoManual, citar, meta);
    await supa.rpc("agente_registrar", { p_telefone: a.destino, p_papel: "assistant", p_texto: textoManual, p_msg_id: enviados[0] ?? null, p_meta: meta });
    await supa.rpc("agente_aviso_marcar", { p_id: a.id, p_status: "respondido_manual" });
    return confirmar(meta.erro_envio ? `⚠️ Não consegui mandar para ${a.de}: ${meta.erro_envio}` : `✅ Mandei sua resposta para ${a.de}.`);
  }

  let liberado = "";
  if (verbo === "libe") {
    if (a.registrado) {
      liberado = "já estava liberado; ";
    } else {
      const { data: l } = await supa.rpc("agente_liberar", {
        p_tipo: a.tipo, p_alvo: a.destino, p_nome: a.tipo === "grupo" ? (a.grupo_nome ?? "") : (a.de ?? "").split(" (")[0], p_nivel: "basico",
      });
      if (!(l as any)?.ok) return confirmar(`⚠️ Não consegui liberar #${a.id}: ${(l as any)?.erro ?? "erro"}.`);
      const nivel = (l as any)?.nivel === "completo" ? "completo" : "básico";
      liberado = a.tipo === "grupo" ? `grupo liberado (nível ${nivel}) e ` : `número liberado (nível ${nivel}) e `;
    }
  }
  // liberado agora = pelo comando, ou já estava/foi liberado depois que o aviso chegou (vale o nível de hoje)
  const atual = await situacaoAtual(a);
  const liberadoAgora = verbo === "libe" || a.registrado === true || atual.liberado;

  // responde: a IA responde a pergunta original para a pessoa/grupo (sem novo aviso)
  const local: Local = a.tipo === "grupo" ? { grupo: a.grupo_nome ?? "" } : { privadoCom: a.nome_curto ?? "" };
  const r = await responder(local, [{ papel: "user", texto: a.pergunta, autor: a.nome_curto }], (atual.nivel ?? a.nivel) === "completo", "");
  const meta: Record<string, unknown> = { consultas: r.consultas, modelo: r.modelo, tokens: r.uso, aviso_id: a.id };
  await supa.rpc("agente_registrar", {
    p_telefone: a.destino, p_papel: "user", p_texto: a.pergunta, p_msg_id: null, p_meta: { autor_nome: a.nome_curto, aviso_id: a.id },
  });
  const textoFinal = (await introNaoLiberado(a, liberadoAgora)) + r.texto;
  const { enviados, textoSemFotos } = await entregar(a.destino, textoFinal, citar, meta);
  await supa.rpc("agente_registrar", { p_telefone: a.destino, p_papel: "assistant", p_texto: textoFinal, p_msg_id: enviados[0] ?? null, p_meta: meta });
  await supa.rpc("agente_aviso_marcar", { p_id: a.id, p_status: verbo === "libe" ? "liberado" : "respondido" });
  if (meta.erro_envio) return confirmar(`⚠️ ${liberado}não consegui mandar a resposta para ${a.de}: ${meta.erro_envio}`);
  const previa = textoSemFotos.length > 300 ? textoSemFotos.slice(0, 300) + "…" : textoSemFotos;
  return confirmar(`✅ ${liberado}respondi ${a.de.split(" (")[0]}${meta.fotos ? ` (+${meta.fotos} foto${Number(meta.fotos) > 1 ? "s" : ""})` : ""}:\n${previa}`);
}

// o número/grupo do aviso já pode falar com o Sam hoje, e com que nível? (pode ter sido liberado depois do aviso)
async function situacaoAtual(a: any): Promise<{ liberado: boolean; nivel: string | null }> {
  if (a.tipo === "grupo") {
    const { data: g } = await supa.rpc("agente_grupo", { p_chat_id: a.destino, p_nome: a.grupo_nome ?? null });
    return { liberado: (g as any)?.ativo === true, nivel: (g as any)?.ativo ? (g as any)?.nivel ?? null : null };
  }
  const { data: u } = await supa.rpc("agente_usuario", { p_telefone: a.destino });
  return { liberado: !!u, nivel: (u as any)?.nivel ?? null };
}

// quando a pergunta chegou de quem não estava liberado, a resposta começa explicando (e dizendo que já foi liberado)
async function introNaoLiberado(a: any, liberadoAgora: boolean): Promise<string> {
  // aviso antigo (sem a marcação nao_liberado): decide pelo motivo
  const naoLiberado = a.registrado === false || a.nao_liberado === true ||
    (a.nao_liberado === undefined && /liberad/i.test(a.motivo ?? ""));
  if (!naoLiberado) return "";
  const resp = (await parametros()).responsavel.nome;
  const grupo = a.tipo === "grupo";
  const saudacao = grupo ? "Oi, pessoal!" : `Oi, ${a.nome_curto || "tudo bem"}!`;
  const quem = grupo ? "Este grupo" : "Seu número";
  const sobre = grupo ? `a pergunta de ${a.nome_curto}` : "a sua pergunta";
  return liberadoAgora
    ? `${saudacao} ${quem} ainda não estava liberado para falar comigo quando a mensagem chegou. Reportei para o ${resp} e ele já liberou o acesso. Agora, sobre ${sobre}:\n\n`
    : `${saudacao} ${quem} não está liberado para falar comigo, mas o ${resp} pediu para eu responder ${sobre}:\n\n`;
}

// quem mandou: nome do cadastro de colaboradores pelo número, senão o nome do WhatsApp
async function descreverRemetente(e: Entrada): Promise<string> {
  const num = [e.autorId, e.chatId].map(soDigitos).find((d) => d.length >= 10 && d.length <= 13) ?? "";
  if (num) {
    const { data: p } = await supa.rpc("agente_quem", { p_id: num });
    if (p) return `${(p as any).nome} (${(p as any).cargo} · ${(p as any).unidade}${(p as any).status !== "Ativo" ? " · " + (p as any).status : ""}) +${num}`;
  }
  const id = num ? "+" + num : "id " + soDigitos(e.autorId || e.chatId);
  return `${e.autorNome || "sem nome"} (${id})`;
}

// ── processamento de uma pergunta ───────────────────────────────────────────
// conversa = chave do histórico e destino da resposta (id do grupo, ou o número cadastrado no privado)
// de = quem perguntou (p/ o aviso); avisar = nome do responsável ("" se quem pergunta é ele)
type Conversa = {
  chave: string; local: Local; autorNome: string; completo: boolean; citar: boolean; de: string; avisar: string;
};

async function processar(e: Entrada, pergunta: string, cv: Conversa) {
  const autor = { autor_id: e.autorId, autor_nome: cv.autorNome };
  const completo = cv.completo;
  const { data: reg, error: eReg } = await supa.rpc("agente_registrar", {
    p_telefone: cv.chave, p_papel: "user", p_texto: pergunta, p_msg_id: e.msgId, p_meta: autor,
  });
  if (eReg) throw new Error("registrar: " + eReg.message);
  if ((reg as any)?.duplicado) return; // webhook reenviado

  let texto: string;
  let meta: Record<string, unknown> = {};
  let motivosAviso: string[] = [];
  try {
    const { data: hist } = await supa.rpc("agente_historico", { p_telefone: cv.chave });
    const hist0 = [{ papel: "user", texto: pergunta, autor: autor.autor_nome }];
    const r = await responder(cv.local, (hist as Fala[]) ?? hist0, completo, cv.avisar);
    texto = r.texto || "Não encontrei uma resposta para isso.";
    motivosAviso = r.semResposta;
    meta = { consultas: r.consultas, modelo: r.modelo, tokens: r.uso, pergunta_id: e.msgId, nivel: completo ? "completo" : "basico" };
    if (motivosAviso.length) meta.sem_resposta = motivosAviso;
  } catch (err) {
    texto = "Tive um problema para consultar agora. Tenta de novo em alguns minutos?";
    meta = { erro: erroTxt(err), pergunta_id: e.msgId };
    motivosAviso = ["erro: " + erroTxt(err).slice(0, 150)];
  }

  const { enviados, textoSemFotos } = await entregar(cv.chave, texto, cv.citar ? e.msgId : null, meta);
  // msg_id = id da resposta enviada → reconhece reply ao Sam
  await supa.rpc("agente_registrar", {
    p_telefone: cv.chave, p_papel: "assistant", p_texto: texto, p_msg_id: enviados[0] ?? null,
    p_meta: { ...meta, enviados },
  });

  if (motivosAviso.length && cv.avisar) {
    const grupo = "grupo" in cv.local;
    await avisarResponsavel({
      de: cv.de, onde: grupo ? `grupo ${(cv.local as { grupo: string }).grupo}` : "privado", pergunta,
      motivo: motivosAviso.join("; "), resposta: textoSemFotos,
      destino: cv.chave, tipo: grupo ? "grupo" : "privado", perguntaMsgId: e.msgId,
      nivel: completo ? "completo" : "basico", registrado: true, nomeCurto: cv.autorNome,
      grupoNome: grupo ? (cv.local as { grupo: string }).grupo : undefined,
    });
  }
}

// privado: a pessoa está cadastrada? (procura pelo número e pelo id anônimo do WhatsApp)
async function usuarioCadastrado(e: Entrada): Promise<{ telefone: string; nome: string; nivel: string } | null> {
  const ids = [...new Set([e.autorId, e.chatId].map(soDigitos).filter((d) => d.length >= 10))];
  for (const id of ids) {
    const { data } = await supa.rpc("agente_usuario", { p_telefone: id });
    if (data) return data as any;
  }
  return null;
}

const falha = (chave: string) => (err: unknown) =>
  supa.rpc("agente_ignorado", { p_motivo: "falha:" + erroTxt(err).slice(0, 200), p_telefone: chave });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ ok: true });
  const url = new URL(req.url);
  const payload = await req.json().catch(() => null);

  // modo teste: responde no corpo, não envia nem grava
  if (url.searchParams.has("teste")) {
    const t = await segredo("teste_secret");
    if (!t || url.searchParams.get("teste") !== t) return json({ ok: false, erro: "nao_autorizado" }, 401);
    // ?aviso=1: cria um aviso manualmente (ex.: pergunta que chegou antes de existir o aviso) — este envia ao responsável
    if (url.searchParams.get("aviso") === "1") {
      try {
        await avisarResponsavel(payload as Aviso);
        return json({ ok: true });
      } catch (err) {
        return json({ ok: false, erro: erroTxt(err) }, 500);
      }
    }
    try {
      const autor = String(payload?.nome ?? "Teste");
      const fala = [{ papel: "user", texto: String(payload?.texto ?? ""), autor }];
      const local: Local = payload?.privado === true ? { privadoCom: autor } : { grupo: String(payload?.grupo ?? "Teste") };
      const r = await responder(local, fala, payload?.completo === true, (await parametros()).responsavel.nome);
      return json({ ok: true, ...r, ...separarFotos(r.texto) });
    } catch (err) {
      return json({ ok: false, erro: erroTxt(err) }, 500);
    }
  }

  // modo reunião (chamado pela edge agente-reuniao, senha interna): resposta para ser falada na sala
  if (url.searchParams.has("reuniao")) {
    const s = await segredo("portal_secret");
    if (!s || url.searchParams.get("reuniao") !== s) return json({ ok: false, erro: "nao_autorizado" }, 401);
    try {
      const contexto = String(payload?.contexto ?? "").slice(-12_000);
      const texto = (contexto ? `Transcrição recente da reunião (automática, pode ter erros):\n${contexto}\n\n` : "") +
        `Pergunta feita agora ao Sam: ${String(payload?.texto ?? "")}`;
      const r = await responder({ reuniao: String(payload?.titulo ?? "Reunião de RH") },
        [{ papel: "user", texto, autor: String(payload?.nome ?? "") || null }], true, "");
      return json({ ok: true, texto: r.texto, consultas: r.consultas, modelo: r.modelo, uso: r.uso });
    } catch (err) {
      return json({ ok: false, erro: erroTxt(err) }, 500);
    }
  }

  const k = await segredo("webhook_secret");
  if (!k || url.searchParams.get("k") !== k) return json({ ok: false, erro: "nao_autorizado" }, 401);

  const lido = lerWebhook(payload);
  if (!lido.ok) return json({ ok: true, ignorado: lido.motivo });
  const e = lido.e;
  const { botIds, responsavel } = await parametros();

  // privado: só quem está cadastrado; não precisa chamar o Sam (a conversa já é com ele)
  if (!e.grupo) {
    const u = await usuarioCadastrado(e);
    if (!u) {
      // não cadastrado: não responde; avisa o responsável (até 10/h por remetente)
      const origem = soDigitos(e.autorId || e.chatId);
      const tel = [e.autorId, e.chatId].map(soDigitos).find((d) => /^55\d{10,11}$/.test(d));
      EdgeRuntime.waitUntil(
        descreverRemetente(e)
          .then((de) =>
            avisarResponsavel({
              de, onde: "privado", pergunta: e.texto, motivo: "número não cadastrado — o Sam não respondeu",
              destino: tel ?? e.chatId, tipo: "privado", perguntaMsgId: e.msgId, nivel: "basico", registrado: false, naoLiberado: true,
              nomeCurto: (de.split(" (")[0] || e.autorNome).split(" ")[0],
            }, origem)
          )
          .catch(falha(origem)),
      );
      return json({ ok: true, ignorado: "privado_nao_cadastrado" });
    }
    // o responsável pode dar comandos sobre os avisos (responde/libera/ignora/"27: texto")
    if (u.telefone === responsavel.telefone && await comandoResponsavel(e, responsavel)) {
      return json({ ok: true, comando: true });
    }
    const primeiro = u.nome.split(" ")[0] || u.nome;
    const pergunta = (await chamado(e, botIds)) ?? e.texto;
    const cv: Conversa = {
      chave: u.telefone, local: { privadoCom: primeiro }, autorNome: primeiro,
      completo: u.nivel === "completo", citar: false, de: u.nome,
      avisar: u.telefone === responsavel.telefone ? "" : responsavel.nome,
    };
    EdgeRuntime.waitUntil(processar(e, pergunta, cv).catch(falha(u.telefone)));
    return json({ ok: true });
  }

  const pergunta = await chamado(e, botIds);
  if (!pergunta) return json({ ok: true, ignorado: "nao_chamado" }); // conversa normal do grupo: nada é gravado

  const { data: g, error: eG } = await supa.rpc("agente_grupo", { p_chat_id: e.chatId, p_nome: e.grupoNome });
  if (eG) return json({ ok: false, erro: eG.message }, 500);
  if (!(g as any)?.ativo) {
    // grupo não liberado: não responde; guarda o payload e avisa o responsável (até 10/h por grupo)
    await supa.rpc("agente_ignorado", { p_motivo: "grupo_pendente", p_telefone: e.chatId, p_payload: payload });
    EdgeRuntime.waitUntil(
      descreverRemetente(e)
        .then((de) =>
          avisarResponsavel({
            de, onde: `grupo ${(g as any)?.nome || e.grupoNome || e.chatId}`, pergunta,
            motivo: "grupo não liberado para o Sam — ele não respondeu",
            destino: e.chatId, tipo: "grupo", perguntaMsgId: e.msgId, nivel: (g as any)?.nivel ?? "basico",
            registrado: false, naoLiberado: true, nomeCurto: (e.autorNome || de).split(" ")[0], grupoNome: (g as any)?.nome || e.grupoNome,
          }, e.chatId)
        )
        .catch(falha(e.chatId)),
    );
    return json({ ok: true, ignorado: "grupo_pendente" });
  }

  // quem perguntou no grupo (p/ o aviso; se for o próprio responsável, não avisa)
  const u = await usuarioCadastrado({ ...e, chatId: "" });
  const de = u ? u.nome : await descreverRemetente({ ...e, chatId: "" });

  // responde já ao webhook e processa em segundo plano (a IA pode levar ~10–40s)
  const cv: Conversa = {
    chave: e.chatId, local: { grupo: (g as any)?.nome || e.grupoNome },
    autorNome: e.autorNome.split(" ")[0] || e.autorNome, completo: (g as any)?.nivel === "completo", citar: true,
    de, avisar: u?.telefone === responsavel.telefone ? "" : responsavel.nome,
  };
  EdgeRuntime.waitUntil(processar(e, pergunta, cv).catch(falha(e.chatId)));
  return json({ ok: true });
});
