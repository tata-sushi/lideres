// ─────────────────────────────────────────────────────────────────────────────
// rhid-ausencias-sync — RHID → dp_rh.ausencias (substitui os Apps Scripts)
//
// Numa passada só, para o período (semana anterior por padrão):
//   • ausência justificada (idJustification) → tipo mapeado (Atestado, INSS, …)
//   • falta dia inteiro (faltaDiaInteiro)     → "Falta"
// Unidade/departamento/status vêm do profiles. Upsert via public.ausencia_sync
// (preserva a devolutiva do líder). Login RHID vem dos secrets RHID_EMAIL/RHID_PASSWORD.
//
// Body (POST, opcional): { dataIni, dataFinal, personLimit }
//   dataIni/dataFinal : "YYYY-MM-DD" (override do período)
//   personLimit       : nº p/ processar só as N primeiras pessoas (teste rápido)
// ─────────────────────────────────────────────────────────────────────────────
import { createClient } from "jsr:@supabase/supabase-js@2";

const RHID = "https://rhid.com.br/v2/api.svc";
const PAGE_SIZE = 100;
const CONCURRENCY = 6;

const NOMES_EXCLUIR = ["ID2ID", "CLOUD", "ID2"];
const MATRICULAS_EXCLUIR = ["0"];

const MAPA_TIPOS: Record<string, string> = {
  "falta": "Falta",
  "medico": "Atestado Médico",
  "atestado médico": "Atestado Médico",
  "atestado medico": "Atestado Médico",
  "afastamento inss": "Afastamento INSS",
  "suspensão": "Suspensão",
  "suspensao": "Suspensão",
  "suspensão de contrato": "Suspensão de Contrato",
  "suspensao de contrato": "Suspensão de Contrato",
  "licença casamento": "Licença Casamento",
  "licenca casamento": "Licença Casamento",
  "licença maternidade": "Licença Maternidade",
  "licenca maternidade": "Licença Maternidade",
  "licença nojo": "Licença Nojo",
  "licenca nojo": "Licença Nojo",
  "licença paternidade": "Licença Paternidade",
  "licenca paternidade": "Licença Paternidade",
  "acompanhamento familiar": "Acompanhamento Familiar",
  "declaração de horas": "Declaração de Horas",
  "declaracao de horas": "Declaração de Horas",
};

function titleCase(s: string): string {
  if (!s) return "";
  const minus = ["de", "da", "do", "das", "dos", "e", "a", "o"];
  return s.toLowerCase().replace(/\S+/g, (w, i) =>
    (i === 0 || !minus.includes(w)) ? w.charAt(0).toUpperCase() + w.slice(1) : w
  );
}

function traduzStatus(s: unknown): string {
  return s === 1 ? "Ativo" : s === 0 ? "Inativo" : s === 2 ? "Bloqueado" : String(s ?? "—");
}

