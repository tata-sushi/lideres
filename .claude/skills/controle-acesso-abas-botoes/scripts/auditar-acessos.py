#!/usr/bin/env python3
"""
Auditoria das chaves de acesso (data-aba-id / data-botao-id) das páginas de
Governança — repo `lideres`.

Objetivo: organizar e padronizar. O script varre `compliance/**/*.html`, extrai
todas as chaves e o `GOV_PAGE_ID` de cada página, e aponta divergências que
quebram o controle de acesso ou fogem da convenção. Não altera nada — só relata.

Uso:
    python3 .claude/skills/controle-acesso-abas-botoes/scripts/auditar-acessos.py
    python3 ...auditar-acessos.py --raiz compliance        # limita a pasta
    python3 ...auditar-acessos.py --vocab                  # só o vocabulário de slugs

Saída: um relatório por página com PROBLEMAS (prefixo != GOV_PAGE_ID, slug fora
do kebab-case, data-botao-id sem fiação de JS) e AVISOS de padronização
(sinônimos como dashboard/kpis, all/todos, extrair-csv/export-csv), mais o
vocabulário de slugs do repo inteiro. Código de saída 1 se houver PROBLEMA.
"""
import argparse
import os
import re
import sys
from collections import Counter, defaultdict

RE_PAGE_ID = re.compile(r"""GOV_PAGE_ID\s*=\s*['"]([^'"]+)['"]""")
RE_KEY = re.compile(r'data-(aba|botao)-id="([^"]*)"')
RE_KEBAB = re.compile(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')

# Sinônimos conhecidos → forma canônica sugerida. A ideia é convergir o mesmo
# conceito para um único slug em todas as páginas (ver references/padronizacao.md).
SINONIMOS = {
    'kpis': 'dashboard',        # aba de indicadores: padronizar em "dashboard"
    'indicadores': 'dashboard',
    'geral': 'dashboard',       # confira caso a caso — "geral" às vezes é outra coisa
    'all': 'todos',             # filtro "todos": usar português
    'export-csv': 'exportar-csv',
    'extrair-csv': 'exportar-csv',
}

def achar_paginas(raiz):
    for base, _, arquivos in os.walk(raiz):
        for nome in arquivos:
            if nome.endswith('.html'):
                yield os.path.join(base, nome)

def slug_de(chave):
    return chave.split('::', 1)[1] if '::' in chave else None

def prefixo_de(chave):
    return chave.split('::', 1)[0] if '::' in chave else chave

def auditar(raiz):
    paginas = sorted(achar_paginas(raiz))
    problemas = []          # (arquivo, msg) — quebram o acesso / fora do padrão duro
    avisos = []             # (arquivo, msg) — padronização recomendada
    vocab = Counter()       # slug -> contagem no repo
    slug_paginas = defaultdict(set)  # slug -> {páginas}

    for f in paginas:
        try:
            txt = open(f, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        chaves = RE_KEY.findall(txt)
        if not chaves:
            continue
        m = RE_PAGE_ID.search(txt)
        page_id = m.group(1) if m else None
        tem_gov_botoes = 'GOV_BOTOES' in txt

        if not page_id:
            problemas.append((f, "tem data-*-id mas NÃO declara window.GOV_PAGE_ID"))

        for tipo, chave in chaves:
            if '::' not in chave:
                # chaves dinâmicas tipo data-botao-id="' + id + '" caem aqui: ignora
                if '+' in chave or '{' in chave:
                    continue
                problemas.append((f, f"chave sem '::' — fora do formato <pagina>::<slug>: {chave!r}"))
                continue
            pref, slug = prefixo_de(chave), slug_de(chave)
            vocab[slug] += 1
            slug_paginas[slug].add(os.path.basename(f))

            if page_id and pref != page_id:
                problemas.append((f, f"prefixo '{pref}' != GOV_PAGE_ID '{page_id}' (chave {chave!r})"))
            if not RE_KEBAB.match(slug):
                problemas.append((f, f"slug fora do kebab-case: {slug!r} (use minúsculas, sem acento, '-' entre palavras)"))
            if '-' not in slug and tipo == 'botao' or (tipo == 'aba' and slug in {'editar', 'excluir', 'novo', 'nova', 'remover', 'cadastrar'}):
                # verbo "pelado" sem substantivo (editar, excluir…) → ambíguo entre páginas
                if slug in {'editar', 'excluir', 'novo', 'nova', 'remover', 'cadastrar', 'adicionar', 'criar'}:
                    avisos.append((f, f"verbo sem objeto: {slug!r} → prefira 'verbo-substantivo' (ex.: '{slug}-<coisa>')"))
            if slug in SINONIMOS:
                avisos.append((f, f"slug '{slug}' → padronizar em '{SINONIMOS[slug]}' (mesmo conceito noutras páginas)"))

            # data-botao-id exige fiação de JS na página (esconde por padrão + trava ação)
            if tipo == 'botao' and not tem_gov_botoes:
                problemas.append((f, f"usa data-botao-id ({chave}) mas a página não tem GOV_BOTOES/aplicarBotoes — o botão não é gerido"))

    return paginas, problemas, avisos, vocab, slug_paginas

def imprimir(problemas, avisos, vocab, slug_paginas, so_vocab=False):
    if not so_vocab:
        print("=" * 72)
        print("PROBLEMAS (quebram o acesso ou fogem do formato) — corrija:")
        print("=" * 72)
        if problemas:
            for f, msg in problemas:
                print(f"  [x] {f}\n        {msg}")
        else:
            print("  (nenhum) ✅")

        print("\n" + "=" * 72)
        print("AVISOS de padronização (organize quando mexer na página):")
        print("=" * 72)
        if avisos:
            for f, msg in sorted(set(avisos)):
                print(f"  [!] {f}\n        {msg}")
        else:
            print("  (nenhum) ✅")

    print("\n" + "=" * 72)
    print("VOCABULÁRIO DE SLUGS (slug × nº de páginas que usam):")
    print("=" * 72)
    # Ordena pela quantidade de PÁGINAS que usam o slug: o slug mais espalhado é
    # o padrão de fato. Ocorrências (vocab) só desempatam.
    por_paginas = sorted(slug_paginas, key=lambda s: (-len(slug_paginas[s]), -vocab[s], s))
    for slug in por_paginas:
        paginas = sorted(slug_paginas[slug])
        marca = f"  ← padronizar em '{SINONIMOS[slug]}'" if slug in SINONIMOS else ""
        print(f"  {len(paginas):>2}  {slug:<28}{marca}")
        if slug in SINONIMOS or len(paginas) == 1:
            amostra = ', '.join(paginas[:4]) + ('…' if len(paginas) > 4 else '')
            print(f"        ({amostra})")

def main():
    ap = argparse.ArgumentParser(description="Audita as chaves data-aba-id/data-botao-id do portal.")
    ap.add_argument('--raiz', default='compliance', help="pasta a varrer (default: compliance)")
    ap.add_argument('--vocab', action='store_true', help="mostra só o vocabulário de slugs")
    args = ap.parse_args()

    if not os.path.isdir(args.raiz):
        print(f"pasta não encontrada: {args.raiz} — rode a partir da raiz do repo lideres.", file=sys.stderr)
        return 2

    paginas, problemas, avisos, vocab, slug_paginas = auditar(args.raiz)
    print(f"Auditadas {len(paginas)} páginas .html em '{args.raiz}/'.\n")
    imprimir(problemas, avisos, vocab, slug_paginas, so_vocab=args.vocab)
    return 1 if problemas else 0

if __name__ == '__main__':
    raise SystemExit(main())
