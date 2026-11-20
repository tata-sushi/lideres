// ─────────────────────────────────────────────────────────────────────────────
// rhid-ponto-sync — RHiD → dp_rh.ponto_dia (marcações de ponto por pessoa/dia)
//
// Para cada pessoa (ativos/bloqueados + quem saiu dentro do período, via public.ponto_dia_pessoas),
// chama a apuracao_ponto do RHiD no período e grava 1 linha por dia:
//   • marcacao_1..6 = batidas do dia em ordem (dateTime local de SP), sem as ocultas
//   • jornada_rhid  = horário contratual do RHiD ([{entrada, saida}], formato de escala_dias.marcacoes)
//   • números da apuração do RHiD (previsto, trabalhado, extra, falta/atraso, banco de horas) p/ conferência
// Dia sem batida, sem jornada, sem falta e sem justificativa não é gravado.
// Upsert via public.ponto_dia_sync (atualiza se o RHiD mudou algo depois).
//
// O RHiD não devolve todas as pessoas numa chamada (apuracao_ponto exige idPerson):
// ~160 chamadas por rodada, 6 em paralelo. Período longo é quebrado em blocos de 31 dias.
//
// Chamada: POST …/rhid-ponto-sync?k=<portal_secret>   (mesmo segredo do agente-portal)
// Body (opcional): { dataIni, dataFinal, matriculas: ["24740", …] }
//   sem período → ontem e hoje (fecha ontem e traz o parcial de hoje)
// Login RHiD: secrets RHID_EMAIL / RHID_PASSWORD (mesmos das outras syncs).
// ─────────────────────────────────────────────────────────────────────────────
import { createClient } from "jsr:@supabase/supabase-js@2";

const RHID = "https://rhid.com.br/v2/api.svc";
const CONCURRENCY = 6;
const BLOCO_DIAS = 31;
const MAX_COLUNAS = 6;

function paraMinutos(v: unknown): number | null {
  if (v === null || v === undefined || v === "") return null;
  if (typeof v === "number") return Math.round(v);
  if (typeof v === "string") {
    const m = v.match(/^(-?)(\d+):(\d{2})(?::(\d{2}))?$/);
    if (m) return (m[1] === "-" ? -1 : 1) * (parseInt(m[2]) * 60 + parseInt(m[3]));
    const n = parseFloat(v);
    return isNaN(n) ? null : Math.round(n);
  }
  return null;
}

// "2026-11-17T15:03:00" (local SP) → "2026-11-17 15:03:00"
function horaLocal(v: unknown): string | null {
  const s = String(v ?? "");
  const m = s.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::(\d{2}))?/);
  if (!m || m[1].startsWith("0001")) return null;
  return `${m[1]} ${m[2]}:${m[3] ?? "00"}`;
}

// "12:00-15:00\r\n18:00-22:20" → [{entrada:"12:00", saida:"15:00"}, {entrada:"18:00", saida:"22:20"}]
function jornada(str: unknown): { entrada: string; saida: string }[] | null {
  const pares = String(str ?? "").split(/[\r\n]+/).map((l) => l.trim()).filter(Boolean)
    .map((l) => l.match(/^(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})$/))
    .filter((m): m is RegExpMatchArray => !!m)
    .map((m) => ({ entrada: m[1].padStart(5, "0"), saida: m[2].padStart(5, "0") }));
  return pares.length ? pares : null;
}

function hojeSP(): string {
  return new Date(Date.now() - 3 * 3600 * 1000).toISOString().slice(0, 10);
}
function somaDias(iso: string, n: number): string {
  const d = new Date(iso + "T00:00:00Z"); d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
function blocos(ini: string, fim: string): [string, string][] {
  const out: [string, string][] = [];
  let a = ini;
  while (a <= fim) {
    const b = somaDias(a, BLOCO_DIAS - 1);
    out.push([a, b < fim ? b : fim]);
    a = somaDias(b, 1);
  }
  return out;
}

async function login(): Promise<string | null> {
  const email = Deno.env.get("RHID_EMAIL"), password = Deno.env.get("RHID_PASSWORD");
  if (!email || !password) return null;
  const r = await fetch(`${RHID}/login`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, domain: "" }),
  });
  if (!r.ok) return null;
  const d = await r.json();
  return d.accessToken || d.token || d.access_token || null;
}

async function getApuracao(token: string, idPerson: string, ini: string, fim: string): Promise<any[] | null> {
  const url = `${RHID}/apuracao_ponto?dataIni=${ini}&dataFinal=${fim}&idPerson=${encodeURIComponent(idPerson)}`;
  const r = await fetch(url, { headers: { Authorization: "Bearer " + token } });
  if (!r.ok) return null;
  let parsed: any = await r.json();
  if (typeof parsed === "string") parsed = JSON.parse(parsed);
  const arr = Array.isArray(parsed) ? parsed : (parsed.records || parsed.data || []);
  return arr.filter((d: any) => !d.error);
}

