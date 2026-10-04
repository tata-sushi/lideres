#!/usr/bin/env python3
"""
Relatório "ids de acesso × quem vê" — repo `lideres`.

Cruza os ids do HTML (fonte da verdade: data-aba-id / data-botao-id + GOV_PAGE_ID
de compliance/**/*.html) com o banco (catálogo e acessos por pessoa, schema
`tata_plus`) e gera uma página HTML com duas visões: POR PÁGINA (cada id, o tipo e
quem vê) e POR PESSOA (páginas, abas escondidas e botões liberados), mais uma lista
de pontos de atenção (id sem registro no banco, nome antigo no banco, pessoa
inativa com acesso, liberação sem efeito…).

⚠️ O relatório tem NOME DE PESSOAS. Gere SEMPRE fora do repo (scratchpad) e nunca
commite: tudo que entra no repo é publicado no GitHub Pages.

Uso:
    python3 .claude/skills/controle-acesso-abas-botoes/scripts/relatorio-acessos.py <pasta_dump> <saida.html>

<pasta_dump> tem 4 arquivos texto, uma linha por registro, campos separados por "|"
(listas de matrícula separadas por vírgula). Gere cada um com o SQL abaixo (MCP do
Supabase, projeto aoqsbusfrffapjglpqjk) e cole o resultado:

  pessoas.txt   matricula|nome|cargo|unidade|perfil|status
    with env as (select matricula from tata_plus.governanca_acessos_paginas
      union select matricula from tata_plus.governanca_abas_bloqueios
      union select matricula from tata_plus.governanca_abas_liberacoes
      union select matricula from tata_plus.profiles where perfil='admin' and status='Ativo')
    select string_agg(p.matricula||'|'||coalesce(p.nome,'')||'|'||coalesce(p.cargo,'')||'|'||
      coalesce(p.unidade,'')||'|'||coalesce(p.perfil,'')||'|'||coalesce(p.status,''), E'\\n' order by p.nome)
    from tata_plus.profiles p join env e on e.matricula=p.matricula;

  paginas.txt   pagina_id|label|secao|sub|url|ativo(1/0)|matriculas_com_acesso
    select string_agg(pg.pagina_id||'|'||coalesce(pg.label,'')||'|'||coalesce(pg.secao,'')||'|'||
      coalesce(pg.sub,'')||'|'||coalesce(pg.url,'')||'|'||case when pg.ativo then '1' else '0' end||'|'||
      coalesce((select string_agg(g.matricula, ',' order by g.matricula) from tata_plus.governanca_acessos_paginas g
                where g.pagina_id=pg.pagina_id),''), E'\\n' order by pg.ordem, pg.pagina_id)
    from tata_plus.governanca_paginas pg;

  catalogo.txt  aba_id|pagina_id|label|tipo|ordem|ativo(1/0)|bloqueados|liberados
    select string_agg(a.aba_id||'|'||coalesce(a.pagina_id,'')||'|'||coalesce(a.label,'')||'|'||
      coalesce(a.tipo,'')||'|'||coalesce(a.ordem::text,'')||'|'||case when a.ativo then '1' else '0' end||'|'||
      coalesce((select string_agg(b.matricula, ',' order by b.matricula) from tata_plus.governanca_abas_bloqueios b
                where b.aba_id=a.aba_id),'')||'|'||
      coalesce((select string_agg(l.matricula, ',' order by l.matricula) from tata_plus.governanca_abas_liberacoes l
                where l.aba_id=a.aba_id),''), E'\\n' order by a.pagina_id, a.tipo, a.ordem, a.aba_id)
    from tata_plus.governanca_abas a;

  valores.txt   area|matriculas_liberadas            (opcional)
    select area, string_agg(matricula, ',' order by matricula) filter (where liberado)
    from dp_rh.perm_ver_valores group by area order by area;

Confira as contagens depois de colar (bloqueios, liberações e acessos) contra um
count(*) no banco antes de mostrar o relatório.

Regras aplicadas (as mesmas do gate.js / RPCs):
  - Página: vê quem tem linha em governanca_acessos_paginas; admin vê tudo, exceto
    a seção "App" do Plus (Kanban, Limpeza, Brainstorm…), que não tem bypass de admin.
  - Aba (tipo 'aba'): visível para quem vê a página, menos os bloqueados.
  - Botão (tipo 'botao'): oculto; aparece só para quem foi liberado (e vê a página).
  - Id no HTML sem registro no banco: o gate não esconde → aparece para todos que veem a página.
  - Admin vê todas as abas e botões. Pessoa inativa não entra em "quem vê".
"""
import html
import os
import re
import sys
from collections import OrderedDict, defaultdict
from datetime import date

