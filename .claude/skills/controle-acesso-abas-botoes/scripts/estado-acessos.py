#!/usr/bin/env python3
"""
Gera o `estado.json` da TABELA DE ACESSOS (assets/matriz-acessos.html): por página,
quem abre a página e, para cada aba / botão / valor, quem vê — no formato que a
tabela usa para o dono clicar "incluir" / "tirar" e deixar as mudanças para o Claude.

Usa os mesmos arquivos de dump do `relatorio-acessos.py` (pessoas.txt, paginas.txt,
catalogo.txt, valores.txt — os SQLs estão no topo daquele script) e lê os ids do HTML.

⚠️ O estado.json tem nomes de pessoas: gere no scratchpad, nunca no repo.

Uso:
    python3 .claude/skills/controle-acesso-abas-botoes/scripts/estado-acessos.py <pasta_dump> <saida.json> [raiz]

[raiz] = pasta que contém `compliance/` (padrão: o repo). Use uma cópia do main
(`git archive origin/main compliance | tar -x -C <pasta>`) quando o repo tiver edições em andamento.
"""
import importlib.util
import json
import os
import sys
from datetime import datetime, timedelta, timezone

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('relatorio', os.path.join(AQUI, 'relatorio-acessos.py'))
rel = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rel)

SECOES_SEM_BYPASS = rel.SECOES_SEM_BYPASS


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    pasta, saida = sys.argv[1], sys.argv[2]
    raiz_repo = sys.argv[3] if len(sys.argv) > 3 else os.path.abspath(os.path.join(AQUI, '..', '..', '..', '..'))

    pessoas = {}
    for f in rel.ler(pasta, 'pessoas.txt', 6):
        pessoas[f[0]] = {'nome': f[1], 'cargo': f[2], 'unidade': f[3], 'perfil': f[4], 'ativo': f[5] == 'Ativo'}
    curto = rel.nome_curto(pessoas)
    ativos = {m for m, p in pessoas.items() if p['ativo']}

    cat = {}
    for f in rel.ler(pasta, 'catalogo.txt', 8):
        cat[f[0]] = {'pagina': f[1], 'label': f[2], 'tipo': f[3], 'ordem': int(f[4] or 0), 'ativo': f[5] == '1',
                     'bloq': rel.lista(f[6]), 'lib': rel.lista(f[7])}
    valores = {f[0]: rel.lista(f[1]) for f in rel.ler(pasta, 'valores.txt', 2)}
    html_pags = rel.varrer_html(os.path.join(raiz_repo, 'compliance'))

    paginas = []
    for f in rel.ler(pasta, 'paginas.txt', 7):
        pid, label, secao, sub, url, ativo, acesso = f[0], f[1], f[2] or 'Sem seção', f[3], f[4], f[5] == '1', rel.lista(f[6])
        if not ativo:
            continue
        ph = html_pags.get(pid)
        itens = []
        vistos = set()
        # 1) na ordem em que aparecem no HTML (abas primeiro, depois botões do menu, depois da página)
        html_ids = list(ph['ids'].items()) if ph else []
        def chave_ordem(kv):
            k, d = kv
            c = cat.get(k)
            t = c['tipo'] if c else d['tipo']
            return (0 if t == 'aba' else (1 if d.get('menu') else 2), c['ordem'] if c else 9999)
        for k, d in sorted(html_ids, key=chave_ordem):
            c = cat.get(k)
            tipo = c['tipo'] if c else d['tipo']
            itens.append({'id': k, 'tipo': tipo, 'label': (c['label'] if c and c['label'] else d['label']) or k.split('::')[-1],
                          'slug': k.split('::', 1)[-1], 'menu': bool(d.get('menu')), 'cadastrado': bool(c),
                          'bloq': sorted(m for m in (c['bloq'] if c else []) if m in ativos),
                          'lib': sorted(m for m in (c['lib'] if c else []) if m in ativos)})
            vistos.add(k)
        # 2) o que só está no banco (controlado pelo servidor, ex.: Armários incluir/excluir) — sem os nomes antigos
        for k, c in sorted(cat.items(), key=lambda kv: kv[1]['ordem']):
            if c['pagina'] != pid or k in vistos or k in rel.ANTIGOS or not c['ativo']:
                continue
            if c['tipo'] == 'valor':
                # valor NÃO tem bypass de admin: vê quem está liberado na área ou na área 'geral' (todas)
                itens.append({'id': k, 'tipo': 'valor', 'label': c['label'] or 'Valores em R$', 'slug': k, 'menu': False,
                              'cadastrado': True, 'bloq': [], 'lib': sorted(m for m in valores.get(k, []) if m in ativos),
                              'geral': sorted(m for m in valores.get('geral', []) if m in ativos)})
            else:
                itens.append({'id': k, 'tipo': c['tipo'], 'label': c['label'], 'slug': k.split('::', 1)[-1], 'menu': False,
                              'cadastrado': True, 'so_banco': True,
                              'bloq': sorted(m for m in c['bloq'] if m in ativos),
                              'lib': sorted(m for m in c['lib'] if m in ativos)})
        paginas.append({'id': pid, 'label': label, 'secao': secao, 'sub': sub,
                        'arquivo': os.path.relpath(ph['arquivo'], raiz_repo) if ph else url,
                        'existe': bool(ph) or url.startswith('app://'),
                        'adminVeTudo': secao not in SECOES_SEM_BYPASS,
                        'acesso': sorted(m for m in acesso if m in ativos), 'itens': itens})

    # páginas do repo fora do controle: sem GOV_PAGE_ID (abrem sem gate) e com id mas sem cadastro no banco.
    # ABERTAS_DE_PROPOSITO não entram em semId: ficam sem gate por decisão do dono.
    ABERTAS_DE_PROPOSITO = {'compliance/areas/organograma2.html'}   # 04/10/2026
    no_banco = {p['id'] for p in paginas} | {f[0] for f in rel.ler(pasta, 'paginas.txt', 7)}
    sem_id = []
    for base, _, arqs in os.walk(os.path.join(raiz_repo, 'compliance')):
        for nome in sorted(arqs):
            if nome.endswith('.html'):
                fp = os.path.join(base, nome)
                if not rel.RE_PAGE_ID.search(open(fp, encoding='utf-8', errors='replace').read()) \
                        and os.path.relpath(fp, raiz_repo) not in ABERTAS_DE_PROPOSITO:
                    sem_id.append(os.path.relpath(fp, raiz_repo))
    fora = [{'id': pid, 'arquivo': os.path.relpath(ph['arquivo'], raiz_repo), 'ids': len(ph['ids'])}
            for pid, ph in sorted(html_pags.items()) if pid not in no_banco]

    gente = []
    for m, p in sorted(pessoas.items(), key=lambda kv: curto[kv[0]].lower()):
        if not p['ativo']:
            continue
        gente.append({'m': m, 'nome': p['nome'], 'curto': curto[m], 'cargo': p['cargo'], 'unidade': p['unidade'],
                      'admin': p['perfil'] == 'admin'})

    agora = datetime.now(timezone(timedelta(hours=-3)))
    estado = {'gerado': agora.strftime('%d/%m/%Y %H:%M'), 'pessoas': gente, 'paginas': paginas,
              'semId': sorted(sem_id), 'foraDoBanco': fora}
    json.dump(estado, open(saida, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    n_itens = sum(len(p['itens']) for p in paginas)
    print(f'ok: {saida}  páginas={len(paginas)} itens={n_itens} pessoas={len(gente)} '
          f'sem_cadastro={sum(1 for p in paginas for i in p["itens"] if not i["cadastrado"])} '
          f'sem_GOV_PAGE_ID={len(sem_id)} fora_do_banco={len(fora)}')


if __name__ == '__main__':
    main()
