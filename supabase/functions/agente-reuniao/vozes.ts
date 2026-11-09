// Quem falou o quê na reunião.
//
// A página grava a reunião inteira em μ-law 8 kHz mono (1 byte por amostra, sem cabeçalho) e manda
// um pedaço por minuto. No fim, o áudio é separado por vozes (OpenRouter, elevenlabs/scribe-v2 com
// diarize) em blocos de até 10 min. Antes de cada bloco vão os trechos das vozes cadastradas
// (dp_rh.agente_vozes): a voz da reunião que o separador junta com o trecho do Victor é o Victor.
// Cadastro: na rodada de nomes ("aqui é o Victor…"), cada voz é ligada ao nome que ela mesma disse.

export const TAXA = 8000; // amostras (= bytes) por segundo
const BLOCO_S = 600; // blocos de até 10 min
const VOZ_MAX_S = 12; // trecho guardado de cada pessoa
const VOZ_MIN_S = 2;

export type Palavra = { texto: string; de: number; ate: number; spk: string };
export type Voz = { nome: string; audio: Uint8Array };
export type Parte = { parte: number; ms: number; bytes: number; caminho: string };
export type Linha = { ms: number; fim: number; quem: string; texto: string };

export const silencio = (seg: number) => new Uint8Array(Math.round(TAXA * seg)).fill(0xff);

export function juntar(partes: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(partes.reduce((a, p) => a + p.length, 0));
  let o = 0;
  for (const p of partes) { out.set(p, o); o += p.length; }
  return out;
}

// μ-law cru → wav (formato 7)
export function wavUlaw(data: Uint8Array): Uint8Array {
  const h = new DataView(new ArrayBuffer(44));
  const txt = (o: number, t: string) => { for (let i = 0; i < t.length; i++) h.setUint8(o + i, t.charCodeAt(i)); };
  txt(0, "RIFF"); h.setUint32(4, 36 + data.length, true); txt(8, "WAVE"); txt(12, "fmt ");
  h.setUint32(16, 16, true); h.setUint16(20, 7, true); h.setUint16(22, 1, true); h.setUint32(24, TAXA, true);
  h.setUint32(28, TAXA, true); h.setUint16(32, 1, true); h.setUint16(34, 8, true); txt(36, "data");
  h.setUint32(40, data.length, true);
  return juntar([new Uint8Array(h.buffer), data]);
}

export function base64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}
export const deBase64 = (b: string) => Uint8Array.from(atob(b), (c) => c.charCodeAt(0));

const norm = (t: string) =>
  t.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9 ]+/g, " ").replace(/\s+/g, " ").trim();

function lev(a: string, b: string): number {
  const d = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    let ant = d[0];
    d[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const t = d[j];
      d[j] = Math.min(d[j] + 1, d[j - 1] + 1, ant + (a[i - 1] === b[j - 1] ? 0 : 1));
      ant = t;
    }
  }
  return d[b.length];
}

