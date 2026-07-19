# TEMPORÁRIO — Páginas `-portal` dos atalhos (APAGAR DEPOIS)

> Registro de rastreio. Estas páginas são uma **ponte temporária** e devem ser
> **apagadas** quando o login antigo do portal (`index.html` / Apps Script) for
> aposentado ou quando os atalhos do dashboard passarem a abrir via Tatá Plus.
> Criadas em 2026-07-19 (PR #2280).

## Por que existem
Os 9 atalhos do dashboard do `index.html` (portal de líderes) apontam para
páginas que foram migradas para o **modelo novo** (`gate.js`), que só abre
embutido no Tatá Plus e **nega** quando aberto direto no portal. Para os atalhos
continuarem funcionando pelo portal, duplicamos essas páginas no **modelo antigo**
(gate inline `lideres_session`, abre direto) com o sufixo `-portal`. Os originais
seguem no modelo novo, para uso via Plus.

## Arquivos a APAGAR (as cópias `-portal`, modelo antigo)
- [ ] `compliance/kpis/rh/recrutamento-portal.html`
- [ ] `compliance/kpis/rh/solicitacoes-portal.html`
- [ ] `compliance/kpis/rh/absenteismo-portal.html`
- [ ] `compliance/kpis/rh/experiencias-portal.html`
- [ ] `compliance/kpis/rh/bancodehoras-portal.html`
- [ ] `compliance/kpis/manutencao/index-portal.html`
- [ ] `compliance/kpis/rh/estoqueadm-portal.html`
- [ ] `compliance/kpis/rh/feriados-portal.html`
- [ ] `compliance/areas/rh/brainstorm-portal.html`

## O que reverter no `index.html` ao apagar
Os 9 atalhos do dashboard apontam hoje para as cópias `-portal`. Ao apagar as
cópias, reapontar cada atalho para o destino definitivo (o original no modelo
novo, ou para a rota do Plus, conforme a decisão da época):

| Atalho | Aponta hoje (temporário) | Original (modelo novo / Plus) |
|---|---|---|
| Recrutamento | kpis/rh/recrutamento-portal.html | kpis/rh/recrutamento.html |
| Solicitações | kpis/rh/solicitacoes-portal.html | kpis/rh/solicitacoes.html |
| Absenteísmo | kpis/rh/absenteismo-portal.html | kpis/rh/absenteismo.html |
| Experiência | kpis/rh/experiencias-portal.html | kpis/rh/experiencias.html |
| Banco de Horas | kpis/rh/bancodehoras-portal.html | kpis/rh/bancodehoras.html |
| Manutenção | kpis/manutencao/index-portal.html | kpis/manutencao/index.html |
| Uniforme e EPI's | kpis/rh/estoqueadm-portal.html | kpis/rh/estoqueadm.html |
| Feriados | kpis/rh/feriados-portal.html | kpis/rh/feriados.html |
| Brainstorm | areas/rh/brainstorm-portal.html | areas/rh/brainstorm.html |

## Atenção enquanto existirem
Cada uma dessas 9 páginas tem **duas cópias** (`-portal` antiga + original nova).
Edições de conteúdo/dados precisam ser replicadas nas duas, senão divergem.
