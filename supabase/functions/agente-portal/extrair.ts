// Extrai o conteúdo ESCRITO de uma página do Portal Líderes (sem dados dinâmicos):
//   • dashboards: só a aba Sobre (<div id="view-sobre">) — o resto é filtro/gráfico preenchido por JS;
//   • páginas institucionais/conceitos/menus: o corpo, sem header, footer, drawer, gate de acesso e modais.
// Devolve seções (caminho de títulos + texto) já quebradas em pedaços de até ~1.800 caracteres,
// e os links de arquivos/páginas citados (PDF, DOCX, imagens, outras páginas).
// Sem dependências: roda no Deno (edge) e no Node (teste local).

export type Pedaco = { secao: string; texto: string };
export type Link = { texto: string; url: string };
export type Pagina = { titulo: string; pedacos: Pedaco[]; links: Link[]; temSobre: boolean };

const PULAR_TAG = new Set([
  "script", "style", "svg", "noscript", "template", "head", "canvas", "button", "select", "option",
  "input", "textarea", "label", "header", "footer", "nav", "iframe", "video", "audio", "map",
]);
const VAZIAS = new Set(["br", "img", "input", "meta", "link", "hr", "source", "wbr", "col", "area", "base", "param", "track", "embed"]);
const BLOCO = new Set([
  "p", "div", "li", "ul", "ol", "tr", "td", "th", "table", "thead", "tbody", "section", "article", "aside", "main",
  "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "details", "summary", "dd", "dt", "dl", "figure", "figcaption", "pre",
]);
const PULAR_ID = /^(auth-gate|gate-.*|drawer|drawer-overlay|loading-overlay|errorState|error-state|toast.*)$/i; // (zoom-content embrulha a página inteira: não pular)
const PULAR_CLASSE = new Set([
  "header", "footer", "tabs", "tab-btn", "dash-subtabs", "drawer", "drawer-overlay", "overlay", "modal", "modal-overlay",
  "loading-overlay", "spinner", "filters", "filter-bar", "filtros", "toast", "kpis-wrap", "chart-card", "gate",
]);
// títulos: nível 1 a 4
const TITULO_CLASSE: Array<[RegExp, number]> = [
  [/^mod-title$/, 1],
  [/^sec-div$/, 2],
  [/^(acc-name|ft-acc-name)$/, 3],
  [/^(?!chart-|modal-|drawer-|kpi-|btn-|filter-|form-|field-)[a-z0-9-]+-(title|titulo)$/, 4],
];
const RUIDO = /^(Verificando acesso\.{0,3}|Confirmando sua permissão\.?|Sem acesso|Seu perfil não possui permissão.*|← Voltar ao Portal|Carregando.*|Ver mais|Limpar filtros|Em construção\.?|—|-|–|·|✕|×|0|[0-9]+ (registro|colaborador|resgate|página)\(s\).*|[0-9]{1,3}%?|TATÁ Sushi \| TATÁ Poke \| .*)$/i;

const NOMEADAS: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", middot: "·", mdash: "—", ndash: "–", hellip: "…",
  laquo: "«", raquo: "»", ldquo: "“", rdquo: "”", lsquo: "‘", rsquo: "’", bull: "•", deg: "°", ordm: "º", ordf: "ª",
  copy: "©", reg: "®", trade: "™", times: "×", rarr: "→", larr: "←", uarr: "↑", darr: "↓", check: "✓", euro: "€",
  aacute: "á", Aacute: "Á", agrave: "à", Agrave: "À", acirc: "â", Acirc: "Â", atilde: "ã", Atilde: "Ã",
  eacute: "é", Eacute: "É", ecirc: "ê", Ecirc: "Ê", iacute: "í", Iacute: "Í", oacute: "ó", Oacute: "Ó",
  ocirc: "ô", Ocirc: "Ô", otilde: "õ", Otilde: "Õ", uacute: "ú", Uacute: "Ú", uuml: "ü", ccedil: "ç", Ccedil: "Ç",
};
export function decodificar(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z][a-z0-9]*);/gi, (m, e: string) => {
    if (e[0] === "#") {
      const n = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : m;
    }
    return NOMEADAS[e] ?? m;
  });
}

function atributo(attrs: string, nome: string): string | null {
  const m = new RegExp(`(?:^|\\s)${nome}\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))`, "i").exec(attrs);
  return m ? (m[2] ?? m[3] ?? m[4] ?? "") : null;
}

function resolver(href: string, base: string): string | null {
  const h = decodificar(href.trim());
  if (!h || h.startsWith("#") || /^(javascript|mailto|tel|data):/i.test(h)) return null;
  try {
    return new URL(h, base).href;
  } catch {
    return null;
  }
}

type No = { tag: string; pular: boolean; titulo: number; ehSobre: boolean };

