import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "jsr:@supabase/supabase-js@2"

// Migra a selfie do fluxo de admissão (bucket privado `admissao-docs`) para o avatar
// oficial do colaborador (bucket público `avatares`), nomeando {matricula}.ext na raiz,
// e vincula em tata_plus.auth_users.avatar_url (via RPC, sem sobrescrever).
//
// Fonte da worklist: RPC tata_plus.admissao_avatar_pendentes() — só quem tem selfie
// entregue + virou profile (match por CPF) + ainda está sem avatar. Idempotente.
// A selfie original é MANTIDA em admissao-docs (cópia, não movimento).
//
// Disparada diariamente pelo cron `migrar-selfies-avatar-diario` (08:30 BRT).

const SRC_BUCKET = "admissao-docs"
const DST_BUCKET = "avatares"

function extDe(mime: string, path: string): string {
  const m = (mime || "").toLowerCase()
  if (m === "image/png")  return "png"
  if (m === "image/webp") return "webp"
  if (m === "image/jpeg" || m === "image/jpg") return "jpg"
  const e = (path.split(".").pop() || "").toLowerCase()
  if (e === "jpeg") return "jpg"
  if (["png", "webp", "jpg"].includes(e)) return e
  return "jpg"
}

Deno.serve(async (_req) => {
  try {
    const SUPA_URL = Deno.env.get("SUPABASE_URL")
    const SERVICE  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!SUPA_URL || !SERVICE) {
      return new Response(JSON.stringify({ ok: false, motivo: "config" }), {
        status: 200, headers: { "Content-Type": "application/json" },
      })
    }

    const db = createClient(SUPA_URL, SERVICE, { auth: { persistSession: false } })

    const { data: pendentes, error: e1 } = await db.schema("tata_plus").rpc("admissao_avatar_pendentes")
    if (e1) throw new Error("pendentes: " + e1.message)

    const lista = Array.isArray(pendentes) ? pendentes : []
    const res = { ok: true, total: lista.length, migrados: 0, pulados: 0, erros: [] as any[] }

    for (const row of lista) {
      const matricula  = String(row?.matricula || "").trim()
      const selfiePath = String(row?.selfie_path || "")
      const mime       = String(row?.mime || "")
      if (!matricula || !selfiePath) { res.pulados++; continue }

      try {
        // 1) baixa a selfie do bucket privado
        const dl = await db.storage.from(SRC_BUCKET).download(selfiePath)
        if (dl.error || !dl.data) throw new Error("download: " + (dl.error?.message || "sem dados"))

        // 2) sobe no bucket público como {matricula}.ext na raiz
        const objectName  = `${matricula}.${extDe(mime, selfiePath)}`
        const contentType = mime.startsWith("image/") ? mime : "image/jpeg"
        const up = await db.storage.from(DST_BUCKET).upload(objectName, dl.data, {
          upsert: true, contentType, cacheControl: "3600",
        })
        if (up.error) throw new Error("upload: " + up.error.message)

        // 3) vincula no perfil (auth_users.avatar_url), sem sobrescrever
        const { data: url, error: e3 } = await db.schema("tata_plus")
          .rpc("admissao_avatar_vincular", { p_matricula: matricula })
        if (e3) throw new Error("vincular: " + e3.message)

        res.migrados++
        console.log(`✅ ${matricula} ← ${objectName} (${url})`)
      } catch (e: any) {
        res.erros.push({ matricula, erro: String(e?.message || e) })
        console.error(`❌ ${matricula}: ${e?.message || e}`)
      }
    }

    return new Response(JSON.stringify(res), { headers: { "Content-Type": "application/json" } })
  } catch (e: any) {
    console.error("migrar-selfies-avatar erro:", e?.message, e?.stack)
    return new Response(JSON.stringify({ ok: false, erro: String(e?.message || e) }), {
      status: 500, headers: { "Content-Type": "application/json" },
    })
  }
})
