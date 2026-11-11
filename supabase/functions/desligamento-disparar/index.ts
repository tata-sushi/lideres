import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}


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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, erro: "metodo" }, 405);
  { const neg = await conferirBotao(req, ["governanca-kpis-rh-desligamentos::disparar-entrevista"]); if (neg) return neg; }
  try {
    const body = await req.json().catch(() => ({}));
    const mat = String(body?.matricula ?? "").trim();
    const tipo = body?.tipo ?? null;
    if (!mat) return json({ ok: false, erro: "matricula_obrigatoria" }, 400);

    const supaUrl = Deno.env.get("SUPABASE_URL")!;
    const srKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supa = createClient(supaUrl, srKey, { auth: { persistSession: false } });

    // 1) emite (ou reaproveita) o token
    const { data: emit, error: e1 } = await supa.schema("tata_plus")
      .rpc("av_desligamento_emitir", { p_matricula: mat, p_tipo: tipo });
    if (e1) return json({ ok: false, erro: "emitir_falhou", detalhe: e1.message }, 400);
    if (!emit?.ok) return json({ ok: false, erro: "emitir_recusou", detalhe: emit }, 400);

    const token = emit.token as string;
    const linkUrl = emit.url as string;
    const primeiro = String(emit.nome ?? "").split(" ")[0] || "";

    // 2) telefone do profile
    const { data: prof } = await supa.schema("tata_plus").from("profiles")
      .select("telefone").eq("matricula", mat).maybeSingle();
    let dig = String(prof?.telefone ?? "").replace(/\D/g, "");
    if (dig.length === 10 || dig.length === 11) dig = "55" + dig;
    if (dig.length < 12) return json({ ok: false, erro: "telefone_invalido", token }, 422);

    // 3) mensagem (copy padrao Sara, igual ao n8n)
    const NL = "\n";
    const msg =
      "Olá" + (primeiro ? ", " + primeiro : "") + "! Aqui é a Sara, do TATÁ Sushi." + NL + NL +
      "Quero agradecer pelo seu tempo com a gente e saber como foi a sua experiência por aqui." + NL + NL +
      "Você consegue responder nossa Pesquisa de Desligamento? É confidencial e bem rapidinho." + NL + NL +
      "É só responder por aqui:" + NL + linkUrl;

    // 4) envia via uazapi
    const uToken = Deno.env.get("UAZAPI_TOKEN");
    if (!uToken) return json({ ok: false, erro: "sem_uazapi_token", token }, 500);
    const uUrl = Deno.env.get("UAZAPI_URL") || "https://tatasushi.uazapi.com/send/text";
    const resp = await fetch(uUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", token: uToken },
      body: JSON.stringify({ number: dig, text: msg, delay: 0, linkPreview: true }),
    });
    const sentOk = resp.ok;
    let detalhe: unknown = null;
    try { detalhe = await resp.json(); } catch { detalhe = await resp.text().catch(() => null); }

    // 5) marca enviado SO se o envio deu certo
    if (sentOk) {
      await supa.schema("tata_plus").rpc("av_desligamento_marcar_enviado", { p_token: token });
    }

    const telMask = dig.replace(/^(\d{4})\d+(\d{2})$/, "$1***$2");
    return json({
      ok: sentOk,
      token,
      reaproveitado: !!emit.reaproveitado,
      telefone: telMask,
      nome: emit.nome,
      unidade: emit.unidade,
      uazapi_status: resp.status,
      detalhe: sentOk ? undefined : detalhe,
    }, sentOk ? 200 : 502);
  } catch (e) {
    return json({ ok: false, erro: "excecao", detalhe: String((e as Error)?.message ?? e) }, 500);
  }
});
