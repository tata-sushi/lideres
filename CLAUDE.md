# Lideres - Notas do Projeto

## Drawer (menu lateral) de Compliance

O drawer aparece em 6 páginas de compliance e é o componente que sempre configuramos/atualizamos neste repositório:

- `compliance/index.html`
- `compliance/menucompliance.html`
- `compliance/areas/index.html`
- `compliance/areas/rh/index.html`
- `compliance/areas/institucional/index.html`
- `compliance/areas/rh/sancoes.html`

**Nota:** `compliance/areas/rh/estoqueadm.html` NÃO possui drawer.

### Estrutura do drawer
- Seção "Versão Atual" — nome e versão do portal
- Seção "O que é" — descrição do Governança de Processos
- Seção "Números" — KPIs (Seções, Departamentos, Parceiros, Dashboards, Páginas)
- Seção "Responsável" — rodapé fixo com responsável
- `sancoes.html` tem uma seção extra "Ferramentas" no drawer

### KPI "Páginas" (id="kpi-pages")
- Conta automaticamente os `.html` dentro de `compliance/`
- Atualizado via GitHub Action (`.github/workflows/update-page-count.yml`)
- Dispara a cada push que altera `compliance/**/*.html`

## Regra: novas páginas de compliance

Sempre que uma nova página `.html` for criada dentro de `compliance/`, ela DEVE incluir o drawer completo no padrão das outras páginas. Copiar o bloco do drawer de um arquivo existente (ex: `compliance/areas/rh/index.html`) e adaptar conforme necessário. O drawer inclui:
1. Overlay + container `.drawer`
2. Header com botão fechar
3. Body com seções: Versão Atual, O que é, Números (com todos os KPIs incluindo `id="kpi-pages"`)
4. Footer com responsável
5. Funções JS `openDrawer()` / `closeDrawer()`
6. Botão `.header-plus` no header da página para abrir o drawer
