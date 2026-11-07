// agente-portal — lê o Portal Líderes publicado e alimenta a base de conhecimento do Sam
// (dp_rh.agente_conhecimento, fonte 'portal' e 'arquivo').
//
// 1. Lista as páginas e arquivos do repositório tata-sushi/lideres (API pública do GitHub, a
//    mesma que o menu do portal usa para contar páginas). Se a API falhar, usa as páginas já
//    indexadas.
// 2. Baixa cada página de https://lideres.tatasushi.tech/ (o que está publicado), extrai o
//    texto escrito (aba Sobre dos dashboards; corpo das páginas institucionais) com
//    ./extrair.ts e grava por RPC (tata_plus.agente_portal_gravar).
// 3. Grava a lista de arquivos (PDF, DOCX, logos…) com o link, e no fim desativa páginas
//    que sumiram (tata_plus.agente_portal_fim).
// A extração roda dentro do limite de CPU da edge: passando de ~1,1 s, o resto segue numa
// nova chamada (a função chama a si mesma com a lista e o ponto onde parou).
//
// Chamada: POST …/agente-portal?k=<portal_secret>  (pg_cron diário e o comando
// "atualiza portal" do responsável no WhatsApp). verify_jwt = false; a senha fica em
// dp_rh.agente_config (portal_secret), lida por tata_plus.agente_segredo.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { extrair, extrairMarkdown } from "./extrair.ts";

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

const SITE = "https://lideres.tatasushi.tech/";
const REPO = "tata-sushi/lideres";
const arvore = (ref: string) => `https://api.github.com/repos/${REPO}/git/trees/${encodeURIComponent(ref)}?recursive=1`;
const bruto = (ref: string, caminho: string) =>
  `https://raw.githubusercontent.com/${REPO}/${ref}/${caminho.split("/").map(encodeURIComponent).join("/")}`;
const DOC_RE = /^docs\/conhecimento\/.+\.md$/;
const PAGINA_RE = /^compliance\/.+\.html$/;
const ARQUIVO_RE = /^compliance\/.+\.(pdf|docx?|xlsx?|pptx?|png|jpe?g|webp)$/i;
const LIMITE_CPU_MS = 1100;
const LOTE = 6;

const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
const supa = createClient(SUPA_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
  db: { schema: "tata_plus" },
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });
const erroTxt = (err: unknown) => String((err as Error)?.message ?? err);
const urlDe = (caminho: string) => SITE + caminho.split("/").map(encodeURIComponent).join("/");

type Lista = { paginas: string[]; arquivos: string[]; documentos: string[]; origem: string };
type Resumo = {
  origem: string; paginas: number; processadas: number; pedacos: number; arquivos: number;
  documentos: number; erros: string[]; chamadas: number;
};

async function itensDoRepo(ref: string): Promise<string[] | null> {
  try {
    const r = await fetch(arvore(ref), { headers: { "User-Agent": "tata-agente-portal", Accept: "application/vnd.github+json" } });
    if (!r.ok) return null;
    const d = await r.json();
    return (d?.tree ?? []).filter((f: any) => f?.type === "blob").map((f: any) => String(f.path));
  } catch {
    return null;
  }
}

async function listar(): Promise<Lista> {
  const itens = await itensDoRepo("main");
  if (itens) {
    const paginas = itens.filter((p) => PAGINA_RE.test(p)).sort();
    if (paginas.length) {
      return {
        paginas, origem: "github",
        arquivos: itens.filter((p) => ARQUIVO_RE.test(p)).sort(),
        documentos: itens.filter((p) => DOC_RE.test(p)).sort(),
      };
    }
  }
  // plano B: as páginas que já estão na base (sem a lista de arquivos)
  const { data } = await supa.rpc("agente_conhecimento_catalogo", { p_completo: true });
  const paginas = ((data as any)?.paginas ?? [])
    .map((p: any) => String(p.url ?? ""))
    .filter((u: string) => u.startsWith(SITE))
    .map((u: string) => decodeURIComponent(u.slice(SITE.length)))
    .sort();
  return { paginas, arquivos: [], documentos: [], origem: "base" };
}

// documentos transcritos (docs/conhecimento/*.md, ex.: Código de Ética) → fonte 'pdf'
async function gravarDocumentos(ref: string, caminhos: string[], resumo: Resumo): Promise<void> {
  for (const c of caminhos) {
    try {
      const r = await fetch(bruto(ref, c), { headers: { "User-Agent": "tata-agente-portal" } });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const d = extrairMarkdown(await r.text());
      const { data, error } = await supa.rpc("agente_conhecimento_gravar", {
        p_fonte: "pdf", p_pagina: c, p_titulo: d.titulo || c, p_url: d.url ?? `https://github.com/${REPO}/blob/${ref}/${c}`,
        p_pedacos: d.pedacos,
      });
      if (error) throw new Error(error.message);
      resumo.documentos += Number(data ?? 0);
    } catch (e) {
      resumo.erros.push(`${c}: ${erroTxt(e)}`);
    }
  }
}

