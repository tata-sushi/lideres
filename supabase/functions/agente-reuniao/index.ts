// agente-reuniao — Sam no modo reunião (reunião de RH presencial).
//
// A página compliance/kpis/rh/sam.html (dentro do app Tatá Plus) ouve pelo microfone e manda
// trechos de áudio cortados nas pausas. Aqui:
//   iniciar   → abre a reunião (dp_rh.agente_reunioes); sem saudação (a página só apita)
//   teste_mic → (antes de começar) transcreve 5 s de fala para o líder conferir o microfone
//   trecho    → transcreve (OpenRouter) e guarda; avisa se chamaram "Sam, …"
//               cada trecho fica registrado em dp_rh.agente_reuniao_trechos (tamanho, nível do
//               microfone, resultado); com agente_config reuniao_diag_audio = '1', o áudio dos que
//               não viraram texto fica guardado 3 dias para diagnóstico
//   perguntar → o Sam de sempre (edge agente-whatsapp ?reuniao=) responde com o contexto dos
//               últimos minutos; a resposta volta em texto e em voz (OpenRouter)
//   encerrar  → fecha e gera em segundo plano (Claude) a ata no formato das atas de RH, o resumo e o
//               encerramento falado; ata, resumo e transcrição vão para dp_rh.alinhamento_transcricao
//               (a tabela das atas de RH) e só o resumo vai para o WhatsApp (agente_config
//               reuniao_grupo_resumo: o grupo DP/RH, ou o responsável durante os testes); cada
//               pendência vira card em "Pendentes" no kanban (agente_config reuniao_quadro), com
//               etiqueta do quadro e responsável quando ficou claro na reunião (reuniao_responsaveis)
//   gravacao  → pedaço de 1 min da gravação contínua (μ-law 8 kHz) → storage agente-reuniao; no fim
//               a reunião é separada por vozes e as vozes cadastradas viram nomes (vozes.ts)
//   rodada_audio → o Sam pedindo a rodada de nomes (cadastro das vozes, com consentimento)
//   (11/11) O Sam não fala sozinho: ao começar, a página só dá um apito. Ele fala quando chamado
//   ("Sam, …"); "Sam, se apresente" = apresentação + rodada de nomes (resposta com rodada: true).
//   status    → situação da reunião (a página consulta até a ata ficar pronta)
//   fala_final→ o Sam fala o encerramento na sala (assuntos, decisões, pendências)
//   varrer    → (pg_cron, ?k=<portal_secret>) encerra reuniões abandonadas há 20 min
//
// Acesso: token do usuário (o mesmo que o portal recebe do Plus) + página
// governanca-kpis-rh-sam liberada para ele (tata_plus.gov_meus_acessos). Só quem abriu a
// reunião mexe nela. verify_jwt = false porque a conferência é feita aqui (e o pg_cron chama
// "varrer" com a senha interna).
// Áudio e IA pelo OpenRouter, com a mesma chave do Sam (LLM_API_KEY): transcrição em
// /audio/transcriptions (padrão openai/gpt-transcribe) e voz em /audio/speech (padrão
// microsoft/mai-voice-2.1-flash, voz brasileira pt-BR-Rafael). Modelos e voz em dp_rh.agente_config:
// reuniao_modelo_transcricao, reuniao_modelo_voz, reuniao_voz.
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  blocosDeAudio, cadastroDaRodada, comPrefixo, deBase64, falasDoBloco, juntar, type Linha, nomesDasVozes, type Parte, separar,
  TAXA, type Voz,
} from "./vozes.ts";

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const LLM_URL = Deno.env.get("LLM_API_URL") || "https://openrouter.ai/api/v1/chat/completions";
const LLM_KEY = Deno.env.get("LLM_API_KEY") ?? "";
const AUDIO_BASE = LLM_URL.replace(/\/chat\/completions\/?$/, ""); // https://openrouter.ai/api/v1
const MODELOS_ATA = [...new Set([Deno.env.get("AGENTE_LLM_MODEL") || "anthropic/claude-sonnet-5.5", "anthropic/claude-sonnet-5.5", "anthropic/claude-sonnet-5"])];
const UAZ_BASE = (Deno.env.get("SAM_UAZAPI_URL") || "https://tatasushi.uazapi.com").replace(/\/+$/, "");
const PAGINA = "governanca-kpis-rh-sam";
const ORIGENS = ["https://lideres.tatasushi.tech", "https://plus.tatasushi.tech"];
const BUCKET = "agente-reuniao"; // gravação contínua (apagada depois da ata)
// textos falados (agente_config reuniao_texto_rodada / reuniao_texto_apresentacao sobrepõem, sem publicar)
// botão "Rodada de nomes": alguém novo na sala
const RODADA_TEXTO = "Quem ainda não se apresentou: diga, uma vez só, aqui é o, ou aqui é a, o seu nome e uma frase " +
  "sobre o que faz. Depois disso, eu reconheço a sua voz sozinho nas próximas reuniões. Quem falar concorda que eu " +
  "guarde um trecho da sua voz só para isso; dá para pedir para apagar quando quiser.";

// "Sam, se apresente": quem ele é, o que faz na reunião e o pedido da rodada de nomes
const APRESENTACAO_TEXTO = "Olá, pessoal! Eu sou o Sam, o assistente virtual do RH do TATÁ. Eu acompanho a reunião e, " +
  "no final, faço a ata, mando o resumo no grupo do DP e RH e coloco as demandas no kanban, cada uma com o seu " +
  "responsável. Se precisarem de alguma informação do RH, é só dizer: Sam, e a pergunta. Agora, para eu aprender a " +
  "voz de vocês, peço que cada um se apresente, um de cada vez: diga aqui é o, ou aqui é a, o seu nome e uma frase " +
  "sobre o que faz. É só desta vez: depois disso, eu reconheço vocês sozinho em todas as reuniões. Quem falar " +
  "concorda que eu guarde um trecho da sua voz só para isso; dá para pedir para apagar quando quiser. Pode começar " +
  "quem quiser.";
const semAcento = (t: string) =>
  t.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