RE_PAGE_ID = re.compile(r"""GOV_PAGE_ID\s*=\s*['"]([^'"]+)['"]""")
RE_TAG = re.compile(r'<(button|a|div|span|li|label)\b([^>]*?)\bdata-(aba|botao)-id="([^"]+)"([^>]*)>', re.S)
RE_CLASS = re.compile(r'class="([^"]*)"')
RE_TITLE = re.compile(r'title="([^"]*)"')
# Nomes antigos substituídos no #2991 (apagar do banco na fase 2).
ANTIGOS = {
    'governanca-kpis-compras-abastecimento::kpis', 'governanca-kpis-rh-admissao::kpis', 'governanca-app-escala::kpis',
    'governanca-kpis-rh-experiencias::kpis', 'governanca-kpis-rh-feriados::kpis', 'governanca-kpis-rh-ferias::kpis',
    'governanca-kpis-rh-solicitacoes::kpis', 'governanca-kpis-rh-performance::geral', 'governanca-kpis-rh-semanal::indicadores',
    'governanca-kpis-rh-armarios::all', 'governanca-kpis-rh-estoqueadm::all', 'governanca-kpis-tatahouse-cardapio::extrair-csv',
    'governanca-parceiros-sistemas::editar', 'governanca-parceiros-sistemas::excluir',
}
SECOES_SEM_BYPASS = {'App'}


