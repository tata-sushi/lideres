import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "jsr:@supabase/supabase-js@2"

// Envio automático da ficha de admissão pro DP (via Resend), com os documentos como LINKS de download
// (signed URL 30 dias) — sem anexo, pra não esbarrar em limite de tamanho no destinatário.
//   POST { token }  (verify_jwt: só RH autenticado dispara)
// Config por secrets: RESEND_API_KEY, ADMISSAO_EMAIL_FROM, ADMISSAO_EMAIL_TO

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, apikey, authorization",
  "Content-Type": "application/json",
}
const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: CORS })
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const DIAS = 30, EXP = DIAS * 24 * 3600

const GRUPO_LABEL: Record<string,string> = { pessoais:"Dados pessoais", endereco:"Endereço", trabalho:"Trabalho e uniforme", bancario:"Dados bancários", dependente:"Dependentes", conducao:"Conduções (VT)" }
const GRUPO_ORDEM = ["pessoais","endereco","trabalho","bancario","dependente","conducao"]
function esc(s: unknown){ return String(s==null?"":s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[c] as string)) }


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
  { const neg = await conferirBotao(req, ["governanca-kpis-rh-admissao::enviar-ficha-dp"]); if (neg) return neg; }
  try {
    const RESEND = Deno.env.get("RESEND_API_KEY")
    const FROM   = Deno.env.get("ADMISSAO_EMAIL_FROM") || "Admissão Tatá <admissao@tatasushi.com.br>"
    const TO     = Deno.env.get("ADMISSAO_EMAIL_TO")   || "equipe5.dp@cadis.com.br"
    if (!RESEND) return json({ ok:false, motivo:"sem_config" })   // Resend ainda não configurado → front usa o fallback (Outlook web)

    const SUPA_URL = Deno.env.get("SUPABASE_URL")!
    const SERVICE  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    let b: any = {}; try { b = await req.json() } catch {}
    const token = String(b.token || "").trim()
    if (!token || !UUID_RE.test(token)) return json({ ok:false, motivo:"token_invalido" })

    const db = createClient(SUPA_URL, SERVICE, { auth: { persistSession: false } })
    const { data: ficha, error } = await db.schema("tata_plus").rpc("admissao_ficha_get", { p_token: token })
    if (error || !ficha || !ficha.admissao) return json({ ok:false, motivo:"nao_encontrado", erro: error?.message })

    const a = ficha.admissao || {}
    const resp = (ficha.respostas || []) as any[]
    const docs = (ficha.documentos || []) as any[]

    // corpo HTML: dados agrupados
    const byG: Record<string, any[]> = {}
    for (const r of resp) { if (r.grupo==="trabalho" && r.campo==="proposta") continue; (byG[r.grupo] = byG[r.grupo] || []).push(r) }
    const grupos = GRUPO_ORDEM.filter(g=>byG[g]).concat(Object.keys(byG).filter(g=>GRUPO_ORDEM.indexOf(g)<0))
    let html = `<div style="font-family:Arial,sans-serif;font-size:14px;color:#111">`
    html += `<h2 style="margin:0 0 4px">Admissão — ${esc(a.nome||"")}</h2>`
    html += `<p style="margin:0 0 12px;color:#555">${esc(a.cargo||"")} · ${esc(a.unidade||"")}${a.protocolo?` · ${esc(a.protocolo)}`:""}<br>CPF: ${esc(a.cpf||"")}</p>`
    for (const g of grupos) {
      html += `<h3 style="margin:14px 0 4px;font-size:13px;color:#35383F;text-transform:uppercase;letter-spacing:.5px">${esc(GRUPO_LABEL[g]||g)}</h3><table style="border-collapse:collapse;width:100%">`
      for (const it of byG[g]) {
        const lbl = esc(it.campo) + (it.ordem?` ${it.ordem}`:"") + (it.sentido?` (${esc(it.sentido)})`:"")
        html += `<tr><td style="padding:2px 8px 2px 0;color:#888;white-space:nowrap;vertical-align:top">${lbl}</td><td style="padding:2px 0">${esc(it.valor||"—")}</td></tr>`
      }
      html += `</table>`
    }
    const proposta = resp.filter(r=>r.grupo==="trabalho"&&r.campo==="proposta").map(r=>r.valor)[0]
    if (proposta) html += `<h3 style="margin:14px 0 4px;font-size:13px;color:#35383F;text-transform:uppercase">Proposta</h3><pre style="white-space:pre-wrap;font-family:inherit;margin:0">${esc(proposta)}</pre>`

    // documentos como LINKS de download (signed URL 30 dias)
    html += `<h3 style="margin:16px 0 4px;font-size:13px;color:#35383F;text-transform:uppercase">Documentos</h3>`
    if (!docs.length) { html += `<p style="margin:0;color:#888">(nenhum documento)</p>` }
    else {
      html += `<ul style="margin:0;padding-left:18px">`
      for (const d of docs) {
        let url = ""
        if (d.path) { const { data: su } = await db.storage.from(d.bucket || "admissao-docs").createSignedUrl(d.path, EXP); url = su?.signedUrl || "" }
        const nome = esc((d.slug?`${d.slug}: `:"") + (d.nome || "arquivo"))
        html += url ? `<li><a href="${esc(url)}">${nome}</a></li>` : `<li>${nome} (link indisponível)</li>`
      }
      html += `</ul>`
    }
    html += `<p style="margin:16px 0 0;color:#888;font-size:12px">Links de download válidos por ${DIAS} dias. Enviado automaticamente pelo Portal Líderes.</p></div>`

    const subject = `Admissão — ${a.nome||""} · ${a.cargo||""} · ${a.unidade||""}${a.protocolo?` (${a.protocolo})`:""}`
    const rs = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Authorization": `Bearer ${RESEND}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: FROM, to: [TO], subject, html })
    })
    const rj = await rs.json().catch(()=> ({}))
    if (!rs.ok) return json({ ok:false, motivo:"falha_envio", erro: rj?.message || rs.status })
    return json({ ok:true, id: rj?.id, docs: docs.length, para: TO })
  } catch (e: any) {
    return json({ ok:false, motivo:"erro", erro: String(e?.message || e) })
  }
})