// "se apresente", "apresente-se", "pode se apresentar", "faz a sua apresentação"…
const APRESENTE_RE =
  /^(?:(?:por favor|pode|poderia|voce pode|voce poderia|agora)\s+)*(?:se\s+apresent(?:e|a|ar)\b|apresent[ea]\s+se\b|apresent[ea]\s+(?:voce|vc)\b|fa[cz]\w*\s+(?:a\s+|uma\s+|sua\s+)*apresentacao)/;

const supa = createClient(SUPA_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
  db: { schema: "tata_plus" },
});

const erroTxt = (err: unknown) => String((err as Error)?.message ?? err);

function cors(req: Request): Record<string, string> {
  const o = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ORIGENS.includes(o) ? o : ORIGENS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

// ── configuração ────────────────────────────────────────────────────────────
let cfg: {
  transcricao: string; voz: string; modeloVoz: string; modeloVozes: string; participantes: string[];
  responsavel: string; grupo: string; diag: boolean; textoRodada: string; textoApresentacao: string; em: number;
} | null = null;
async function config() {
  if (!cfg || Date.now() - cfg.em > 60_000) {
    const { data } = await supa.rpc("agente_parametros");
    const d = (data ?? {}) as Record<string, string>;
    cfg = {
      transcricao: d.reuniao_modelo_transcricao || "openai/gpt-transcribe",
      modeloVoz: d.reuniao_modelo_voz || "microsoft/mai-voice-2.1-flash",
      voz: d.reuniao_voz || "pt-BR-Rafael:MAI-Voice-2.1-Flash",
      responsavel: String(d.responsavel_telefone ?? "").replace(/\D/g, ""),
      grupo: String(d.reuniao_grupo_resumo ?? ""),
      diag: String(d.reuniao_diag_audio ?? "") === "1",
      modeloVozes: d.reuniao_modelo_vozes || "elevenlabs/scribe-v2",
      participantes: (() => { try { return (JSON.parse(d.reuniao_participantes || "[]") as unknown[]).map(String); } catch { return []; } })(),
      textoRodada: String(d.reuniao_texto_rodada ?? "").trim() || RODADA_TEXTO,
      textoApresentacao: String(d.reuniao_texto_apresentacao ?? "").trim() || APRESENTACAO_TEXTO,
      em: Date.now(),
    };
  }
  return cfg;
}
const segredos: Record<string, string> = {};
async function segredo(chave: string): Promise<string> {
  if (segredos[chave] === undefined) {
    const { data } = await supa.rpc("agente_segredo", { p_chave: chave });
    segredos[chave] = String(data ?? "");
  }
  return segredos[chave];
}

// ── quem está pedindo (token do portal) ─────────────────────────────────────
type Usuario = { matricula: string; nome: string };
const usuarios = new Map<string, { u: Usuario | null; em: number }>();

async function usuarioDe(req: Request): Promise<Usuario | null> {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token || token === ANON) return null;
  const c = usuarios.get(token);
  if (c && Date.now() - c.em < 300_000) return c.u;
  const cli = createClient(SUPA_URL, ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
    db: { schema: "tata_plus" },
  });
  const [{ data: acessos, error }, { data: mat }] = await Promise.all([
    cli.rpc("gov_meus_acessos"),
    cli.rpc("minha_matricula"),
  ]);
  let u: Usuario | null = null;
  if (!error && ((acessos ?? []) as any[]).some((a) => a.pagina_id === PAGINA)) {
    const matricula = String(mat ?? "");
    const { data: q } = matricula ? await supa.rpc("agente_quem_matricula", { p_matricula: matricula }) : { data: null };
    u = { matricula, nome: String((q as any)?.nome ?? "") };
  }
  usuarios.set(token, { u, em: Date.now() });
  return u;
}

// a reunião é de quem abriu e ainda está aberta?
async function minhaReuniao(id: string, u: Usuario): Promise<any> {
  if (!/^[0-9a-f-]{36}$/i.test(id)) throw new Error("reunião inválida");
  const { data, error } = await supa.rpc("agente_reuniao_ver", { p_id: id });
  if (error) throw new Error(error.message);
  if (!data) throw new Error("reunião não encontrada");
  if ((data as any).iniciada_por !== u.matricula) throw new Error("esta reunião foi aberta por outra pessoa");
  return data;
}

// ── áudio (OpenRouter): transcrição e voz ───────────────────────────────────
const ALUCINACAO = /amara\.org|legendas? (pela|por)|inscreva-se|obrigad[oa] por assistir|^\W*(obrigad[oa]|tchau)\W*$/i;

// formato do áudio para a API (o navegador manda webm/opus; o iPhone, mp4/aac)
function formatoDe(audio: File): string {
  const t = `${audio.type} ${audio.name}`.toLowerCase();
  if (t.includes("webm")) return "webm";
  if (t.includes("ogg")) return "ogg";
  if (t.includes("mp4") || t.includes("m4a") || t.includes("aac")) return "m4a";
  if (t.includes("mpeg") || t.includes("mp3")) return "mp3";
  if (t.includes("wav")) return "wav";
  return "webm";
}

const VOCABULARIO = "Reunião de RH do TATÁ Sushi, em português do Brasil. O assistente virtual se chama Sam: \"Sam, quantas vagas…\".";

type Transcricao = { texto: string; resultado: "ok" | "vazio" | "alucinacao" | "erro"; modelo: string; bruto: string };