def ler(pasta, nome, campos):
    fp = os.path.join(pasta, nome)
    if not os.path.exists(fp):
        return []
    out = []
    for ln in open(fp, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if not ln.strip():
            continue
        f = ln.split('|')
        f += [''] * (campos - len(f))
        out.append(f)
    return out


def lista(s):
    return [x for x in s.split(',') if x]


def texto_do_elemento(src, fim_tag, tag):
    """Texto visível do elemento (sem SVG/tags), até o fechamento da mesma tag."""
    fecha = src.find('</' + tag, fim_tag)
    if fecha < 0 or fecha - fim_tag > 4000:
        return ''
    miolo = src[fim_tag:fecha]
    miolo = re.sub(r'<svg.*?</svg>', ' ', miolo, flags=re.S)
    miolo = re.sub(r'<[^>]+>', ' ', miolo)
    miolo = html.unescape(re.sub(r'\s+', ' ', miolo)).strip()
    return miolo if len(miolo) <= 60 else miolo[:57] + '…'


def varrer_html(raiz):
    paginas = {}  # pagina_id -> {arquivo, ids: OrderedDict(chave -> {tipo_html, label, n})}
    for base, _, arquivos in os.walk(raiz):
        for nome in sorted(arquivos):
            if not nome.endswith('.html'):
                continue
            fp = os.path.join(base, nome)
            src = open(fp, encoding='utf-8', errors='replace').read()
            m = RE_PAGE_ID.search(src)
            if not m:
                continue
            pid = m.group(1)
            pg = paginas.setdefault(pid, {'arquivo': fp, 'ids': OrderedDict()})
            for t in RE_TAG.finditer(src):
                tag, antes, attr, chave, depois = t.groups()
                if '::' not in chave or '+' in chave or '{' in chave:
                    continue
                attrs = antes + ' ' + depois
                mc = RE_CLASS.search(attrs)
                cls = mc.group(1) if mc else ''
                tipo = 'aba' if ('tab-btn' in cls.split() and attr == 'aba') else 'botao'
                label = texto_do_elemento(src, t.end(), tag)
                if not label:
                    tm = RE_TITLE.search(attrs)
                    label = html.unescape(tm.group(1)) if tm else ''
                d = pg['ids'].setdefault(chave, {'tipo': tipo, 'label': label, 'n': 0, 'attr': attr})
                d['n'] += 1
                if not d['label'] and label:
                    d['label'] = label
    return paginas


def nome_curto(pessoas):
    PULA = {'jr', 'sr', 'filho', 'neto', 'de', 'da', 'do', 'dos', 'das', 'e'}
    curto = {}
    for m, p in pessoas.items():
        partes = p['nome'].split()
        sobren = [x for x in partes[1:] if x.lower() not in PULA]
        curto[m] = partes[0] + (' ' + sobren[-1] if sobren else '')
    # colisão → primeiro + segundo nome
    vistos = defaultdict(list)
    for m, c in curto.items():
        vistos[c].append(m)
    for c, ms in vistos.items():
        if len(ms) > 1:
            for m in ms:
                partes = pessoas[m]['nome'].split()
                curto[m] = ' '.join(partes[:2])
    return curto


def esc(s):
    return html.escape(str(s), quote=True)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    pasta, saida = sys.argv[1], sys.argv[2]
    raiz_repo = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
    pessoas = OrderedDict()
    for f in ler(pasta, 'pessoas.txt', 6):
        pessoas[f[0]] = {'nome': f[1], 'cargo': f[2], 'unidade': f[3], 'perfil': f[4], 'ativo': f[5] == 'Ativo'}
    nc = nome_curto(pessoas)
    admins = [m for m, p in pessoas.items() if p['perfil'] == 'admin' and p['ativo']]

    pags_db = OrderedDict()
    for f in ler(pasta, 'paginas.txt', 7):
        pags_db[f[0]] = {'label': f[1], 'secao': f[2] or 'Sem seção', 'sub': f[3], 'url': f[4], 'ativo': f[5] == '1',
                         'acesso': lista(f[6])}
    cat = OrderedDict()
    for f in ler(pasta, 'catalogo.txt', 8):
        cat[f[0]] = {'pagina': f[1], 'label': f[2], 'tipo': f[3], 'ordem': f[4], 'ativo': f[5] == '1',
                     'bloq': lista(f[6]), 'lib': lista(f[7])}
    valores = {f[0]: lista(f[1]) for f in ler(pasta, 'valores.txt', 2)}

    html_pags = varrer_html(os.path.join(raiz_repo, 'compliance'))

    def ativo(m):
        return m in pessoas and pessoas[m]['ativo']

    def ve_pagina(pid):
        """matrículas ativas (não-admin) com acesso explícito + se admin passa direto."""
        pg = pags_db.get(pid)
        explicitos = [m for m in (pg['acesso'] if pg else []) if ativo(m)]
        bypass = not (pg and pg['secao'] in SECOES_SEM_BYPASS)
        return explicitos, bypass

    def ordena(ms):
        return sorted(set(ms), key=lambda m: nc.get(m, m).lower())

    def nomes(ms):
        return ', '.join(esc(nc.get(m, m)) for m in ordena(ms))

    atencao = OrderedDict((k, []) for k in [
        'sem_registro', 'antigos', 'so_banco', 'desativados', 'pagina_sem_registro', 'inativos', 'sem_efeito', 'so_admin_pagina'])

    # ---------- por página ----------
    ordem_pids = list(pags_db.keys()) + sorted(p for p in html_pags if p not in pags_db)
    secoes = OrderedDict()
    por_pessoa = defaultdict(lambda: OrderedDict())  # m -> pid -> {'abas_esc': [], 'botoes': []}
    tot = {'aba': 0, 'botao': 0}

    for pid in ordem_pids:
        pdb = pags_db.get(pid)
        ph = html_pags.get(pid)
        if pdb is None and ph is None:
            continue
        secao = pdb['secao'] if pdb else 'Sem registro no banco'
        explicitos, bypass = ve_pagina(pid)
        nao_admin = [m for m in explicitos if not (bypass and m in admins)]
        if pdb is None:
            atencao['pagina_sem_registro'].append((pid, ph['arquivo']))
        elif not nao_admin and bypass and pdb['ativo']:
            atencao['so_admin_pagina'].append((pid, pdb['label']))
        for m in (pdb['acesso'] if pdb else []):
            if m in pessoas and not pessoas[m]['ativo']:
                atencao['inativos'].append((m, pid))
            if ativo(m) and not (bypass and m in admins):
                por_pessoa[m].setdefault(pid, {'abas_esc': [], 'botoes': []})

        linhas = []
        chaves = OrderedDict()
        for k, d in (ph['ids'].items() if ph else []):
            chaves[k] = {'html': d}
        for k, c in cat.items():
            if c['pagina'] == pid:
                chaves.setdefault(k, {})['db'] = c
        for k, v in chaves.items():
            d, c = v.get('html'), v.get('db')
            tipo = (c['tipo'] if c else d['tipo'])
            label = (c['label'] if c and c['label'] else (d['label'] if d else ''))
            slug = k.split('::', 1)[1] if '::' in k else k
            flag, quem, cls = '', '', ''
            if tipo == 'valor':
                lib = [m for m in valores.get(k, []) if ativo(m)]
                ger = [m for m in valores.get('geral', []) if ativo(m)]
                quem = ('Liberado: ' + nomes(lib) if lib else 'Ninguém liberado na área') + \
                       (' · área "geral": ' + nomes(ger) if ger else '')
                linhas.append((tipo, label, k, quem, 'Valor em R$ (mascarado no servidor)', ''))
                continue
            if d and not c:
                flag = 'Sem registro no banco — ' + ('aparece para todos que veem a página' if tipo == 'botao'
                                                      else 'não dá para esconder no painel')
                cls = 'warn'
                atencao['sem_registro'].append((pid, k, label, tipo))
            elif c and not d:
                if k in ANTIGOS:
                    flag, cls = 'Nome antigo — apagar do banco (fase 2)', 'old'
                    atencao['antigos'].append((pid, k))
                else:
                    flag, cls = 'Só no banco — não existe mais na página', 'old'
                    atencao['so_banco'].append((pid, k, label))
            if c and not c['ativo']:
                flag = (flag + ' · ' if flag else '') + 'desativado no banco'
                cls = 'old'
                atencao['desativados'].append((pid, k, label))
            if d:
                tot[tipo if tipo in tot else 'botao'] += 1
            base = [m for m in nao_admin]
            if tipo == 'aba':
                bloq = [m for m in (c['bloq'] if c else []) if ativo(m)]
                efet = [m for m in bloq if m in base]
                sem = [m for m in bloq if m not in base]
                if sem:
                    atencao['sem_efeito'].append((k, 'bloqueio', sem))
                if not base:
                    quem = 'Só admins' if bypass else 'Ninguém'
                elif len(efet) == len(base):
                    quem = 'Só admins (todos os demais estão bloqueados)' if bypass else 'Ninguém'
                elif len(efet) > len(base) - len(efet):
                    quem = '<b>Só</b>: ' + nomes([m for m in base if m not in efet]) + \
                           ' <span class="muted">(os outros %d estão bloqueados)</span>' % len(efet)
                elif efet:
                    quem = 'Todos que veem a página, <b>menos</b>: ' + nomes(efet)
                else:
                    quem = 'Todos que veem a página'
                if d and c:
                    for m in efet:
                        por_pessoa[m][pid]['abas_esc'].append(label or slug)
            else:
                lib = [m for m in (c['lib'] if c else []) if ativo(m)]
                efet = [m for m in lib if m in base]
                sem = [m for m in lib if m not in base and not (bypass and m in admins)]
                if sem:
                    atencao['sem_efeito'].append((k, 'liberação', sem))
                if d and not c:
                    quem = 'Todos que veem a página' if base else ('Só admins' if bypass else 'Ninguém')
                elif efet:
                    quem = nomes(efet)
                else:
                    quem = 'Só admins' if bypass else 'Ninguém'
                if d and c:
                    for m in efet:
                        por_pessoa[m][pid]['botoes'].append(label or slug)
                if d and not c:
                    for m in base:
                        por_pessoa[m][pid]['botoes'].append((label or slug) + ' (sem registro)')
            linhas.append((tipo, label, k, quem, flag, cls))

        secoes.setdefault(secao, []).append({
            'pid': pid, 'label': (pdb['label'] if pdb else os.path.basename(ph['arquivo'])),
            'arquivo': (os.path.relpath(ph['arquivo'], raiz_repo) if ph else (pdb['url'] or '')),
            'ativo': (pdb['ativo'] if pdb else True), 'bypass': bypass,
            'acesso': nao_admin, 'linhas': linhas, 'sub': pdb['sub'] if pdb else ''})

    # ---------- HTML ----------
    T = []
    w = T.append
    n_pags_ids = sum(1 for s in secoes.values() for p in s if any(l[0] != 'valor' for l in p['linhas']))
    pess_ativas = [m for m in por_pessoa if ativo(m) and m not in admins]
    n_atencao = sum(len(v) for v in atencao.values())
    w('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<title>Ids de acesso</title>'
      '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
      '<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700;800&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">'
      '<style>' + CSS + '</style></head><body>')
    w('<header class="top"><div class="h1">Ids de acesso · quem vê o quê</div>'
      f'<div class="sub">Portal Líderes · gerado em {date.today().strftime("%d/%m/%Y")} · ids lidos do HTML do repositório, '
      'acessos lidos do banco (tata_plus). Documento interno — tem nomes de pessoas, não publicar.</div></header>')
    w('<div class="kpis">'
      f'<div class="kpi"><span class="kl">Páginas com ids</span><span class="kn">{n_pags_ids}</span></div>'
      f'<div class="kpi"><span class="kl">Abas</span><span class="kn">{tot["aba"]}</span></div>'
      f'<div class="kpi"><span class="kl">Botões</span><span class="kn">{tot["botao"]}</span></div>'
      f'<div class="kpi"><span class="kl">Pessoas com acesso</span><span class="kn">{len(pess_ativas)}</span><span class="ks">+ {len(admins)} admins</span></div>'
      '</div>')
    w('<div class="wrap">')
    w('<div class="card regras"><div class="ct">Como ler</div><ul>'
      '<li><span class="pill aba">Aba</span> todo mundo que vê a página vê a aba — some só para quem foi <b>bloqueado</b>.</li>'
      '<li><span class="pill botao">Botão</span> fica escondido — aparece só para quem foi <b>liberado</b>.</li>'
      f'<li><b>Admins veem tudo</b> (páginas, abas e botões): {nomes(admins)}. Exceção: a seção App do Plus.</li>'
      '<li>Pessoa inativa não entra na lista de quem vê (aparece em Pontos de atenção se ainda tiver acesso).</li>'
      '</ul></div>')

    # pontos de atenção
    w(f'<details class="card atencao" open><summary><span class="ct">Pontos de atenção ({n_atencao})</span></summary>')
    def bloco(titulo, itens, fmt):
        if not itens:
            return
        w(f'<div class="at-t">{titulo} <span class="cnt">{len(itens)}</span></div><ul class="at">')
        for it in itens:
            w('<li>' + fmt(it) + '</li>')
        w('</ul>')
    lbl = lambda pid: esc(pags_db[pid]['label'] if pid in pags_db else pid)
    bloco('Id na página sem registro no banco (o painel não controla; botão aparece para todos que veem a página)',
          atencao['sem_registro'], lambda x: f'{lbl(x[0])} — <b>{esc(x[2] or "")}</b> <code>{esc(x[1])}</code> ({"aba" if x[3]=="aba" else "botão"})')
    bloco('Página fora do cadastro de páginas do banco: só admins entram (confira se ainda é usada)',
          atencao['pagina_sem_registro'], lambda x: f'<code>{esc(x[0])}</code> — {esc(os.path.relpath(x[1], raiz_repo))}')
    bloco('Nome antigo ainda no banco (apagar na fase 2, depois que o app mostrar a versão nova)',
          atencao['antigos'], lambda x: f'{lbl(x[0])} — <code>{esc(x[1])}</code>')
    bloco('Id só no banco, sem botão/aba na página (sobra ou função que saiu)',
          atencao['so_banco'], lambda x: f'{lbl(x[0])} — <b>{esc(x[2])}</b> <code>{esc(x[1])}</code>')
    bloco('Id desativado no banco', atencao['desativados'], lambda x: f'{lbl(x[0])} — <b>{esc(x[2])}</b> <code>{esc(x[1])}</code>')
    inat = defaultdict(list)
    for m, pid in atencao['inativos']:
        inat[m].append(pid)
    bloco('Pessoa inativa que ainda tem acesso a páginas (limpar no painel)',
          list(inat.items()), lambda x: f'<b>{esc(pessoas[x[0]]["nome"])}</b> ({esc(pessoas[x[0]]["cargo"])}) — {len(x[1])} páginas')
    bloco('Liberação/bloqueio sem efeito (a pessoa não vê a página — ou é admin)',
          atencao['sem_efeito'], lambda x: f'<code>{esc(x[0])}</code> — {x[1]} para {nomes(x[2])}')
    bloco('Página cadastrada que só admins veem (ninguém mais tem acesso)',
          atencao['so_admin_pagina'], lambda x: f'{esc(x[1])} <code>{esc(x[0])}</code>')
    w('</details>')

    # abas da visão
    w('<div class="vis"><button class="vb on" data-v="pg" onclick="vis(\'pg\')">Por página</button>'
      '<button class="vb" data-v="ps" onclick="vis(\'ps\')">Por pessoa</button>'
      '<input id="busca" class="busca" placeholder="Buscar página, id ou pessoa…" oninput="filtra(this.value)"></div>')

    w('<div id="v-pg">')
    for secao, pags in secoes.items():
        w(f'<div class="sec">{esc(secao)}</div>')
        for p in pags:
            busca = ' '.join([p['label'], p['pid'], p['arquivo']] + [l[2] for l in p['linhas']]
                             + [nc.get(m, m) for m in p['acesso']]).lower()
            w(f'<div class="card pg" data-b="{esc(busca)}">')
            w(f'<div class="pg-h"><div><div class="pg-t">{esc(p["label"])}'
              + (' <span class="tag">inativa</span>' if not p['ativo'] else '') + '</div>'
              f'<div class="pg-f">{esc(p["arquivo"])} · <code>{esc(p["pid"])}</code></div></div></div>')
            ac = p['acesso']
            w('<div class="acc"><span class="acc-l">Acesso à página</span> ')
            if ac:
                w(f'<span class="acc-n">{len(ac)}</span> ' + nomes(ac))
            else:
                w('<span class="muted">ninguém além dos admins</span>' if p['bypass'] else '<span class="muted">ninguém</span>')
            w(' <span class="muted">' + ('+ admins' if p['bypass'] else '(seção App: admin não entra direto)') + '</span></div>')
            if p['linhas']:
                w('<div class="ids">')
                for tipo, label, k, quem, flag, cls in p['linhas']:
                    pill = {'aba': 'Aba', 'botao': 'Botão', 'valor': 'Valor'}.get(tipo, tipo)
                    w(f'<div class="id {cls}"><div class="id-a"><span class="pill {esc(tipo)}">{pill}</span>'
                      f'<div><div class="id-n">{esc(label or "—")}</div><code class="id-k">{esc(k)}</code></div></div>'
                      f'<div class="id-q">{quem}' + (f'<div class="flag">{esc(flag)}</div>' if flag else '') + '</div></div>')
                w('</div>')
            else:
                w('<div class="muted small">Sem abas ou botões controlados.</div>')
            w('</div>')
    w('</div>')

    # por pessoa
    w('<div id="v-ps" hidden>')
    w('<div class="card"><div class="muted small">Admins veem tudo (menos a seção App do Plus, que precisa de liberação): '
      + nomes(admins) + '. Abaixo, as demais pessoas ativas: páginas que abrem, abas escondidas e botões liberados.</div></div>')
    for m in sorted(pess_ativas, key=lambda x: nc[x].lower()):
        p = pessoas[m]
        pgs = por_pessoa[m]
        busca = ' '.join([p['nome'], p['cargo'], p['unidade']] + [pags_db[x]['label'] if x in pags_db else x for x in pgs]).lower()
        w(f'<details class="card ps" data-b="{esc(busca)}"><summary><div class="ps-t">{esc(p["nome"])}</div>'
          f'<div class="pg-f">{esc(p["cargo"])} · {esc(p["unidade"])} · mat. {esc(m)} · <b>{len(pgs)}</b> páginas</div></summary>')
        w('<div class="ps-l">')
        simples = [pags_db[x]['label'] if x in pags_db else x for x, i in pgs.items() if not i['abas_esc'] and not i['botoes']]
        if simples:
            w('<div class="ps-i"><div class="small"><span class="pos">Abre, no padrão da página:</span> ' + esc(', '.join(simples)) + '</div></div>')
        for pid, info in pgs.items():
            if not info['abas_esc'] and not info['botoes']:
                continue
            nome_pg = pags_db[pid]['label'] if pid in pags_db else pid
            extra = []
            if info['abas_esc']:
                extra.append('<span class="neg">Abas escondidas:</span> ' + esc(', '.join(info['abas_esc'])))
            if info['botoes']:
                extra.append('<span class="pos">Botões:</span> ' + esc(', '.join(info['botoes'])))
            w(f'<div class="ps-i"><div class="ps-p">{esc(nome_pg)}</div>' + (''.join(f'<div class="small">{e}</div>' for e in extra)) + '</div>')
        w('</div></details>')
    w('</div></div>')
    w('<script>' + JS + '</script></body></html>')
    open(saida, 'w', encoding='utf-8').write(''.join(T))
    print(f'ok: {saida}  páginas={sum(len(s) for s in secoes.values())} abas={tot["aba"]} botões={tot["botao"]} '
          f'pessoas={len(pess_ativas)} admins={len(admins)} atenção={n_atencao}')
    for k, v in atencao.items():
        print(f'  {k}: {len(v)}')


CSS = """
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#F4F4F4;--surface:#FFF;--carbon:#35383F;--citric:#CFFF00;--text:#111;--mid:#555;--muted:#999;--border:#E2E2E2;
--amber:#7A4A00;--amber-bg:#FFF4DC;--red:#7A1A1A;--red-bg:#FDEAEA;--blue:#1A3A5C;--blue-bg:#E8F0FA;--radius:8px}
body{font-family:'DM Sans',sans-serif;background:var(--bg);color:var(--text);font-size:14px;line-height:1.45}
code{font-family:'DM Mono',monospace;font-size:11px;color:var(--mid);word-break:break-all}
b{font-weight:700}
.top{background:var(--carbon);color:#fff;padding:18px 16px}
.h1{font-size:18px;font-weight:700;color:var(--citric)}
.sub{font-size:12px;color:rgba(255,255,255,.7);margin-top:4px}
.kpis{background:var(--surface);border-bottom:1px solid var(--border);padding:14px 16px;display:grid;grid-template-columns:1fr 1fr;gap:10px}
.kpi{background:var(--bg);border:1px solid var(--border);border-radius:var(--radius);padding:12px;display:flex;flex-direction:column;align-items:center;gap:4px;text-align:center}
.kl{font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.8px;text-transform:uppercase;color:var(--carbon)}
.kn{font-size:28px;font-weight:700;color:var(--carbon);line-height:1;font-variant-numeric:tabular-nums}
.ks{font-family:'DM Mono',monospace;font-size:11px;color:var(--muted)}
.wrap{padding:14px 12px 60px;max-width:1100px}
.card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:14px 16px;margin-bottom:12px}
.ct{font-family:'DM Mono',monospace;font-size:11px;font-weight:700;letter-spacing:.8px;text-transform:uppercase;color:var(--carbon)}
.regras ul{margin-top:10px;padding-left:0;list-style:none;display:flex;flex-direction:column;gap:8px;font-size:13px;color:var(--mid)}
.pill{display:inline-flex;align-items:center;justify-content:center;min-width:48px;padding:3px 9px;border-radius:100px;font-size:10px;font-weight:500;letter-spacing:.3px;white-space:nowrap;flex-shrink:0}
.pill.aba{background:var(--blue-bg);color:var(--blue)}
.pill.botao{background:var(--carbon);color:var(--citric)}
.pill.valor{background:var(--amber-bg);color:var(--amber)}
details>summary{cursor:pointer;list-style:none}
details>summary::-webkit-details-marker{display:none}
details>summary::after{content:'▾';float:right;color:var(--muted)}
details[open]>summary::after{content:'▴'}
.atencao{border-color:#E9D9AE}
.at-t{font-size:13px;font-weight:700;color:var(--carbon);margin:14px 0 6px}
.cnt{display:inline-block;background:var(--amber-bg);color:var(--amber);border-radius:100px;font-size:10px;padding:1px 8px;margin-left:4px}
ul.at{list-style:none;display:flex;flex-direction:column;gap:4px;font-size:12.5px;color:var(--mid)}
ul.at li{padding:6px 8px;background:var(--bg);border-radius:6px}
.vis{position:sticky;top:0;z-index:5;background:var(--bg);padding:8px 0;display:flex;gap:8px;flex-wrap:wrap;align-items:center}
.vb{font-family:'DM Sans',sans-serif;font-size:12px;font-weight:500;padding:9px 14px;border-radius:100px;border:1px solid var(--border);background:var(--surface);color:var(--carbon);cursor:pointer}
.vb.on{background:var(--carbon);color:var(--citric);border-color:var(--carbon)}
.busca{flex:1;min-width:180px;font-family:'DM Sans',sans-serif;font-size:13px;padding:9px 12px;border:1px solid var(--border);border-radius:var(--radius);background:var(--surface)}
.sec{font-family:'DM Mono',monospace;font-size:11px;letter-spacing:.8px;text-transform:uppercase;color:var(--muted);margin:18px 4px 8px}
.pg-t,.ps-t{font-size:15px;font-weight:700;color:var(--carbon)}
.pg-f{font-size:11.5px;color:var(--muted);margin-top:2px}
.tag{font-size:10px;background:var(--red-bg);color:var(--red);border-radius:100px;padding:1px 8px;vertical-align:middle}
.acc{margin-top:10px;font-size:12.5px;color:var(--mid);padding:8px 10px;background:var(--bg);border-radius:6px}
.acc-l{font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.8px;text-transform:uppercase;color:var(--carbon);margin-right:4px}
.acc-n{display:inline-block;background:var(--carbon);color:var(--citric);border-radius:100px;font-size:10px;font-weight:700;padding:1px 7px;margin-right:2px}
.ids{margin-top:10px;border-top:1px solid var(--border)}
.id{display:grid;grid-template-columns:1fr;gap:6px;padding:10px 2px;border-bottom:1px solid var(--border)}
.id-a{display:flex;gap:10px;align-items:flex-start}
.id-n{font-size:13.5px;font-weight:500;color:var(--carbon)}
.id-q{font-size:12.5px;color:var(--mid);padding-left:2px}
.flag{margin-top:4px;font-size:11.5px;font-weight:500}
.id.warn .flag{color:var(--amber)}
.id.warn{background:linear-gradient(90deg,var(--amber-bg),transparent 60%)}
.id.old{opacity:.6}
.id.old .flag{color:var(--red)}
.muted{color:var(--muted)}
.small{font-size:12px}
.neg{color:var(--red);font-weight:500}
.pos{color:var(--carbon);font-weight:700}
.ps-l{margin-top:10px;display:flex;flex-direction:column;gap:6px}
.ps-i{padding:8px 10px;background:var(--bg);border-radius:6px;color:var(--mid)}
.ps-p{font-size:13px;font-weight:500;color:var(--carbon)}
@media (min-width:768px){
 .kpis{grid-template-columns:repeat(4,1fr);padding:14px 24px}
 .wrap{padding:16px 24px 60px}
 .id{grid-template-columns:minmax(0,1fr) minmax(0,1.2fr);gap:16px;align-items:start}
}
"""

JS = """
function vis(v){document.getElementById('v-pg').hidden=v!=='pg';document.getElementById('v-ps').hidden=v!=='ps';
 document.querySelectorAll('.vb').forEach(function(b){b.classList.toggle('on',b.dataset.v===v)});}
function filtra(q){q=(q||'').toLowerCase().trim();document.querySelectorAll('[data-b]').forEach(function(el){
 el.style.display=(!q||el.dataset.b.indexOf(q)>=0)?'':'none';});}
"""

if __name__ == '__main__':
    main()