export function extrair(html: string, urlPagina: string): Pagina {
  const titulo = decodificar((/<title[^>]*>([\s\S]*?)<\/title>/i.exec(html)?.[1] ?? "").replace(/\s+/g, " ").trim())
    .replace(/^TAT[ÁA] (SUSHI|Sushi)\s*[-–—|·]\s*/i, "").trim();
  const temSobre = /<div[^>]*\bid\s*=\s*["']view-sobre["']/i.test(html);

  const pilha: No[] = [];
  let pular = 0; // quantos ancestrais mandam pular
  let dentroSobre = 0; // dentro de #view-sobre
  let tituloAtivo = 0; // nível do título sendo lido (0 = nenhum)
  let bufTitulo = "";
  const caminho: string[] = ["", "", "", ""];
  type Sec = { caminho: string[]; linhas: string[] };
  const secoes: Sec[] = [{ caminho: ["", "", "", ""], linhas: [] }];
  let linha = "";
  const links: Link[] = [];
  const vistos = new Set<string>();
  let linkAberto: { url: string; texto: string } | null = null;
  // tabelas: cabeçalhos das colunas para prefixar as células
  const tabelas: Array<{ cab: string[]; col: number; naCab: boolean; celula: string }> = [];

  const capturando = () => pular === 0 && (!temSobre || dentroSobre > 0);
  const fecharLinha = () => {
    const t = linha.replace(/[ \t ]+/g, " ").trim();
    linha = "";
    if (!t || RUIDO.test(t)) return;
    const sec = secoes[secoes.length - 1];
    if (sec.linhas[sec.linhas.length - 1] !== t) sec.linhas.push(t);
  };
  const novaSecao = (nivel: number, texto: string) => {
    fecharLinha();
    caminho[nivel - 1] = texto;
    for (let i = nivel; i < 4; i++) caminho[i] = "";
    secoes.push({ caminho: [...caminho], linhas: [] });
  };
  const escrever = (t: string) => {
    if (!capturando()) return;
    if (tituloAtivo) bufTitulo += t;
    else linha += t;
    if (linkAberto) linkAberto.texto += t;
    const tab = tabelas[tabelas.length - 1];
    if (tab?.naCab) tab.celula += t;
  };

  const re = /<!--[\s\S]*?-->|<![^>]*>|<(\/?)([a-zA-Z][a-zA-Z0-9-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>|([^<]+)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html))) {
    if (m[4] !== undefined) {
      escrever(decodificar(m[4]).replace(/\s+/g, " "));
      continue;
    }
    if (!m[2]) continue; // comentário
    const fecha = m[1] === "/";
    const tag = m[2].toLowerCase();
    const attrs = m[3] ?? "";

    if (!fecha) {
      // conteúdo bruto: pula até o fechamento
      if (tag === "script" || tag === "style" || tag === "textarea") {
        const fim = html.toLowerCase().indexOf(`</${tag}`, re.lastIndex);
        re.lastIndex = fim < 0 ? html.length : fim;
        continue;
      }
      const autoFecha = VAZIAS.has(tag) || /\/\s*$/.test(attrs);
      if (tag === "br") {
        if (capturando()) {
          if (tituloAtivo) bufTitulo += " ";
          else fecharLinha();
        }
        continue;
      }
      if (autoFecha) continue;

      const id = atributo(attrs, "id") ?? "";
      const classes = (atributo(attrs, "class") ?? "").split(/\s+/).filter(Boolean);
      const ehSobre = id === "view-sobre";
      // (display:none não conta: o conteúdo fica escondido até o gate de acesso liberar)
      const pularEste = PULAR_TAG.has(tag) || PULAR_ID.test(id) || classes.some((c) => PULAR_CLASSE.has(c));
      let nivel = 0;
      if (/^h[1-6]$/.test(tag)) nivel = Math.min(4, Math.max(1, Number(tag[1])));
      for (const c of classes) for (const [rx, n] of TITULO_CLASSE) if (!nivel && rx.test(c)) nivel = n;
      if (tituloAtivo) nivel = 0; // título dentro de título: conta como texto do mesmo

      const no: No = { tag, pular: pularEste, titulo: nivel, ehSobre };
      pilha.push(no);
      if (pularEste) pular++;
      if (ehSobre) dentroSobre++;
      if (capturando()) {
        if (nivel) {
          fecharLinha();
          tituloAtivo = nivel;
          bufTitulo = "";
        } else if (BLOCO.has(tag)) {
          if (!tituloAtivo) fecharLinha();
          else bufTitulo += " ";
        }
        if (tag === "li" && !tituloAtivo) linha += "• ";
        if (tag === "table") tabelas.push({ cab: [], col: 0, naCab: false, celula: "" });
        const tab = tabelas[tabelas.length - 1];
        if (tab && tag === "thead") tab.naCab = true;
        if (tab && tag === "tr") tab.col = 0;
        if (tab && (tag === "td" || tag === "th")) {
          if (tab.naCab) {
            tab.celula = "";
          } else if (tab.cab.length > 1 && tab.cab[tab.col]) {
            linha += `${tab.cab[tab.col]}: `;
          }
        }
        if (tag === "a") {
          const url = resolver(atributo(attrs, "href") ?? "", urlPagina);
          linkAberto = url ? { url, texto: "" } : null;
        }
      }
      continue;
    }

    // fechamento: desempilha até a tag correspondente (HTML mal fechado é tolerado)
    let idx = -1;
    for (let i = pilha.length - 1; i >= 0; i--) if (pilha[i].tag === tag) { idx = i; break; }
    if (idx < 0) continue;
    while (pilha.length > idx) {
      const no = pilha.pop()!;
      const cap = capturando();
      if (cap && no.titulo && tituloAtivo === no.titulo) {
        const t = bufTitulo.replace(/\s+/g, " ").trim();
        tituloAtivo = 0;
        bufTitulo = "";
        if (t && t.length <= 90 && !RUIDO.test(t)) novaSecao(no.titulo, t);
        else if (t) { linha += t; fecharLinha(); }
      } else if (cap && BLOCO.has(no.tag) && !tituloAtivo) {
        fecharLinha();
      }
      const tab = tabelas[tabelas.length - 1];
      if (cap && tab) {
        if ((no.tag === "td" || no.tag === "th") && tab.naCab) {
          tab.cab[tab.col] = tab.celula.replace(/\s+/g, " ").trim();
          tab.celula = "";
        }
        if (no.tag === "td" || no.tag === "th") tab.col++;
        if (no.tag === "thead") tab.naCab = false;
      }
      if (cap && no.tag === "table") tabelas.pop();
      if (cap && no.tag === "a" && linkAberto) {
        const texto = linkAberto.texto.replace(/\s+/g, " ").trim();
        const url = linkAberto.url;
        linkAberto = null;
        if (texto && !vistos.has(url)) {
          vistos.add(url);
          links.push({ texto, url });
        }
        if (texto) linha += ` (${url})`;
      }
      if (no.pular) pular--;
      if (no.ehSobre) dentroSobre--;
    }
  }
  fecharLinha();

  // seções → pedaços: um item inteiro (até o 3º nível de título) por pedaço, quebrando os grandes.
  // Subtítulos (4º nível) entram no texto como "Subtítulo:". Itens pequenos e vizinhos de mesmo
  // assunto não se misturam com o próximo item (ex.: plano de saúde ≠ seguro de vida).
  const pedacos: Pedaco[] = [];
  const MAX = 1800, MIN = 120;
  let atual: (Pedaco & { chave: string; base: string[] }) | null = null;
  for (const s of secoes) {
    if (!s.linhas.length) continue;
    const nome = s.caminho.filter(Boolean).join(" › ");
    const chave = s.caminho.slice(0, 3).join("¦");
    let texto = s.linhas.join("\n");
    const mesmoItem = atual && atual.chave === chave;
    const pequeno = atual && atual.texto.length < MIN; // ex.: só a introdução do título-pai
    if (atual && (mesmoItem || pequeno) && atual.texto.length + texto.length + 2 <= MAX) {
      const sub = s.caminho.slice(atual.base.filter(Boolean).length).filter(Boolean).join(" › ");
      atual.texto += `\n\n${sub ? `${sub}:\n` : ""}${texto}`;
      if (!mesmoItem) { atual.chave = chave; atual.secao = s.caminho.slice(0, 3).filter(Boolean).join(" › "); }
      continue;
    }
    while (texto.length > MAX) {
      let corte = texto.lastIndexOf("\n", MAX);
      if (corte < MAX / 2) corte = MAX;
      pedacos.push({ secao: nome, texto: texto.slice(0, corte).trim() });
      texto = texto.slice(corte).trim();
    }
    const base = s.caminho.slice(0, 3);
    atual = { secao: base.filter(Boolean).join(" › ") || nome, texto, chave, base };
    if (nome !== atual.secao) atual.texto = `${s.caminho.slice(3).filter(Boolean).join(" › ")}:\n${texto}`;
    pedacos.push(atual);
  }
  return {
    titulo,
    pedacos: pedacos.filter((p) => p.texto.length >= 20).map((p) => ({ secao: p.secao, texto: p.texto })),
    links,
    temSobre,
  };
}

// links internos para outras páginas .html do portal (para descobrir páginas novas)
export function paginasCitadas(html: string, urlPagina: string, prefixo: string): string[] {
  const achadas = new Set<string>();
  const re = /["'`]([^"'`\s<>]+?\.html)(?:[?#][^"'`\s<>]*)?["'`]/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html))) {
    const u = resolver(m[1], urlPagina);
    if (u && u.startsWith(prefixo)) achadas.add(u.split("#")[0].split("?")[0]);
  }
  return [...achadas];
}