// transcreve um trecho; se o primeiro modelo devolver texto vazio, tenta o próximo
// (outro reconhecedor às vezes pega o que o primeiro perdeu)
async function transcrever(audio: File): Promise<Transcricao> {
  if (!LLM_KEY) throw new Error("sem chave do OpenRouter (LLM_API_KEY)");
  const { transcricao } = await config();
  const dados = base64(new Uint8Array(await audio.arrayBuffer()));
  const modelos = [...new Set([transcricao, "openai/gpt-transcribe", "openai/whisper-large-v3-turbo"])];
  let ultimo = "";
  let semTexto: Transcricao | null = null;
  for (const modelo of modelos) {
    const r = await fetch(`${AUDIO_BASE}/audio/transcriptions`, {
      method: "POST",
      headers: { Authorization: `Bearer ${LLM_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: modelo,
        input_audio: { data: dados, format: formatoDe(audio) },
        language: "pt",
        temperature: 0,
        provider: { options: { openai: { prompt: VOCABULARIO }, groq: { prompt: VOCABULARIO } } },
      }),
      signal: AbortSignal.timeout(60_000),
    });
    const txt = await r.text();
    if (r.ok) {
      let bruto = "";
      try { bruto = String(JSON.parse(txt)?.text ?? ""); } catch { bruto = ""; }
      bruto = bruto.replace(/\s+/g, " ").trim();
      const alucinacao = !!bruto && ALUCINACAO.test(bruto) && bruto.length < 80;
      if (bruto && !alucinacao) return { texto: bruto, resultado: "ok", modelo, bruto };
      semTexto ??= { texto: "", resultado: alucinacao ? "alucinacao" : "vazio", modelo, bruto: bruto || txt.slice(0, 300) };
      if (alucinacao || audio.size < 4000) return semTexto; // silêncio de verdade: não insiste
      continue;
    }
    ultimo = `transcrição ${r.status} (${modelo}): ${txt.slice(0, 200)}`;
    if (r.status === 401 || r.status === 402) break; // chave/crédito: não adianta trocar de modelo
  }
  if (semTexto) return semTexto;
  throw new Error(ultimo);
}

// transcreve e registra o trecho (dp_rh.agente_reuniao_trechos): tamanho, nível do microfone
// que a página mediu, resultado e, no modo diagnóstico, o áudio dos que não viraram texto
async function ouvir(audio: File, reuniaoId: string | null, u: Usuario, corpo: any): Promise<Transcricao> {
  const t0 = Date.now();
  const n = (v: unknown) => (Number.isFinite(Number(v)) && String(v ?? "") !== "" ? Number(v) : null);
  const cliente = { rms_max: n(corpo.rms_max), voz_ms: n(corpo.voz_ms), ruido: n(corpo.ruido), ua: String(corpo.ua ?? "").slice(0, 200) || null };
  let t: Transcricao;
  try {
    t = await transcrever(audio);
  } catch (err) {
    t = { texto: "", resultado: "erro", modelo: "", bruto: erroTxt(err) };
  }
  const ms = Date.now() - t0;
  console.log("trecho", JSON.stringify({ reuniao: reuniaoId, bytes: audio.size, mime: audio.type, resultado: t.resultado, modelo: t.modelo, letras: t.texto.length, ms, ...cliente }));
  try {
    const { diag } = await config();
    const { error } = await supa.rpc("agente_reuniao_trecho_log", {
      p_reuniao: reuniaoId,
      p_matricula: u.matricula,
      p_dados: {
        bytes: audio.size, segundos: n(corpo.segundos), mime: audio.type || null, resultado: t.resultado,
        modelo: t.modelo || null, texto: t.resultado === "ok" ? null : t.bruto, ms, cliente,
      },
      p_audio: diag && t.resultado !== "ok" ? base64(new Uint8Array(await audio.arrayBuffer())) : null,
    });
    if (error) console.error("trecho_log", error.message);
  } catch (err) {
    console.error("trecho_log", erroTxt(err));
  }
  if (t.resultado === "erro") throw new Error(t.bruto);
  return t;
}

function base64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

// pcm 16 bits mono → wav (para o navegador tocar)
function wav(pcm: Uint8Array, taxa = 24000): Uint8Array {
  const h = new DataView(new ArrayBuffer(44));
  const txt = (o: number, t: string) => { for (let i = 0; i < t.length; i++) h.setUint8(o + i, t.charCodeAt(i)); };
  txt(0, "RIFF"); h.setUint32(4, 36 + pcm.length, true); txt(8, "WAVE"); txt(12, "fmt ");
  h.setUint32(16, 16, true); h.setUint16(20, 1, true); h.setUint16(22, 1, true); h.setUint32(24, taxa, true);
  h.setUint32(28, taxa * 2, true); h.setUint16(32, 2, true); h.setUint16(34, 16, true); txt(36, "data");
  h.setUint32(40, pcm.length, true);
  const out = new Uint8Array(44 + pcm.length);
  out.set(new Uint8Array(h.buffer), 0);
  out.set(pcm, 44);
  return out;
}

// texto → áudio { mime, base64 }; null se der erro (a página mostra o texto)
type Audio = { mime: string; base64: string };
async function falar(texto: string): Promise<Audio | null> {
  if (!LLM_KEY || !texto.trim()) return null;
  const { modeloVoz, voz } = await config();
  const tentativas: Array<{ model: string; voice: string; formato: "mp3" | "pcm" }> = [
    { model: modeloVoz, voice: voz, formato: /gemini|heygen/.test(modeloVoz) ? "pcm" : "mp3" },
    { model: "google/gemini-3.8-flash-tts", voice: "Charon", formato: "pcm" },
  ];
  for (const t of tentativas) {
    const corpo: Record<string, unknown> = { model: t.model, voice: t.voice, input: texto.slice(0, 1500), response_format: t.formato };
    if (/gemini/.test(t.model)) corpo.instructions = "Fale em português do Brasil, tom calmo e cordial de colega de trabalho, ritmo natural.";
    const r = await fetch(`${AUDIO_BASE}/audio/speech`, {
      method: "POST",
      headers: { Authorization: `Bearer ${LLM_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify(corpo),
      signal: AbortSignal.timeout(30_000),
    });
    if (r.ok) {
      const bytes = new Uint8Array(await r.arrayBuffer());
      return t.formato === "mp3" ? { mime: "audio/mpeg", base64: base64(bytes) } : { mime: "audio/wav", base64: base64(wav(bytes)) };
    }
    console.error("voz", r.status, t.model, (await r.text().catch(() => "")).slice(0, 200));
    if (r.status === 401 || r.status === 402) break;
  }
  return null;
}

// para falar: sem markdown, links, emojis e marcadores
function paraVoz(t: string): string {
  return t
    .replace(/https?:\/\/\S+/g, "")
    .replace(/[*_~`#>]/g, "")
    .replace(/^\s*[•\-–]\s*/gm, "")
    .replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]/gu, "")
    .replace(/\n{2,}/g, "\n")
    .trim();
}

// "Sam, …" / "ô Sam …" → a pergunta (string vazia = chamou sem perguntar ainda)
const CHAMADO_RE = /(?:^|[.!?…]\s*|\b(?:ô|ó|oi|ei|e aí|fala|hey)\s*,?\s*)\bsam\b[\s,:;!.?-]*/i;
function chamadoDoSam(t: string): string | null {
  const m = CHAMADO_RE.exec(t);
  if (!m) return null;
  return t.slice(m.index + m[0].length).trim();
}

// ── o Sam responde (mesmo cérebro do WhatsApp, em modo reunião) ─────────────
async function responderSam(reuniao: any, pergunta: string, u: Usuario) {
  const [{ data: contexto }, k] = await Promise.all([
    supa.rpc("agente_reuniao_transcricao", { p_id: reuniao.id, p_minutos: 10 }),
    segredo("portal_secret"),
  ]);
  await supa.rpc("agente_reuniao_fala", { p_id: reuniao.id, p_tipo: "pergunta", p_texto: pergunta, p_segundos: null });
  const r = await fetch(`${SUPA_URL}/functions/v1/agente-whatsapp?reuniao=${encodeURIComponent(k)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ texto: pergunta, contexto: String(contexto ?? ""), nome: u.nome.split(" ")[0], titulo: reuniao.titulo }),
    signal: AbortSignal.timeout(120_000),
  });
  const out = await r.json().catch(() => ({})) as any;
  const texto = out?.ok ? paraVoz(String(out.texto ?? "")) : "Tive um problema para consultar agora. Pode repetir daqui a pouco?";
  await supa.rpc("agente_reuniao_fala", { p_id: reuniao.id, p_tipo: "resposta", p_texto: texto || "(sem resposta)", p_segundos: null });
  return { texto, audio: await falar(texto), consultas: out?.consultas ?? [], erro: out?.ok ? null : (out?.erro ?? `HTTP ${r.status}`) };
}

// ── ata ─────────────────────────────────────────────────────────────────────
const hora = (iso: string | null) =>
  iso ? new Date(iso).toLocaleTimeString("pt-BR", { timeZone: "America/Sao_Paulo", hour: "2-digit", minute: "2-digit" }) : "";
const dia = (iso: string) => new Date(iso).toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });

// 11/11: reunião de 1h16 voltou com a resposta vazia (o raciocínio do modelo gastou os 5.000 tokens antes do
// texto). Agora: folga de 16.000 tokens, e resposta vazia tenta o próximo modelo, com o motivo no erro/log.
async function chamarClaude(sistema: string, usuario: string): Promise<string> {
  let ultimo = "";
  for (const modelo of MODELOS_ATA) {
    const r = await fetch(LLM_URL, {
      method: "POST",
      signal: AbortSignal.timeout(280_000),
      headers: {
        Authorization: `Bearer ${LLM_KEY}`, "Content-Type": "application/json",
        "HTTP-Referer": "https://lideres.tatasushi.tech", "X-Title": "Tata Agente RH - ata",
      },
      body: JSON.stringify({
        model: modelo, max_tokens: 16000, reasoning: { effort: "medium" },
        messages: [{ role: "system", content: sistema }, { role: "user", content: usuario }],
      }),
    });
    const txt = await r.text();
    if (r.ok) {
      let j: any = null;
      try { j = JSON.parse(txt); } catch { /* resposta cortada */ }
      const ch = j?.choices?.[0];
      const c = String(ch?.message?.content ?? "").trim();
      console.log("ata llm", JSON.stringify({ modelo, fim: ch?.finish_reason ?? null, letras: c.length, uso: j?.usage ?? null }));
      if (c) return c;
      ultimo = `LLM sem texto (${modelo}): fim=${ch?.finish_reason ?? "?"} erro=${JSON.stringify(ch?.error ?? j?.error ?? null).slice(0, 150)}`;
      continue; // resposta vazia: tenta o próximo modelo
    }
    ultimo = `LLM ${r.status} (${modelo}): ${txt.trim().slice(0, 200)}`;
    if (!(r.status === 400 || r.status === 404) || !/model/i.test(txt)) break;
  }
  throw new Error(ultimo);
}

const INSTRUCOES_ATA = `Você é o Sam, assistente virtual do RH do TATÁ Sushi. A partir da transcrição automática de uma reunião de RH (ela tem erros de reconhecimento e pode ter trechos soltos; quando a linha traz um nome — "[10:02] Victor: …" — é quem falou; "Pessoa A", "Pessoa B" são vozes não reconhecidas, e a mesma letra em horários distantes pode ser outra pessoa; "Sam" é você; linhas sem nome não identificam quem fala), escreva TRÊS textos, cada um depois do seu marcador, em linhas próprias, exatamente assim:

===ATA===
Síntese executiva da reunião

<um parágrafo de abertura, começando com "A reunião concentrou-se em", com os assuntos principais; sem data, horário ou duração>

1. <Tema>

<parágrafos curtos: o que foi discutido, números citados e o que ficou definido ou o próximo passo; quando houver vários itens, uma lista com "- item;" e o último terminando em ponto>

2. <Tema>

...

Decisões

- <decisão>

Pendências

- <responsável> — <o que fazer> — <prazo, se foi dito>
===GRUPO===
<resumo para o WhatsApp do DP/RH, até uns 1.200 caracteres: primeira linha "*<título> — <data>*"; a síntese em 2 ou 3 frases; "*Decisões*" com •; "*Pendências*" com • responsável — o quê — prazo; última linha "Ata completa no portal.">
===FALADO===
<o encerramento que você vai FALAR em voz alta na sala: 3 a 5 frases curtas, tom de colega, começando com "Fechando a reunião:"; os assuntos principais, o que ficou decidido e quem ficou com cada pendência; termine dizendo que vai mandar o resumo no grupo do DP. Sem listas, emojis ou asteriscos.>

Regras:
• Português do Brasil, no estilo das atas de RH da empresa: frases completas e impessoais ("foi discutido", "ficou definido", "o próximo passo é"), parágrafos curtos, agrupado por tema e não pela ordem da conversa.
• Ata em texto puro: sem markdown (# ou **), sem emojis, sem assinatura ou observação sobre quem fez a ata ou como ela foi feita.
• Resumo do grupo: sem emojis; o asterisco só para o negrito do WhatsApp.
• Não invente: só o que está na transcrição. Responsável que não ficou claro = "responsável a definir". Se não houver decisões ou pendências, escreva "Nenhuma registrada." na seção.
• Nomes de pessoas como aparecem; corrija erros óbvios de transcrição só quando o contexto deixar claro.
• Quando a transcrição diz quem falou, use isso para os responsáveis: "eu faço", "deixa comigo", "eu vejo isso" dito pelo Victor = Victor é o responsável. No texto da ata mantenha o estilo impessoal; cite nomes só quando importa (quem ficou com o quê, quem trouxe uma proposta).
• Perguntas ao Sam e respostas dele só entram se viraram decisão ou pendência.
• No resumo do grupo e no encerramento falado, sem salário individual nem assunto pessoal ou confidencial de colaborador (saúde, sanção, desligamento de alguém): use termos gerais. Isso fica só na ata, que é restrita.`;

