// ─────────────────────────────────────────────────────────────────────────────
// rhid-feriados-sync — RHID → dp_rh.feriados_horas (substitui relatórioFeriados)
//
// Para o período (semana anterior por padrão): detecta feriados, e para cada
// ativo que trabalhou no feriado grava horas trabalhadas + saldo do banco de
// horas no dia anterior. Upsert via public.feriado_sync (regra: saldo negativo
// em linha NOVA → "Não tem direito"; preserva a decisão do líder no que já existe).
// Unidade/departamento/nome vêm do profiles. Login: secrets RHID_EMAIL/RHID_PASSWORD.
//
// Body (POST, opcional): { dataIni, dataFinal }  ("YYYY-MM-DD", override do período)
// ─────────────────────────────────────────────────────────────────────────────
import { createClient } from "jsr:@supabase/supabase-js@2";

const RHID = "https://rhid.com.br/v2/api.svc";
const PAGE_SIZE = 100;
const CONCURRENCY = 8;

const NOMES_EXCLUIR = ["ID2ID", "CLOUD", "ID2"];
const MATRICULAS_EXCLUIR = ["0","1","2","3","4","5","7","8","24077","24090","24092","24164","24174","24194","24600"];

function titleCase(s: string): string {
  if (!s) return "";
  const minus = ["de","da","do","das","dos","e","a","o"];
  return s.toLowerCase().replace(/\S+/g, (w, i) =>
    (i === 0 || !minus.includes(w)) ? w.charAt(0).toUpperCase() + w.slice(1) : w);
}
function normMat(v: unknown): string { return String(v ?? "").trim().replace(/^0+/, ""); }

function fmtHoras(min: number): string {
  const h = Math.floor(min / 60), m = min % 60;
  return h + "h" + (m > 0 ? String(m).padStart(2, "0") + "m" : "");
}
function fmtSaldo(min: number): string {
  const s = min < 0 ? "-" : "+", a = Math.abs(min);
  return s + Math.floor(a / 60) + "h" + String(a % 60).padStart(2, "0") + "m";
}

