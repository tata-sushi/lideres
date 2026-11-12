import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "jsr:@supabase/supabase-js@2"

// Exclusão DEFINITIVA de uma admissão: a RPC apaga o registro (respostas e
// documentos saem por FK ON DELETE CASCADE) e devolve os caminhos dos arquivos;
// aqui removemos esses arquivos do Storage.
//   POST { token }   (verify_jwt: só RH autenticado dispara)

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
}
const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: CORS })
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i


// ── Porta (skill controle-de-acessos): quem chama precisa estar logado e ter o botão do catálogo.
// Só depois disso entra o service role.
async function conferirBotao(req: Request, botoes: string[]): Promise<Response | null> {
  const auth = req.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return json({ ok: false, erro: "sem_login" }, 401);
  const quem = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } }, auth: { persistSession: false },
  });
  for (const b of botoes) {
    const { data, error } = await quem.schema("tata_plus").rpc("pode_botao", { p_aba_id: b });
    if (!error && data === true) return null;
  }
  return json({ ok: false, erro: "sem_permissao" }, 403);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS })
  if (req.method !== "POST")   return json({ ok:false, motivo:"metodo" }, 405)
  { const neg = await conferirBotao(req, ["governanca-kpis-rh-admissao::excluir-ficha"]); if (neg) return neg; }
  try {
    const SUPA_URL = Deno.env.get("SUPABASE_URL")!
    const SERVICE  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    let b: any = {}; try { b = await req.json() } catch {}
    const token = String(b.token || "").trim()
    if (!token || !UUID_RE.test(token)) return json({ ok:false, motivo:"token_invalido" })

    const db = createClient(SUPA_URL, SERVICE, { auth: { persistSession: false } })

    // 1) apaga o registro (cascade) e recebe de volta os arquivos p/ remover do Storage
    const { data: res, error: eDel } = await db.schema("tata_plus").rpc("admissao_excluir", { p_token: token })
    if (eDel) return json({ ok:false, motivo:"falha_exclusao", erro: eDel.message })
    if (!res || !res.ok) return json(res || { ok:false, motivo:"desconhecido" })

    // 2) remove os arquivos do Storage (agrupando por bucket); best-effort
    let arquivos_removidos = 0
    const porBucket: Record<string, string[]> = {}
    for (const a of ((res.arquivos || []) as any[])) {
      const path = String(a?.path || "").trim()
      if (!path) continue
      const bucket = String(a?.bucket || "admissao-docs").trim() || "admissao-docs"
      ;(porBucket[bucket] = porBucket[bucket] || []).push(path)
    }
    for (const bucket of Object.keys(porBucket)) {
      const paths = porBucket[bucket]
      if (!paths.length) continue
      const { data: rm, error: eRm } = await db.storage.from(bucket).remove(paths)
      if (!eRm && Array.isArray(rm)) arquivos_removidos += rm.length
    }

    return json({ ...res, arquivos_removidos })
  } catch (e: any) {
    return json({ ok:false, motivo:"erro", erro: String(e?.message || e) })
  }
})