// 4º bloco: as pendências viram cards no kanban do RH (etiquetas e responsáveis do quadro)
type Opcoes = { etiquetas: string[]; responsaveis: string[] };
function instrucoesAta(op: Opcoes): string {
  if (!op.etiquetas.length) return INSTRUCOES_ATA;
  return `${INSTRUCOES_ATA}

Depois do FALADO, escreva o quarto bloco:
===CARDS===
<uma linha por pendência da ata, em JSON numa linha só, para virar card no quadro de demandas do RH:
{"titulo": "...", "descricao": "...", "responsavel": "...", "etiqueta": "...", "prazo": "..."}>

Regras dos cards:
• titulo: curto (até 50 caracteres), no estilo "Tema – ação" (ex.: "Jurídico – recurso", "Confraternização fim de ano").
• descricao: 1 ou 2 frases com o que fazer e o contexto que ajuda quem vai executar.
• responsavel: um destes nomes — ${op.responsaveis.join(", ")} — só se ficou claro na reunião quem vai fazer (a pessoa foi chamada pelo nome para a tarefa ou disse que faz). Se não ficou claro, "". Use o mesmo responsável na seção Pendências da ata e do resumo.
• etiqueta: exatamente uma destas, a que melhor descreve o assunto: ${op.etiquetas.join("; ")}. Se nenhuma servir, "Outros".
• prazo: AAAA-MM-DD se um prazo foi dito (converta "sexta", "dia 20", "fim do mês" a partir da data da reunião; "semana que vem" = sexta-feira da semana seguinte); senão "".
• Só pendências de verdade (alguém precisa fazer algo). Sem pendências: escreva só "Nenhum".`;
}