function periodoSemanaAnterior(): { dataIni: string; dataFinal: string } {
  const now = new Date(Date.now() - 3 * 3600 * 1000);
  const dom = new Date(now); dom.setUTCDate(now.getUTCDate() - now.getUTCDay());
  const seg = new Date(dom); seg.setUTCDate(dom.getUTCDate() - 6);
  const f = (d: Date) => d.toISOString().slice(0, 10);
  return { dataIni: f(seg), dataFinal: f(dom) };
}
function diasDoPeriodo(ini: string, fim: string): string[] {
  const out: string[] = [];
  const d = new Date(ini + "T00:00:00Z"), end = new Date(fim + "T00:00:00Z");
  while (d <= end) { out.push(d.toISOString().slice(0, 10)); d.setUTCDate(d.getUTCDate() + 1); }
  return out;
}
function diaAnterior(iso: string): string {
  const d = new Date(iso + "T00:00:00Z"); d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
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
async function getAllPersons(token: string): Promise<any[]> {
  const pessoas: any[] = []; let start = 0;
  while (true) {
    const r = await fetch(`${RHID}/person?start=${start}&length=${PAGE_SIZE}`, { headers: { Authorization: "Bearer " + token } });
    if (!r.ok) break;
    let data: any = await r.json(); if (typeof data === "string") data = JSON.parse(data);
    const arr: any[] = data.records || data.data || (Array.isArray(data) ? data : []);
    if (arr.length === 0) break;
    for (const p of arr) pessoas.push({ id: p.id, name: p.name || ("id_" + p.id), registration: String(p.registration || ""), status: p.status });
    if (arr.length < PAGE_SIZE) break;
    start += PAGE_SIZE;
  }
  return pessoas;
}
async function getApuracao(token: string, idPerson: number, ini: string, fim: string): Promise<any[] | null> {
  const url = `${RHID}/apuracao_ponto?dataIni=${encodeURIComponent(ini)}&dataFinal=${encodeURIComponent(fim)}&idPerson=${idPerson}`;
  const r = await fetch(url, { headers: { Authorization: "Bearer " + token } });
  if (!r.ok) return null;
  let parsed: any = await r.json(); if (typeof parsed === "string") parsed = JSON.parse(parsed);
  return Array.isArray(parsed) ? parsed : (parsed.records || parsed.data || []);
}
function elegivel(p: any): boolean {
  if (p.status !== 1) return false;
  const nm = (p.name || "").toUpperCase();
  if (NOMES_EXCLUIR.some((n) => nm.includes(n.toUpperCase()))) return false;
  const mt = normMat(p.registration);
  if (!mt || MATRICULAS_EXCLUIR.includes(mt)) return false;
  return true;
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
    const body = await req.json().catch(() => ({}));
    const per = (body.dataIni && body.dataFinal) ? { dataIni: body.dataIni, dataFinal: body.dataFinal } : periodoSemanaAnterior();

    const token = await login();
    if (!token) return json({ error: "rhid_login_failed (checar secrets RHID_EMAIL/RHID_PASSWORD)" }, 500);

    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const pmap = new Map<string, any>();
    const { data: profs, error: perr } = await supa.schema("tata_plus").from("profiles").select("matricula,nome,unidade,departamento");
    if (perr) return json({ error: "profiles: " + perr.message }, 500);
    for (const p of (profs || [])) pmap.set(String(p.matricula), p);

    const ativos = (await getAllPersons(token)).filter(elegivel);
    if (ativos.length === 0) return json({ ok: true, feriados: [], linhas: 0, gravadas: 0, aviso: "sem ativos" });

    // Detectar feriados no período (sonda com o primeiro ativo)
    const feriados: { data: string; nome: string }[] = [];
    for (const dia of diasDoPeriodo(per.dataIni, per.dataFinal)) {
      const ap = await getApuracao(token, ativos[0].id, dia, dia);
      const reg = ap && ap[0];
      if (reg && reg.isHoliday === 1 && reg.holiday && reg.holiday.name) feriados.push({ data: dia, nome: reg.holiday.name });
    }
    if (feriados.length === 0) return json({ ok: true, periodo: per, feriados: [], linhas: 0, gravadas: 0, ms: Date.now() - t0 });

    const rows: any[] = [];
    for (const fer of feriados) {
      const anterior = diaAnterior(fer.data);
      const parciais = await mapPool(ativos, CONCURRENCY, async (p) => {
        const dias = await getApuracao(token, p.id, fer.data, fer.data);
        const dia = dias && dias[0];
        if (!dia || !dia.totalHorasTrabalhadas || dia.totalHorasTrabalhadas === 0) return null;
        let saldo = "";
        const ant = await getApuracao(token, p.id, anterior, anterior);
        if (ant && ant[0]) saldo = fmtSaldo(Math.round(ant[0].saldoBancoFinalDia || 0));
        const mt = normMat(p.registration);
        const prof = pmap.get(mt) || {};
        return {
          matricula: mt,
          colaborador: prof.nome || titleCase(p.name || ""),
          unidade: prof.unidade || "",
          departamento: prof.departamento || "",
          data_feriado: fer.data,
          feriado_nome: fer.nome,
          horas: fmtHoras(dia.totalHorasTrabalhadas),
          saldo_anterior: saldo,
        };
      });
      for (const r of parciais) if (r) rows.push(r);
    }

    let gravadas = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const { data, error } = await supa.rpc("feriado_sync", { p_rows: rows.slice(i, i + 500) });
      if (error) return json({ error: "feriado_sync: " + error.message, at: i }, 500);
      gravadas += (data as number) || 0;
    }

    return json({ ok: true, periodo: per, feriados, ativos: ativos.length, linhas: rows.length, gravadas, ms: Date.now() - t0 });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json" } });
}