async function baixar(caminho: string): Promise<string> {
  const r = await fetch(urlDe(caminho), { headers: { "User-Agent": "tata-agente-portal" } });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return await r.text();
}

async function gravarArquivos(arquivos: string[]): Promise<number> {
  const itens = arquivos.map((c) => {
    const nome = c.split("/").pop()!.replace(/\.[^.]+$/, "");
    return { caminho: c, nome, pasta: c.slice(0, c.lastIndexOf("/")), url: urlDe(c) };
  });
  const { data, error } = await supa.rpc("agente_portal_arquivos", { p_itens: itens });
  if (error) throw new Error(error.message);
  return Number(data ?? 0);
}

// processa a partir de `desde`; devolve o índice onde parou (= total se terminou)
async function processar(lista: Lista, desde: number, resumo: Resumo): Promise<number> {
  let cpu = 0;
  let i = desde;
  while (i < lista.paginas.length) {
    const grupo = lista.paginas.slice(i, i + LOTE);
    const htmls = await Promise.all(grupo.map((c) => baixar(c).then((h) => ({ h }), (e) => ({ e: erroTxt(e) }))));
    for (let j = 0; j < grupo.length; j++) {
      if (cpu > LIMITE_CPU_MS) return i; // segue numa nova chamada a partir desta página
      const caminho = grupo[j];
      const r = htmls[j] as { h?: string; e?: string };
      i++;
      if (r.e !== undefined) { resumo.erros.push(`${caminho}: ${r.e}`); continue; }
      const t0 = performance.now();
      const p = extrair(r.h!, urlDe(caminho));
      cpu += performance.now() - t0;
      const { data, error } = await supa.rpc("agente_portal_gravar", {
        p_pagina: caminho, p_titulo: p.titulo, p_url: urlDe(caminho), p_pedacos: p.pedacos,
      });
      if (error) { resumo.erros.push(`${caminho}: ${error.message}`); continue; }
      resumo.processadas++;
      resumo.pedacos += Number(data ?? 0);
    }
  }
  return i;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const { data: segredo } = await supa.rpc("agente_segredo", { p_chave: "portal_secret" });
  if (!segredo || url.searchParams.get("k") !== segredo) return json({ ok: false, erro: "nao_autorizado" }, 401);

  let corpo: any = {};
  try { corpo = await req.json(); } catch { /* chamada sem corpo = começo */ }

  try {
    const continuando = Array.isArray(corpo?.paginas) && Number.isInteger(corpo?.desde);
    const lista: Lista = continuando
      ? { paginas: corpo.paginas, arquivos: [], documentos: [], origem: corpo.resumo?.origem ?? "continuação" }
      : await listar();
    const resumo: Resumo = continuando
      ? { ...corpo.resumo, chamadas: (corpo.resumo?.chamadas ?? 1) + 1 }
      : {
        origem: lista.origem, paginas: lista.paginas.length, processadas: 0, pedacos: 0, arquivos: 0, documentos: 0,
        erros: [], chamadas: 1,
      };
    if (!lista.paginas.length) return json({ ok: false, erro: "nenhuma página encontrada", resumo }, 500);

    if (!continuando && lista.arquivos.length) {
      try { resumo.arquivos = await gravarArquivos(lista.arquivos); }
      catch (e) { resumo.erros.push(`arquivos: ${erroTxt(e)}`); }
    }
    if (!continuando) {
      // documentos: do main (padrão) ou de outro ramo, para carregar antes do merge ({"ramo_documentos": "…"})
      const ramo = typeof corpo?.ramo_documentos === "string" && /^[\w./-]{1,100}$/.test(corpo.ramo_documentos)
        ? corpo.ramo_documentos : "main";
      const docs = ramo === "main" ? lista.documentos : ((await itensDoRepo(ramo)) ?? []).filter((p) => DOC_RE.test(p)).sort();
      await gravarDocumentos(ramo, docs, resumo);
    }

    const parou = await processar(lista, continuando ? corpo.desde : 0, resumo);
    if (parou < lista.paginas.length) {
      // limite de CPU: continua numa nova chamada (não espera)
      EdgeRuntime.waitUntil(fetch(`${SUPA_URL}/functions/v1/agente-portal?k=${encodeURIComponent(String(segredo))}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ paginas: lista.paginas, desde: parou, resumo }),
      }).catch(() => {}));
      return json({ ok: true, continua: true, desde: parou, resumo });
    }

    resumo.erros = resumo.erros.slice(0, 20);
    const { error } = await supa.rpc("agente_portal_fim", { p_paginas: lista.paginas, p_resumo: resumo });
    if (error) resumo.erros.push(`fim: ${error.message}`);
    return json({ ok: true, continua: false, resumo });
  } catch (err) {
    return json({ ok: false, erro: erroTxt(err) }, 500);
  }
});