function fmtISO(v: unknown): string | null {
  if (!v) return null;
  const s = String(v);
  let m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = s.match(/\/Date\((-?\d+)([+-]\d+)?\)\//);
  if (m) return new Date(parseInt(m[1], 10)).toISOString().slice(0, 10);
  return s.slice(0, 10);
}

function periodoSemanaAnterior(): { dataIni: string; dataFinal: string } {
  const now = new Date(Date.now() - 3 * 3600 * 1000); // ~America/Sao_Paulo
  const dom = new Date(now); dom.setUTCDate(now.getUTCDate() - now.getUTCDay());
  const seg = new Date(dom); seg.setUTCDate(dom.getUTCDate() - 6);
  const f = (d: Date) => d.toISOString().slice(0, 10);
  return { dataIni: f(seg), dataFinal: f(dom) };
}

async function login(): Promise<string | null> {
  const email = Deno.env.get("RHID_EMAIL");
  const password = Deno.env.get("RHID_PASSWORD");
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
  const pessoas: any[] = [];
  let start = 0;
  while (true) {
    const r = await fetch(`${RHID}/person?start=${start}&length=${PAGE_SIZE}`, {
      headers: { Authorization: "Bearer " + token },
    });
    if (!r.ok) break;
    let data: any = await r.json();
    if (typeof data === "string") data = JSON.parse(data);
    const arr: any[] = data.records || data.data || (Array.isArray(data) ? data : []);
    if (arr.length === 0) break;
    for (const p of arr) {
      pessoas.push({ id: p.id, name: p.name || ("id_" + p.id), registration: String(p.registration || ""), status: p.status });
    }
    if (arr.length < PAGE_SIZE) break;
    start += PAGE_SIZE;
  }
  return pessoas;
}

async function getApuracao(token: string, idPerson: number, ini: string, fim: string): Promise<any[] | null> {
  const url = `${RHID}/apuracao_ponto?dataIni=${encodeURIComponent(ini)}&dataFinal=${encodeURIComponent(fim)}&idPerson=${idPerson}`;
  const r = await fetch(url, { headers: { Authorization: "Bearer " + token } });
  if (!r.ok) return null;
  let parsed: any = await r.json();
  if (typeof parsed === "string") parsed = JSON.parse(parsed);
  return Array.isArray(parsed) ? parsed : (parsed.records || parsed.data || []);
}

// Porta de _extrairTipoAusencia3
function extrairTipo(dia: any): string | null {
  const lista = dia.listAfdtManutencao;
  if (!lista || lista.length === 0) return null;
  for (const it of lista) {
    const abrev = it.abreviationJustification;
    if (abrev && String(abrev).trim() !== "" && abrev !== "null") {
      const pad = MAPA_TIPOS[String(abrev).trim().toLowerCase()];
      if (pad) return pad;
    }
  }
  for (const it of lista) {
    if (!it.afdtLogs || it.afdtLogs.length === 0) continue;
    for (const log of it.afdtLogs) {
      const det = log.detalheDiferencaConsiderada;
      if (!det || String(det).trim() === "") continue;
      if (/horário previsto alterado/i.test(det)) continue;
      if (/tolerância|tolerancia/i.test(det)) continue;
      if (/batida/i.test(det)) continue;
      if (/descontada/i.test(det)) continue;
      if (/diferença|diferenca/i.test(det)) continue;
      const pad = MAPA_TIPOS[String(det).trim().toLowerCase()];
      if (pad) return pad;
    }
  }
  return null;
}

function elegivel(p: any): boolean {
  const nm = (p.name || "").toUpperCase();
  if (!String(p.registration || "").trim()) return false;
  if (NOMES_EXCLUIR.some((n) => nm.includes(n.toUpperCase()))) return false;
  if (MATRICULAS_EXCLUIR.includes(String(p.registration || "").trim())) return false;
  return true;
}

async function mapPool<T, R>(items: T[], size: number, fn: (x: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let i = 0;
  const workers = Array.from({ length: Math.min(size, items.length) }, async () => {
    while (i < items.length) { const idx = i++; out[idx] = await fn(items[idx]); }
  });
  await Promise.all(workers);
  return out;
}

Deno.serve(async (req: Request) => {
  const t0 = Date.now();
  try {
    const body = await req.json().catch(() => ({}));
    const per = (body.dataIni && body.dataFinal)
      ? { dataIni: body.dataIni, dataFinal: body.dataFinal }
      : periodoSemanaAnterior();

    const token = await login();
    if (!token) return json({ error: "rhid_login_failed (checar secrets RHID_EMAIL/RHID_PASSWORD)" }, 500);

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // profiles: matrícula → { nome, unidade, departamento, status }
    const pmap = new Map<string, any>();
    const { data: profs, error: perr } = await supa.schema("tata_plus")
      .from("profiles").select("matricula,nome,unidade,departamento,status");
    if (perr) return json({ error: "profiles: " + perr.message }, 500);
    for (const p of (profs || [])) pmap.set(String(p.matricula), p);

    let persons = (await getAllPersons(token)).filter(elegivel);
    if (body.personLimit) persons = persons.slice(0, body.personLimit);

    const perPerson = await mapPool(persons, CONCURRENCY, async (p) => {
      const dias = await getApuracao(token, p.id, per.dataIni, per.dataFinal);
      const rows: any[] = [];
      if (dias) for (const dia of dias) {
        const lista = dia.listAfdtManutencao || [];
        const hasJust = lista.some((it: any) => it.idJustification && it.idJustification !== 0);
        let tipo: string | null = null;
        if (hasJust) tipo = extrairTipo(dia);
        if (!tipo && dia.faltaDiaInteiro) tipo = "Falta";
        if (!tipo) continue;
        const dataISO = fmtISO(dia.date || dia.dateTimeInicio);
        if (!dataISO) continue;
        const mt = String(p.registration).trim().replace(/^0+/, ""); // igual à sync-rhid (profiles)
        const prof = pmap.get(mt) || {};
        rows.push({
          matricula: mt,
          colaborador: prof.nome || titleCase(p.name || ""),
          unidade: prof.unidade || "",
          departamento: prof.departamento || "",
          data_falta: dataISO,
          tipo,
          status: prof.status || traduzStatus(p.status),
        });
      }
      return rows;
    });

    // dedup por (matricula, data_falta) preferindo tipo != Falta
    const byKey = new Map<string, any>();
    for (const r of perPerson.flat()) {
      const k = r.matricula + "|" + r.data_falta;
      const cur = byKey.get(k);
      if (!cur || (cur.tipo === "Falta" && r.tipo !== "Falta")) byKey.set(k, r);
    }
    const rows = [...byKey.values()];

    let affected = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const chunk = rows.slice(i, i + 500);
      const { data, error } = await supa.rpc("ausencia_sync", { p_rows: chunk });
      if (error) return json({ error: "ausencia_sync: " + error.message, at: i }, 500);
      affected += (data as number) || 0;
    }

    return json({
      ok: true, periodo: per, pessoas: persons.length,
      linhas: rows.length, gravadas: affected, ms: Date.now() - t0,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status, headers: { "Content-Type": "application/json" },
  });
}