// separa as vozes de um áudio μ-law; devolve as palavras com o falante
export async function separar(base: string, chave: string, modelo: string, ulaw: Uint8Array): Promise<Palavra[]> {
  const r = await fetch(`${base}/audio/transcriptions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${chave}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: modelo,
      input_audio: { data: base64(wavUlaw(ulaw)), format: "wav" },
      language: "pt",
      response_format: "verbose_json",
      provider: { options: { elevenlabs: { diarize: true } } },
    }),
    signal: AbortSignal.timeout(90_000),
  });
  const txt = await r.text();
  if (!r.ok) throw new Error(`vozes ${r.status}: ${txt.slice(0, 200)}`);
  const j = JSON.parse(txt);
  return ((j.words ?? []) as any[])
    .filter((w) => String(w.word ?? "").trim() && w.type !== "spacing")
    .map((w) => ({ texto: String(w.word).trim(), de: Number(w.start), ate: Number(w.end), spk: String(w.speaker ?? w.speaker_id ?? "?") }));
}

// ── rodada de nomes: cada voz → o nome que ela disse ─────────────────────────
function acharNome(texto: string, participantes: string[]): string | null {
  const t = ` ${norm(texto)} `;
  let melhor: { nome: string; pos: number } | null = null;
  for (const n of participantes) {
    const pos = t.indexOf(` ${norm(n)} `);
    if (pos >= 0 && (!melhor || pos < melhor.pos || (pos === melhor.pos && n.length > melhor.nome.length))) melhor = { nome: n, pos };
  }
  if (melhor) return melhor.nome;
  // aproximado (transcrição errou uma letra: "Bino", "Cintia")
  const palavras = t.trim().split(" ").slice(0, 12);
  for (const n of participantes) {
    const p0 = norm(n).split(" ")[0];
    if (p0.length >= 4 && palavras.some((w) => lev(w, p0) <= 1)) return n;
  }
  return null;
}

export function cadastroDaRodada(palavras: Palavra[], audio: Uint8Array, participantes: string[]) {
  const porVoz = new Map<string, Palavra[]>();
  for (const p of palavras) porVoz.set(p.spk, [...(porVoz.get(p.spk) ?? []), p]);
  const achados = new Map<string, { nome: string; audio: Uint8Array; segundos: number }>();
  for (const ps of porVoz.values()) {
    const nome = acharNome(ps.slice(0, 15).map((p) => p.texto).join(" "), participantes);
    if (!nome) continue;
    // trechos contínuos dessa voz (pausa < 0,6 s), até 12 s
    const trechos: Array<[number, number]> = [];
    for (const p of ps) {
      const u = trechos[trechos.length - 1];
      if (u && p.de - u[1] < 0.6) u[1] = p.ate; else trechos.push([p.de, p.ate]);
    }
    const pedacos: Uint8Array[] = [];
    let total = 0;
    for (const [de, ate] of trechos) {
      if (total >= VOZ_MAX_S * TAXA) break;
      const a = audio.subarray(Math.max(0, Math.floor((de - 0.1) * TAXA)), Math.min(audio.length, Math.ceil((ate + 0.1) * TAXA)));
      const resto = VOZ_MAX_S * TAXA - total;
      pedacos.push(a.subarray(0, resto), silencio(0.2));
      total += Math.min(a.length, resto);
    }
    if (total < VOZ_MIN_S * TAXA) continue;
    const ja = achados.get(nome);
    if (!ja || ja.segundos < total / TAXA) achados.set(nome, { nome, audio: juntar(pedacos), segundos: +(total / TAXA).toFixed(1) });
  }
  return [...achados.values()];
}

// ── blocos da reunião: [vozes cadastradas][silêncio][bloco] ───────────────────
export function blocosDeAudio(partes: Parte[]): Parte[][] {
  const out: Parte[][] = [];
  let atual: Parte[] = [], ini = 0, fim = 0;
  for (const p of partes) {
    const dur = (p.bytes / TAXA) * 1000;
    const continua = atual.length && p.ms - fim < 3000 && p.ms + dur - ini <= BLOCO_S * 1000;
    if (!continua) { if (atual.length) out.push(atual); atual = []; ini = p.ms; }
    atual.push(p);
    fim = p.ms + dur;
  }
  if (atual.length) out.push(atual);
  return out;
}

export function comPrefixo(vozes: Voz[], bloco: Uint8Array) {
  const partes: Uint8Array[] = [];
  const marcas: Array<{ nome: string; de: number; ate: number }> = [];
  let pos = 0;
  for (const v of vozes) {
    const a = v.audio.subarray(0, VOZ_MAX_S * TAXA);
    const s = silencio(0.6);
    marcas.push({ nome: v.nome, de: pos / TAXA, ate: (pos + a.length) / TAXA });
    partes.push(a, s);
    pos += a.length + s.length;
  }
  const s = silencio(1.5);
  partes.push(s, bloco);
  pos += s.length;
  return { audio: juntar(partes), marcas, inicio: pos / TAXA };
}

// falante → nome: a voz que domina o trecho cadastrado de cada pessoa
export function nomesDasVozes(palavras: Palavra[], marcas: Array<{ nome: string; de: number; ate: number }>) {
  const pares: Array<{ nome: string; spk: string; n: number }> = [];
  for (const m of marcas) {
    const cont = new Map<string, number>();
    for (const p of palavras) if (p.de >= m.de - 0.2 && p.ate <= m.ate + 0.5) cont.set(p.spk, (cont.get(p.spk) ?? 0) + 1);
    let spk = "", n = 0, total = 0;
    for (const [s, c] of cont) { total += c; if (c > n) { n = c; spk = s; } }
    if (spk && n >= 2 && n / total >= 0.6) pares.push({ nome: m.nome, spk, n });
  }
  pares.sort((a, b) => b.n - a.n);
  const mapa = new Map<string, string>();
  for (const p of pares) if (!mapa.has(p.spk) && ![...mapa.values()].includes(p.nome)) mapa.set(p.spk, p.nome);
  return mapa;
}

// palavras do bloco → falas com nome ("Sam" nos intervalos em que o Sam falou)
export function falasDoBloco(palavras: Palavra[], mapa: Map<string, string>, inicio: number, msBloco: number, sam: Array<[number, number]>): Linha[] {
  const outros = new Map<string, string>();
  const linhas: Linha[] = [];
  for (const p of palavras) {
    if (p.de < inicio - 0.3) continue; // prefixo das vozes cadastradas
    const ms = msBloco + Math.round((p.de - inicio) * 1000);
    const fim = msBloco + Math.round((p.ate - inicio) * 1000);
    let quem = mapa.get(p.spk);
    if (sam.some(([a, b]) => ms >= a - 300 && ms <= b + 300)) quem = "Sam";
    if (!quem) {
      if (!outros.has(p.spk)) outros.set(p.spk, `Pessoa ${String.fromCharCode(65 + outros.size)}`);
      quem = outros.get(p.spk)!;
    }
    const u = linhas[linhas.length - 1];
    if (u && u.quem === quem && ms - u.fim < 4000 && u.texto.length < 600) { u.texto += " " + p.texto; u.fim = fim; }
    else linhas.push({ ms, fim, quem, texto: p.texto });
  }
  return linhas;
}
