// agente-reuniao — Sam no modo reunião (reunião de RH presencial).
//
// A página compliance/kpis/rh/sam.html (dentro do app Tatá Plus) ouve pelo microfone e manda
// trechos de áudio cortados nas pausas. Aqui:
//   iniciar   → abre a reunião (dp_rh.agente_reunioes) e devolve a saudação falada
//   teste_mic → (antes de começar) transcreve 5 s de fala para o líder conferir o microfone
//   trecho    → transcreve (OpenRouter) e guarda; avisa se chamaram "Sam, …"
//               cada trecho fica registrado em dp_rh.agente_reuniao_trechos (tamanho, nível do
//               microfone, resultado); com agente_config reuniao_diag_audio = '1', o áudio dos que
//               não viraram texto fica guardado 3 dias para diagnóstico
//   perguntar → o Sam de sempre (edge agente-whatsapp ?reuniao=) responde com o contexto dos
//               últimos minutos; a resposta volta em texto e em voz (OpenRouter)
//   encerrar  → fecha e gera em segundo plano (Claude) a ata no formato das atas de RH (grava em
//               dp_rh.alinhamento_transcricao), o resumo para o grupo DP/RH (agente_config
//               reuniao_grupo_resumo) e o encerramento falado; ata completa no privado do responsável
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
let cfg: { transcricao: string; voz: string; modeloVoz: string; responsavel: string; grupo: string; diag: boolean; em: number } | null = null;
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

async function chamarClaude(sistema: string, usuario: string): Promise<string> {
  let ultimo = "";
  for (const modelo of MODELOS_ATA) {
    const r = await fetch(LLM_URL, {
      method: "POST",
      signal: AbortSignal.timeout(180_000),
      headers: {
        Authorization: `Bearer ${LLM_KEY}`, "Content-Type": "application/json",
        "HTTP-Referer": "https://lideres.tatasushi.tech", "X-Title": "Tata Agente RH - ata",
      },
      body: JSON.stringify({
        model: modelo, temperature: 0.2, max_tokens: 5000,
        messages: [{ role: "system", content: sistema }, { role: "user", content: usuario }],
      }),
    });
    const txt = await r.text();
    if (r.ok) {
      const c = JSON.parse(txt)?.choices?.[0]?.message?.content;
      if (c) return String(c).trim();
    }
    ultimo = `LLM ${r.status} (${modelo}): ${txt.slice(0, 200)}`;
    if (!(r.status === 400 || r.status === 404) || !/model/i.test(txt)) break;
  }
  throw new Error(ultimo);
}

const INSTRUCOES_ATA = `Você é o Sam, assistente virtual do RH do TATÁ Sushi. A partir da transcrição automática de uma reunião de RH (ela tem erros de reconhecimento, não identifica quem fala e pode ter trechos soltos), escreva TRÊS textos, cada um depois do seu marcador, em linhas próprias, exatamente assim:

===ATA===
Síntese executiva da reunião

<um parágrafo com os assuntos principais>

1. <Tema>

<parágrafos curtos: o que foi discutido, números citados e o que ficou decidido>

2. <Tema>
...

Decisões
• <decisão>

Pendências
• <responsável> — <o que fazer> — <prazo, se foi dito>
===GRUPO===
<resumo para o grupo de WhatsApp do DP/RH, até uns 1.200 caracteres: primeira linha "📝 *<título> — <data>*"; a síntese em 2 ou 3 frases; "*Decisões*" com •; "*Pendências*" com • responsável — o quê — prazo; última linha "Ata completa no portal.">
===FALADO===
<o encerramento que você vai FALAR em voz alta na sala: 3 a 5 frases curtas, tom de colega, começando com "Fechando a reunião:"; os assuntos principais, o que ficou decidido e quem ficou com cada pendência; termine dizendo que vai mandar o resumo no grupo do DP. Sem listas, emojis ou asteriscos.>

Regras:
• Português do Brasil. Ata: texto puro, sem markdown (# ou **), agrupada por tema, não pela ordem da conversa.
• Não invente: só o que está na transcrição. Responsável que não ficou claro = "responsável a definir". Se não houver decisões ou pendências, escreva "Nenhuma registrada." na seção.
• Nomes de pessoas como aparecem; corrija erros óbvios de transcrição só quando o contexto deixar claro.
• Perguntas ao Sam e respostas dele só entram se viraram decisão ou pendência.
• No resumo do grupo e no encerramento falado, sem salário individual nem assunto pessoal ou confidencial de colaborador (saúde, sanção, desligamento de alguém): use termos gerais. Isso fica só na ata, que é restrita.`;