function linhaDoDia(matricula: string, d: any): any | null {
  const data = horaLocal(d.date)?.slice(0, 10);
  if (!data) return null;
  const batidas = (d.listAfdtManutencao || [])
    .filter((x: any) => !x.oculto)
    .map((x: any) => horaLocal(x.dateTime))
    .filter((x: string | null): x is string => !!x)
    .sort();
  const jor = jornada(d.strHorarioContratualSimples);
  const just = (d.listAfdtManutencao || [])
    .map((x: any) => x.abreviationJustification)
    .find((a: any) => a && String(a).trim() !== "" && a !== "null") || null;
  const falta = !!d.faltaDiaInteiro;
  if (batidas.length === 0 && !jor && !falta && !just) return null;

  const row: any = {
    matricula, data,
    qtd_marcacoes: batidas.length,
    jornada_rhid: jor,
    folga_rhid: !!d.folga,
    feriado: d.isHoliday === 1,
    falta_dia: falta,
    previsto_min: paraMinutos(d.horasUteis),
    trabalhado_min: paraMinutos(d.totalHorasTrabalhadas),
    extra_min: paraMinutos(d.horasExtrasCalculadas),
    falta_atraso_min: paraMinutos(d.horasFaltaAtraso),
    bh_dia_min: paraMinutos(d.saldoBancoCredDeb),
    bh_final_min: paraMinutos(d.saldoBancoFinalDia),
    justificativa: just ? String(just).trim() : null,
    alerta_rhid: d.toolTipAlert ? String(d.toolTipAlert).trim() : null,
  };
  for (let i = 0; i < MAX_COLUNAS; i++) row[`marcacao_${i + 1}`] = batidas[i] ?? null;
  return row;
}

async function mapPool<T, R>(items: T[], size: number, fn: (x: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length); let i = 0;
  await Promise.all(Array.from({ length: Math.min(size, items.length) }, async () => {
    while (i < items.length) { const idx = i++; out[idx] = await fn(items[idx]); }
  }));
  return out;
}

Deno.serve(async (req: Request) => {
  const t0 = Date.now();
  try {
    const url = new URL(req.url);
    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { data: segredo } = await supa.schema("tata_plus").rpc("agente_segredo", { p_chave: "portal_secret" });
    if (!segredo || url.searchParams.get("k") !== segredo) return json({ ok: false, erro: "nao_autorizado" }, 401);

    const body = await req.json().catch(() => ({}));
    const hoje = hojeSP();
    const dataIni: string = body.dataIni || somaDias(hoje, -1);
    const dataFinal: string = body.dataFinal || hoje;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dataIni) || !/^\d{4}-\d{2}-\d{2}$/.test(dataFinal) || dataIni > dataFinal) {
      return json({ ok: false, erro: "periodo_invalido", dataIni, dataFinal }, 400);
    }

    const { data: pessoasDb, error: pErr } = await supa.rpc("ponto_dia_pessoas", { p_ini: dataIni });
    if (pErr) return json({ ok: false, erro: "ponto_dia_pessoas: " + pErr.message }, 500);
    let pessoas: { matricula: string; id_pessoa: string }[] = pessoasDb || [];
    if (Array.isArray(body.matriculas) && body.matriculas.length) {
      const so = new Set(body.matriculas.map(String));
      pessoas = pessoas.filter((p) => so.has(p.matricula));
    }

    const token = await login();
    if (!token) return json({ ok: false, erro: "rhid_login_failed (checar secrets RHID_EMAIL/RHID_PASSWORD)" }, 500);

    const periodos = blocos(dataIni, dataFinal);
    let falhas = 0;
    const porPessoa = await mapPool(pessoas, CONCURRENCY, async (p) => {
      const rows: any[] = [];
      for (const [a, b] of periodos) {
        const dias = await getApuracao(token, p.id_pessoa, a, b);
        if (!dias) { falhas++; continue; }
        for (const d of dias) { const r = linhaDoDia(p.matricula, d); if (r) rows.push(r); }
      }
      return rows;
    });
    const rows = porPessoa.flat();

    let gravadas = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const { data, error } = await supa.rpc("ponto_dia_sync", { p_rows: rows.slice(i, i + 500) });
      if (error) return json({ ok: false, erro: "ponto_dia_sync: " + error.message, at: i }, 500);
      gravadas += (data as number) || 0;
    }

    const mais6 = rows.filter((r) => r.qtd_marcacoes > MAX_COLUNAS).length;
    return json({ ok: true, periodo: { dataIni, dataFinal }, pessoas: pessoas.length, falhas_rhid: falhas,
      linhas: rows.length, gravadas, dias_com_mais_de_6: mais6, ms: Date.now() - t0 });
  } catch (e) {
    return json({ ok: false, erro: String(e) }, 500);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json" } });
}
