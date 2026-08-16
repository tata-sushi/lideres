// ─────────────────────────────────────────────────────────────────────────────
// rhid-banco-horas-sync — RHID → dp_rh.banco_horas (substitui o Apps Script BH)
//
// Snapshot semanal (semana anterior seg→dom, data = domingo). Por pessoa:
//  • saldoBancoFinalDia → saldo líquido → Positivas (>=0) ou Negativas (<0)
//  • soma de saldoBancoAjustado na semana (≠0) → linha "Pagas" (valor absoluto)
//  • desligado (estava ativo na última semana, não está mais):
//        saldo>=0 → "Pagas" ; saldo<0 → "Perdidas"
// Salário/custo NÃO vêm daqui — a RPC banco_horas_sync congela usando
// cargos_salarios (via profiles.cargo_id). Identidade deriva do profiles no read.
// Login: secrets RHID_EMAIL / RHID_PASSWORD (mesmos das outras syncs).
//
// Body (POST, opcional): { dataIni, dataFinal }  ("YYYY-MM-DD", override)
// ─────────────────────────────────────────────────────────────────────────────
import { createClient } from "jsr:@supabase/supabase-js@2";

const RHID = "https://rhid.com.br/v2/api.svc";
const PAGE_SIZE = 100;
const CONCURRENCY = 6;

const NOMES_EXCLUIR      = ["ID2ID", "CLOUD", "ID2"];
const MATRICULAS_ZERO    = ["24241", "24134", "24135"];
const MATRICULAS_EXCLUIR = ["0","1","2","3","4","5","7","8","24077","24090","24092","24164","24174","24194","24600"];

function normMat(v: unknown): string { return String(v ?? "").trim().replace(/^0+/, ""); }

function paraMinutos(v: unknown): number {
  if (v === null || v === undefined || v === "") return 0;
  if (typeof v === "number") return Math.round(v);
  if (typeof v === "string") {
    const m = v.match(/^(-?)(\d+):(\d{2})(?::(\d{2}))?$/);
    if (m) return (m[1] === "-" ? -1 : 1) * (parseInt(m[2]) * 60 + parseInt(m[3]));
    const n = parseFloat(v);
    return isNaN(n) ? 0 : Math.round(n);
  }
  return 0;
}

function periodoSemanaAnterior(): { dataIni: string; dataFinal: string } {
  const now = new Date(Date.now() - 3 * 3600 * 1000); // ~America/Sao_Paulo
  const dow = now.getUTCDay();                          // 0=Dom..6=Sáb
  const dias = dow === 0 ? 7 : dow;
  const dom = new Date(now); dom.setUTCDate(now.getUTCDate() - dias); // domingo passado
  const seg = new Date(dom); seg.setUTCDate(dom.getUTCDate() - 6);    // segunda da mesma semana
  const f = (d: Date) => d.toISOString().slice(0, 10);
  return { dataIni: f(seg), dataFinal: f(dom) };
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
function excluir(nome: string, mt: string): boolean {
  const nm = (nome || "").toUpperCase();
  if (NOMES_EXCLUIR.some((n) => nm.includes(n.toUpperCase()))) return true;
  if (!mt || MATRICULAS_EXCLUIR.includes(mt)) return true;
  return false;
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
    const dataRef = per.dataFinal; // domingo

    const token = await login();
    if (!token) return json({ error: "rhid_login_failed (checar secrets RHID_EMAIL/RHID_PASSWORD)" }, 500);

    const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // ativos da última semana (p/ detectar desligados)
    const { data: prevData, error: prevErr } = await supa.rpc("banco_horas_prev_ativos");
    if (prevErr) return json({ error: "prev_ativos: " + prevErr.message }, 500);
    const prevAtivos = new Set<string>((prevData || []).map((x: any) => String(typeof x === "string" ? x : x.banco_horas_prev_ativos)));

    const pessoas = await getAllPersons(token);
    const ativos = pessoas.filter((p) => p.status === 1 && !excluir(p.name, normMat(p.registration)));
    const ativosMt = new Set<string>(ativos.map((p) => normMat(p.registration)));

    const rows: any[] = [];

    // ── Ativos ──
    const parciaisAtivos = await mapPool(ativos, CONCURRENCY, async (p) => {
      const mt = normMat(p.registration);
      const out: any[] = [];
      if (MATRICULAS_ZERO.includes(mt)) { out.push({ data: dataRef, matricula: mt, tipo: "Negativas", saldo: 0 }); return out; }
      const dias = await getApuracao(token, p.id, per.dataIni, per.dataFinal);
      if (!dias || dias.length === 0) { out.push({ data: dataRef, matricula: mt, tipo: "Positivas", saldo: 0 }); return out; }
      const saldoMin = paraMinutos(dias[dias.length - 1].saldoBancoFinalDia);
      out.push({ data: dataRef, matricula: mt, tipo: saldoMin >= 0 ? "Positivas" : "Negativas", saldo: saldoMin / 60 });
      let ajuste = 0;
      for (const d of dias) { const v = paraMinutos(d.saldoBancoAjustado); if (v !== 0) ajuste += v; }
      if (ajuste !== 0) out.push({ data: dataRef, matricula: mt, tipo: "Pagas", saldo: Math.abs(ajuste) / 60 });
      return out;
    });
    for (const arr of parciaisAtivos) for (const r of arr) rows.push(r);

    // ── Desligados (ativo na última semana, agora não é mais status 1) ──
    const desligados = pessoas.filter((p) => {
      const mt = normMat(p.registration);
      return prevAtivos.has(mt) && !ativosMt.has(mt) && !excluir(p.name, mt);
    });
    const parciaisDesl = await mapPool(desligados, CONCURRENCY, async (p) => {
      const mt = normMat(p.registration);
      const dias = await getApuracao(token, p.id, per.dataIni, per.dataFinal);
      let saldoMin = 0;
      if (dias && dias.length > 0) saldoMin = paraMinutos(dias[dias.length - 1].saldoBancoFinalDia);
      return { data: dataRef, matricula: mt, tipo: saldoMin >= 0 ? "Pagas" : "Perdidas", saldo: saldoMin / 60 };
    });
    for (const r of parciaisDesl) rows.push(r);

    // Gravar (a RPC congela salário/custo via cargos_salarios; on conflict do nothing)
    let gravadas = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const { data, error } = await supa.rpc("banco_horas_sync", { p_rows: rows.slice(i, i + 500) });
      if (error) return json({ error: "banco_horas_sync: " + error.message, at: i }, 500);
      gravadas += (data as number) || 0;
    }

    return json({ ok: true, periodo: per, dataRef, ativos: ativos.length, desligados: desligados.length, linhas: rows.length, gravadas, ms: Date.now() - t0 });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json" } });
}
