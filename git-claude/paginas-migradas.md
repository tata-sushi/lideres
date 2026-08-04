# Páginas migradas — Google Sheets → Supabase

Registro das páginas do front que deixaram de consumir Google Sheets/Apps Script e passaram a usar o Supabase (RPCs). Atualizar a cada migração.

> Padrão: tabela de dado em `dp_rh` (privado) · RPC `SECURITY DEFINER` em `tata_plus` (só `authenticated`) · front chama via `supa.schema('tata_plus').rpc(...)`. Ver `migracao.md` (Regras fixas).

## Repositório `tata-sushi/lideres` (portal / front)

| Página | Módulo | O que migrou | Objeto Supabase | PR | Status |
|---|---|---|---|---|---|
| `compliance/kpis/rh/ouvidoria.html` | Ouvidoria (dashboard) | Leitura das ocorrências | `tata_plus.ouvidoria_listar()` | #2507 | ✅ merge |
| `compliance/kpis/rh/semanal.html` | Report › Alinhamentos | Demandas (→ Kanban) + Transcrição | `demandas_lista()` · `alinhamento_transcricao_listar()` | #2519 | ✅ merge |
| `compliance/kpis/rh/estoqueadm.html` | Estoque Admin (Uniformes/EPI) | Saldo, histórico e **gravação** de movimentos | tabela `dp_rh.estoque_admin` + `estoque_admin_saldo()` / `estoque_admin_posicao()` / `estoque_admin_gravar()` | #2527 #2528 #2529 #2530 #2534 | ✅ merge |
| `compliance/kpis/rh/recrutamento2.html` | Recrutamento (Power BI) | Drawer "Sobre" (contagens) | `tata_plus.colaboradores_listar()` | #2539 | ✅ merge |
| `compliance/kpis/rh/solicitacoes2.html` | Solicitações (Power BI) | Drawer "Sobre" (contagens) | `tata_plus.colaboradores_listar()` | #2539 | ✅ merge |
| `compliance/areas/rh/admissao.html` | Admissão & Integração | Lista de colaboradores (drawer + select) + data de admissão | `tata_plus.colaboradores_listar()` (perfis ativos) | #2542 | ✅ merge |
| `compliance/areas/rh/sancoes.html` | Sanções Disciplinares | Dropdown de colaborador (com filtro por unidade) | `tata_plus.colaboradores_listar()` | #2544 | ✅ merge |

## Outros repositórios

| Repo / Arquivo | Módulo | O que migrou | Objeto Supabase | PR | Status |
|---|---|---|---|---|---|
| `tata-sushi/ouvidoria` · `index.html` | Ouvidoria (form público) | Gravação da ocorrência | `public.ouvidoria_registrar(payload)` (anon) | #37 | ✅ merge |
| `tata-sushi/plus` · `src/routes/Ouvidoria.jsx` | Ouvidoria (form do app) | Gravação da ocorrência | `public.ouvidoria_registrar(payload)` | #446 | ⏳ aberto (app-side) |

## RPCs de apoio criadas

| RPC | Uso | Fonte |
|---|---|---|
| `tata_plus.colaboradores_listar()` | Lookup de colaboradores (dropdowns, contagens) — **reutilizável** | `tata_plus.profiles` (status = Ativo) |
| `tata_plus.ouvidoria_listar()` | Dashboard de ouvidoria | `dp_rh.ouvidoria` |
| `tata_plus.demandas_lista()` | Demandas (Kanban) | `tata_kanban` |
| `tata_plus.alinhamento_transcricao_listar()` | Transcrição de alinhamentos | `dp_rh.alinhamento_transcricao` |
| `tata_plus.estoque_admin_saldo()` / `estoque_admin_posicao()` / `estoque_admin_historico()` / `estoque_admin_gravar()` | Estoque | `dp_rh.estoque_admin` |
| `public.ouvidoria_registrar(payload)` | Gravação anônima da ouvidoria | `dp_rh.ouvidoria` |

## Ainda no Google Sheets (candidatas, mesmo padrão)

- **Lookup de colaboradores** (`action=listColaboradores`) ainda em: `agenda`, `bancodehoras`, `beneficios`, `feriados`, `armarios`, `ferias`, `hc`, `medicina`, `experiencias`, e o lookup do `estoqueadm`. → troca mecânica por `colaboradores_listar()`.
- **Report `semanal.html`**: ainda tem fontes no Sheets (HC, admissões/demissões→profiles, Vagas, Banco de Horas, Absenteísmo, Experiências, Entrevistas, ASOs).
- **Sanções → Kanban**: adiado (ver `migracao.md`).