// separa os três blocos da resposta (com plano B se o modelo não seguir os marcadores)
function blocos(t: string, titulo: string, data: string) {
  const pega = (nome: string) => {
    const m = new RegExp(`===\\s*${nome}\\s*===\\s*([\\s\\S]*?)(?====\\s*[A-Z]+\\s*===|$)`).exec(t);
    return m ? m[1].trim() : "";
  };
  const ata = pega("ATA") || t.replace(/===\s*[A-Z]+\s*===/g, "").trim();
  const grupo = pega("GRUPO") ||
    `*${titulo} — ${data}*\n\n${ata.slice(0, 1100)}${ata.length > 1100 ? "…" : ""}\n\nAta completa no portal.`;
  const falado = pega("FALADO").replace(/[*•#]/g, "").trim() ||
    "Fechando a reunião. Vou mandar o resumo no grupo do DP, e a ata completa fica no portal.";
  const cards: Array<Record<string, string>> = [];
  for (const linha of pega("CARDS").split("\n")) {
    const l = linha.trim().replace(/^[-•]\s*/, "").replace(/,$/, "");
    if (!l.startsWith("{")) continue;
    try {
      const c = JSON.parse(l);
      if (c && typeof c.titulo === "string" && c.titulo.trim()) cards.push(c);
    } catch { /* linha que não é JSON: ignora */ }
  }
  return { ata, grupo, falado, cards };
}

async function opcoesKanban(): Promise<Opcoes> {
  const { data, error } = await supa.rpc("agente_kanban_opcoes");
  if (error || !data) return { etiquetas: [], responsaveis: [] };
  const d = data as any;
  return { etiquetas: (d.etiquetas ?? []).map(String), responsaveis: (d.responsaveis ?? []).map(String) };
}

// "07/11/2026 (sábado)"
const diaSemana = (iso: string) =>
  `${dia(iso)} (${new Date(iso).toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo", weekday: "long" })})`;

// ── quem falou o quê (gravação contínua + vozes cadastradas) ──────────────────
async function baixar(p: Parte): Promise<Uint8Array> {
  const { data, error } = await supa.storage.from(BUCKET).download(p.caminho);
  if (error || !data) throw new Error(`áudio ${p.parte}: ${error?.message ?? "sem dados"}`);
  return new Uint8Array(await data.arrayBuffer());
}

// rodadas de nomes → vozes cadastradas; depois a reunião inteira separada por vozes, com nomes.
// Devolve a transcrição "[HH:MM] Nome: texto" ou "" se não houver gravação.
async function transcricaoComVozes(reuniao: any, gravarVozes = true): Promise<string> {
  const t0 = Date.now();
  const { data: lp } = await supa.rpc("agente_reuniao_audio_listar", { p_id: reuniao.id });
  const partes = ((lp ?? []) as Parte[]).filter((p) => p.bytes > 0);
  if (!partes.length) return "";
  const { modeloVozes, participantes } = await config();
  const msDe = (p: Parte) => p.ms + (p.bytes / TAXA) * 1000;
  const novas: Voz[] = [];

  for (const [de, ate] of (reuniao.rodadas ?? []) as Array<[number, number]>) {
    const ps = partes.filter((p) => p.ms < ate + 1000 && msDe(p) > de - 1000);
    if (!ps.length) continue;
    const audio = juntar(await Promise.all(ps.map(baixar)));
    const ini = Math.max(0, Math.floor(((de - ps[0].ms) / 1000) * TAXA));
    const fim = Math.min(audio.length, Math.ceil(((ate - ps[0].ms) / 1000 + 1) * TAXA));
    const trecho = audio.subarray(ini, fim);
    const palavras = await separar(AUDIO_BASE, LLM_KEY, modeloVozes, trecho);
    for (const v of cadastroDaRodada(palavras, trecho, participantes)) {
      if (!gravarVozes) { novas.push({ nome: v.nome, audio: v.audio }); continue; }
      const { error } = await supa.rpc("agente_voz_gravar", { p_nome: v.nome, p_audio: base64(v.audio), p_segundos: v.segundos, p_reuniao: reuniao.id });
      if (error) console.error("voz", v.nome, error.message);
    }
  }

  const { data: lv } = await supa.rpc("agente_vozes_listar");
  const vozes: Voz[] = [
    ...novas,
    ...((lv ?? []) as any[]).map((v) => ({ nome: String(v.nome), audio: deBase64(String(v.audio)) })).filter((v) => !novas.some((n) => n.nome === v.nome)),
  ];
  const sam = (reuniao.sam ?? []) as Array<[number, number]>;
  const grupos = blocosDeAudio(partes);
  const linhas: Linha[][] = new Array(grupos.length);
  let prox = 0;
  const trabalhar = async () => {
    while (prox < grupos.length) {
      const k = prox++;
      if (Date.now() - t0 > 100_000) throw new Error("separação de vozes demorou demais");
      const g = grupos[k];
      const { audio, marcas, inicio } = comPrefixo(vozes, juntar(await Promise.all(g.map(baixar))));
      const palavras = await separar(AUDIO_BASE, LLM_KEY, modeloVozes, audio);
      linhas[k] = falasDoBloco(palavras, nomesDasVozes(palavras, marcas), inicio, g[0].ms, sam);
    }
  };
  await Promise.all([trabalhar(), trabalhar(), trabalhar()]);
  const base = new Date(reuniao.inicio).getTime();
  console.log("vozes", JSON.stringify({ reuniao: reuniao.id, partes: partes.length, blocos: grupos.length, vozes: vozes.map((v) => v.nome), ms: Date.now() - t0 }));
  return linhas.flat().map((l) => `[${hora(new Date(base + l.ms).toISOString())}] ${l.quem}: ${l.texto}`).join("\n");
}

// apaga a gravação contínua de uma reunião (storage + registros)
async function apagarAudio(id: string) {
  const { data: lp } = await supa.rpc("agente_reuniao_audio_listar", { p_id: id });
  const caminhos = ((lp ?? []) as Parte[]).map((p) => p.caminho);
  for (let i = 0; i < caminhos.length; i += 100) {
    const { error } = await supa.storage.from(BUCKET).remove(caminhos.slice(i, i + 100));
    if (error) { console.error("apagar áudio", error.message); return; }
  }
  await supa.rpc("agente_reuniao_audio_apagar", { p_id: id });
}

async function gerarAta(id: string) {
  try {
    const [{ data: r }, { data: transcricao }] = await Promise.all([
      supa.rpc("agente_reuniao_ver", { p_id: id }),
      supa.rpc("agente_reuniao_transcricao", { p_id: id, p_minutos: null }),
    ]);
    const reuniao = r as any;
    // com a gravação contínua: transcrição separada por vozes, com nomes; senão (ou se falhar), a ao vivo
    let comVozes = "";
    try {
      comVozes = await transcricaoComVozes(reuniao);
    } catch (err) {
      console.error("vozes", erroTxt(err));
    }
    const texto = comVozes || String(transcricao ?? "").trim();
    if (!texto) throw new Error("nenhuma fala foi transcrita");
    const fim = reuniao.fim ?? new Date().toISOString();
    const opcoes = await opcoesKanban();
    const resposta = await chamarClaude(instrucoesAta(opcoes),
      `Reunião: ${reuniao.titulo} — ${diaSemana(reuniao.inicio)}, das ${hora(reuniao.inicio)} às ${hora(fim)}.\n\nTRANSCRIÇÃO\n${texto.slice(-150_000)}`);
    const b = blocos(resposta, reuniao.titulo, dia(reuniao.inicio));
    // ata, resumo e transcrição na tabela das atas de RH (dp_rh.alinhamento_transcricao)
    const { error } = await supa.rpc("agente_reuniao_gravar_ata", {
      p_id: id, p_ata: b.ata, p_resumo_grupo: b.grupo, p_resumo_falado: b.falado,
    });
    if (error) throw new Error(error.message);
    if (comVozes) await supa.rpc("agente_reuniao_transcricao_gravar", { p_id: id, p_texto: comVozes });
    // pendências → cards no kanban (uma vez por reunião; falha aqui não derruba a ata)
    let nCards = 0;
    if (b.cards.length) {
      const { data: n, error: e2 } = await supa.rpc("agente_reuniao_criar_cards", { p_id: id, p_cards: b.cards });
      if (e2) console.error("cards", e2.message);
      nCards = Number(n ?? 0);
    }
    // no WhatsApp vai só o resumo (a ata completa fica no portal). Vira conversa do Sam: dá para
    // responder "Sam, detalha a pendência 2". Destino: grupo DP/RH (ou o responsável, nos testes)
    const { responsavel, grupo } = await config();
    const destino = grupo || responsavel;
    const msg = b.grupo + (nCards ? `\n${nCards === 1 ? "1 demanda criada" : `${nCards} demandas criadas`} no kanban (Pendentes).` : "");
    if (destino) {
      const ids = await enviarWhats(destino, msg);
      await supa.rpc("agente_registrar", {
        p_telefone: destino, p_papel: "assistant", p_texto: msg, p_msg_id: ids[0] ?? null, p_meta: { reuniao_id: id },
      });
    }
    // a gravação contínua só serve para a ata: some depois que ela fica pronta
    await apagarAudio(id).catch((e) => console.error("apagar áudio", erroTxt(e)));
  } catch (err) {
    await supa.rpc("agente_reuniao_status", { p_id: id, p_status: "erro", p_erro: erroTxt(err).slice(0, 500) });
    const { responsavel } = await config();
    if (responsavel) {
      await enviarWhats(responsavel, `Não consegui fazer a ata da reunião (${erroTxt(err).slice(0, 200)}). A transcrição ficou salva; dá para pedir de novo na página do Sam.`)
        .catch(() => {});
    }
  }
}

// envia em partes de até ~3500 caracteres (cortando em parágrafo); devolve os ids das mensagens
async function enviarWhats(destino: string, texto: string): Promise<string[]> {
  const token = Deno.env.get("SAM_UAZAPI_TOKEN") || await segredo("uazapi_token");
  if (!destino || !token) return [];
  const ids: string[] = [];
  let resto = texto;
  while (resto) {
    let corte = resto.length > 3500 ? resto.lastIndexOf("\n\n", 3500) : resto.length;
    if (corte < 1500) corte = Math.min(resto.length, 3500);
    const r = await fetch(UAZ_BASE + "/send/text", {
      method: "POST",
      headers: { "Content-Type": "application/json", token },
      body: JSON.stringify({ number: destino, text: resto.slice(0, corte).trim(), delay: 0, linkPreview: false }),
    });
    try {
      const out = await r.json();
      const id = out?.messageid ?? out?.id ?? out?.key?.id;
      if (id) ids.push(String(id));
    } catch { /* sem JSON */ }
    resto = resto.slice(corte).trim();
  }
  return ids;
}

// ── rotas ───────────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  const h = cors(req);
  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), { status, headers: { ...h, "Content-Type": "application/json" } });
  if (req.method === "OPTIONS") return new Response("ok", { headers: h });
  if (req.method !== "POST") return json({ ok: false, erro: "use POST" }, 405);

  const url = new URL(req.url);
  // pg_cron: encerra reuniões abandonadas (página fechada sem "Encerrar")
  if (url.searchParams.has("k")) {
    const k = await segredo("portal_secret");
    if (!k || url.searchParams.get("k") !== k) return json({ ok: false, erro: "nao_autorizado" }, 401);
    // testes internos (não gravam nem mandam WhatsApp): voz, transcrição e ata
    const t: any = await req.json().catch(() => ({}));
    if (t?.acao === "teste_voz") {
      const t0 = Date.now();
      const a = await falar(String(t.texto ?? "Oi, pessoal! Teste de voz do Sam."));
      return json({ ok: !!a, mime: a?.mime, base64: t.devolver ? a?.base64 : undefined, bytes: a ? Math.round(a.base64.length * 0.75) : 0, ms: Date.now() - t0 });
    }
    if (t?.acao === "teste_transcricao") {
      const t0 = Date.now();
      const bytes = Uint8Array.from(atob(String(t.audio_base64 ?? "")), (c) => c.charCodeAt(0));
      const r = await transcrever(new File([bytes], `teste.${t.formato ?? "mp3"}`, { type: String(t.mime ?? "audio/mpeg") }));
      return json({ ok: true, ...r, chamado: chamadoDoSam(r.texto), ms: Date.now() - t0 });
    }
    if (t?.acao === "teste_ata") {
      const t0 = Date.now();
      const agora = new Date().toISOString();
      const r = await chamarClaude(instrucoesAta(await opcoesKanban()),
        `Reunião: Reunião de RH (teste) — ${diaSemana(agora)}.\n\nTRANSCRIÇÃO\n${String(t.transcricao ?? "")}`);
      return json({ ok: true, ...blocos(r, "Reunião de RH (teste)", dia(agora)), ms: Date.now() - t0 });
    }
    if (t?.acao === "refazer_ata") {
      const { data: r } = await supa.rpc("agente_reuniao_ver", { p_id: String(t.reuniao ?? "") });
      if (!r) return json({ ok: false, erro: "reunião não encontrada" }, 404);
      if ((r as any).status !== "erro") return json({ ok: false, erro: `reunião está ${(r as any).status}` }, 409);
      await supa.rpc("agente_reuniao_status", { p_id: (r as any).id, p_status: "gerando_ata", p_erro: null });
      EdgeRuntime.waitUntil(gerarAta((r as any).id));
      return json({ ok: true, status: "gerando_ata" });
    }
    if (t?.acao === "teste_vozes") {
      // separa por vozes uma reunião já gravada, sem cadastrar vozes nem fazer ata
      const t0 = Date.now();
      const { data: r } = await supa.rpc("agente_reuniao_ver", { p_id: String(t.reuniao ?? "") });
      if (!r) return json({ ok: false, erro: "reunião não encontrada" }, 404);
      const texto = await transcricaoComVozes(r, false);
      return json({ ok: true, texto, ms: Date.now() - t0 });
    }
    // gravações que sobraram (reunião com erro na ata): somem em 3 dias
    const { data: velhas } = await supa.rpc("agente_reuniao_audio_velhas", { p_dias: 3 });
    for (const id of (velhas ?? []) as string[]) await apagarAudio(id).catch((e) => console.error("apagar áudio", erroTxt(e)));
    const { data: paradas } = await supa.rpc("agente_reunioes_paradas", { p_minutos: 20 });
    for (const id of (paradas ?? []) as string[]) {
      await supa.rpc("agente_reuniao_status", { p_id: id, p_status: "gerando_ata", p_erro: null });
      EdgeRuntime.waitUntil(gerarAta(id));
    }
    return json({ ok: true, encerradas: (paradas ?? []).length });
  }

  const u = await usuarioDe(req);
  if (!u) return json({ ok: false, erro: "sem_acesso" }, 403);

  try {
    const multipart = (req.headers.get("Content-Type") ?? "").includes("multipart/form-data");
    const form = multipart ? await req.formData() : null;
    const corpo: any = multipart ? Object.fromEntries([...form!.entries()].filter(([, v]) => typeof v === "string")) : await req.json();
    const acao = String(corpo.acao ?? "");

    if (acao === "iniciar") {
      const { data: id, error } = await supa.rpc("agente_reuniao_iniciar", {
        p_matricula: u.matricula, p_nome: u.nome, p_titulo: String(corpo.titulo ?? "") || null,
      });
      if (error) throw new Error(error.message);
      const primeiro = u.nome.split(" ")[0];
      const { data: vn } = await supa.rpc("agente_vozes_nomes");
      const vozes = ((vn ?? []) as unknown[]).map(String);
      // o Sam não fala ao começar (a página só apita); a rodada de nomes vem com "Sam, se apresente"
      const espera = await falar("Deixa eu ver.");
      return json({ ok: true, id, usuario: primeiro, espera, vozes });
    }

    // rodada de nomes pedida pelo botão (alguém novo na sala)
    if (acao === "rodada_audio") {
      return json({ ok: true, audio: await falar((await config()).textoRodada) });
    }

    // teste do microfone antes de começar: só transcreve e devolve o que o Sam entendeu
    if (acao === "teste_mic") {
      const audio = form?.get("audio");
      if (!(audio instanceof File) || audio.size < 1000) return json({ ok: true, texto: "", motivo: "pequeno" });
      if (audio.size > 8_000_000) return json({ ok: false, erro: "áudio grande demais" }, 413);
      const t = await ouvir(audio, null, u, corpo);
      return json({ ok: true, texto: t.texto, motivo: t.resultado });
    }

    const reuniao = await minhaReuniao(String(corpo.reuniao ?? ""), u);

    if (acao === "status") {
      return json({
        ok: true, status: reuniao.status, ata: reuniao.ata, erro: reuniao.erro, resumo_grupo: reuniao.resumo_grupo,
        resumo_falado: reuniao.resumo_falado, perguntas: reuniao.perguntas, segundos: Number(reuniao.segundos_audio ?? 0),
      });
    }
    // encerramento falado na sala (depois que a ata ficou pronta)
    if (acao === "fala_final") {
      if (reuniao.status !== "concluida") return json({ ok: false, erro: "a ata ainda não ficou pronta" }, 409);
      const texto = String(reuniao.resumo_falado ?? "") || "Fechando a reunião. Vou mandar o resumo no grupo do DP.";
      return json({ ok: true, texto, audio: await falar(texto) });
    }
    if (acao === "encerrar") {
      if (reuniao.status === "gravando") {
        const lista = (v: unknown) =>
          (Array.isArray(v) ? v : []).filter((x) => Array.isArray(x) && x.length === 2)
            .map((x: any) => [Math.max(0, Math.round(Number(x[0]) || 0)), Math.max(0, Math.round(Number(x[1]) || 0))]).slice(0, 1000);
        await supa.rpc("agente_reuniao_meta", { p_id: reuniao.id, p_meta: { sam: lista(corpo.sam), rodadas: lista(corpo.rodadas) } });
      }
      if (reuniao.status === "gravando" || reuniao.status === "erro") {
        await supa.rpc("agente_reuniao_status", { p_id: reuniao.id, p_status: "gerando_ata", p_erro: null });
        EdgeRuntime.waitUntil(gerarAta(reuniao.id));
      }
      return json({ ok: true, status: "gerando_ata" });
    }
    if (reuniao.status !== "gravando") return json({ ok: false, erro: "reunião já encerrada" }, 409);

    if (acao === "gravacao") {
      const audio = form?.get("audio");
      if (!(audio instanceof File) || !audio.size) return json({ ok: true });
      if (audio.size > 2_000_000) return json({ ok: false, erro: "pedaço de gravação grande demais" }, 413);
      const parte = Math.max(0, Math.floor(Number(corpo.parte) || 0));
      const ms = Math.max(0, Math.floor(Number(corpo.ms) || 0));
      const caminho = `${reuniao.id}/${String(parte).padStart(4, "0")}.ulaw`;
      const { error: e1 } = await supa.storage.from(BUCKET)
        .upload(caminho, new Uint8Array(await audio.arrayBuffer()), { contentType: "application/octet-stream", upsert: true });
      if (e1) throw new Error(e1.message);
      await supa.rpc("agente_reuniao_audio_parte", { p_id: reuniao.id, p_parte: parte, p_ms: ms, p_bytes: audio.size, p_caminho: caminho });
      return json({ ok: true });
    }
    if (acao === "trecho") {
      const audio = form?.get("audio");
      if (!(audio instanceof File) || audio.size < 1000) return json({ ok: true, texto: "", motivo: "pequeno" });
      if (audio.size > 8_000_000) return json({ ok: false, erro: "trecho grande demais" }, 413);
      const segundos = Number(corpo.segundos) || null;
      const t = await ouvir(audio, reuniao.id, u, corpo);
      const texto = t.texto;
      if (!texto) return json({ ok: true, texto: "", motivo: t.resultado });
      // pergunta pelo botão (ou depois de só "Sam"): o trecho inteiro é a pergunta
      if (corpo.pergunta === "1") return json({ ok: true, texto, pergunta: texto });
      await supa.rpc("agente_reuniao_fala", { p_id: reuniao.id, p_tipo: "fala", p_texto: texto, p_segundos: segundos });
      const chamado = chamadoDoSam(texto);
      return json({ ok: true, texto, chamado: chamado !== null, pergunta: chamado || null });
    }
    if (acao === "perguntar") {
      const pergunta = String(corpo.pergunta ?? "").trim();
      if (!pergunta) return json({ ok: false, erro: "pergunta vazia" }, 400);
      // "Sam, se apresente": texto fixo e a página abre a rodada de nomes logo depois da fala
      if (APRESENTE_RE.test(semAcento(pergunta))) {
        const { textoApresentacao } = await config();
        return json({ ok: true, texto: textoApresentacao, audio: await falar(textoApresentacao), consultas: [], rodada: true });
      }
      return json({ ok: true, ...(await responderSam(reuniao, pergunta.slice(0, 1000), u)) });
    }
    return json({ ok: false, erro: "ação desconhecida" }, 400);
  } catch (err) {
    return json({ ok: false, erro: erroTxt(err) }, 400);
  }
});