// separa os três blocos da resposta (com plano B se o modelo não seguir os marcadores)
function blocos(t: string, titulo: string, data: string) {
  const pega = (nome: string) => {
    const m = new RegExp(`===\\s*${nome}\\s*===\\s*([\\s\\S]*?)(?====\\s*[A-Z]+\\s*===|$)`).exec(t);
    return m ? m[1].trim() : "";
  };
  const ata = pega("ATA") || t.replace(/===\s*[A-Z]+\s*===/g, "").trim();
  const grupo = pega("GRUPO") ||
    `📝 *${titulo} — ${data}*\n\n${ata.slice(0, 1100)}${ata.length > 1100 ? "…" : ""}\n\nAta completa no portal.`;
  const falado = pega("FALADO").replace(/[*•#]/g, "").trim() ||
    "Fechando a reunião. Vou mandar o resumo no grupo do DP, e a ata completa fica no portal.";
  return { ata, grupo, falado };
}

async function gerarAta(id: string) {
  try {
    const [{ data: r }, { data: transcricao }] = await Promise.all([
      supa.rpc("agente_reuniao_ver", { p_id: id }),
      supa.rpc("agente_reuniao_transcricao", { p_id: id, p_minutos: null }),
    ]);
    const reuniao = r as any;
    const texto = String(transcricao ?? "").trim();
    if (!texto) throw new Error("nenhuma fala foi transcrita");
    const minutos = Math.round(Number(reuniao.segundos_audio ?? 0) / 60);
    const fim = reuniao.fim ?? new Date().toISOString();
    const resposta = await chamarClaude(INSTRUCOES_ATA,
      `Reunião: ${reuniao.titulo} — ${dia(reuniao.inicio)}, das ${hora(reuniao.inicio)} às ${hora(fim)}.\n\nTRANSCRIÇÃO\n${texto.slice(-150_000)}`);
    const b = blocos(resposta, reuniao.titulo, dia(reuniao.inicio));
    const ata = `${b.ata}\n\n— Ata feita pelo Sam a partir da gravação da reunião (${dia(reuniao.inicio)}, ${hora(reuniao.inicio)}–${hora(fim)}, ~${minutos} min de fala, ${reuniao.perguntas ?? 0} pergunta(s) ao Sam).`;
    const { error } = await supa.rpc("agente_reuniao_gravar_ata", {
      p_id: id, p_ata: ata, p_resumo_grupo: b.grupo, p_resumo_falado: b.falado,
    });
    if (error) throw new Error(error.message);
    const { responsavel, grupo } = await config();
    // resumo no grupo do DP (vira conversa do Sam: dá para responder "Sam, detalha…")
    if (grupo) {
      const ids = await enviarWhats(grupo, b.grupo);
      await supa.rpc("agente_registrar", {
        p_telefone: grupo, p_papel: "assistant", p_texto: b.grupo, p_msg_id: ids[0] ?? null, p_meta: { reuniao_id: id },
      });
    }
    // ata completa para o responsável
    if (responsavel) await enviarWhats(responsavel, `📝 *Ata da ${reuniao.titulo}* (${dia(reuniao.inicio)}) — salva junto das atas de RH.\n\n${ata}`);
  } catch (err) {
    await supa.rpc("agente_reuniao_status", { p_id: id, p_status: "erro", p_erro: erroTxt(err).slice(0, 500) });
    const { responsavel } = await config();
    if (responsavel) {
      await enviarWhats(responsavel, `⚠️ Não consegui fazer a ata da reunião (${erroTxt(err).slice(0, 200)}). A transcrição ficou salva; dá para pedir de novo na página do Sam.`)
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
      const r = await chamarClaude(INSTRUCOES_ATA, `Reunião: Reunião de RH (teste) — hoje.\n\nTRANSCRIÇÃO\n${String(t.transcricao ?? "")}`);
      return json({ ok: true, ...blocos(r, "Reunião de RH (teste)", dia(new Date().toISOString())), ms: Date.now() - t0 });
    }
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
      const [saudacao, espera] = await Promise.all([
        falar(`Oi, pessoal! Vou acompanhar a reunião e anotar tudo para a ata. Se precisarem de alguma informação, é só dizer: Sam, e a pergunta.`),
        falar("Deixa eu ver."),
      ]);
      return json({ ok: true, id, usuario: primeiro, saudacao, espera });
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
      if (reuniao.status === "gravando" || reuniao.status === "erro") {
        await supa.rpc("agente_reuniao_status", { p_id: reuniao.id, p_status: "gerando_ata", p_erro: null });
        EdgeRuntime.waitUntil(gerarAta(reuniao.id));
      }
      return json({ ok: true, status: "gerando_ata" });
    }
    if (reuniao.status !== "gravando") return json({ ok: false, erro: "reunião já encerrada" }, 409);

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
      return json({ ok: true, ...(await responderSam(reuniao, pergunta.slice(0, 1000), u)) });
    }
    return json({ ok: false, erro: "ação desconhecida" }, 400);
  } catch (err) {
    return json({ ok: false, erro: erroTxt(err) }, 400);
  }
});
