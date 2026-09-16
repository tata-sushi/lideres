# Esquema de Fechamento — schema `fechamento` (Supabase)

> **Documento vivo.** Atualizado a cada etapa. **Nada é criado/alterado no banco sem "cria"/"ok" explícito do usuário.**
> Projeto longo, tocado **parte por parte**, no ritmo do usuário. Ele entrega cada pedaço; a gente estrutura junto.

Projeto Supabase: **TATÁ SUSHI | TATÁ POKE** — ref `aoqsbusfrffapjglpqjk`.
Branch de trabalho: `claude/sopa-esquema-fechamento-cmpqj1`.

---

## 0. Objetivo

Criar um schema **`fechamento`** que consolide o que já existe no banco (RH: cargos, pontos, colaboradores)
**+** o financeiro, para montar o **fechamento mensal** de cada colaborador:

```
salário fixo + gorjeta + prêmio + extras − descontos − adiantamentos = líquido a pagar
```

---

## 1. Regras de trabalho (fixas)

1. **Ritmo do usuário.** Vamos parte por parte. O usuário passa o que criar primeiro; nada é adiantado por conta própria.
2. **Só mexe no banco com "cria" explícito.** Levantar/planejar/desenhar pode; `CREATE/ALTER/INSERT` só com o "ok".
3. **Erro = devolver, não insistir.** Se algo falhar, parar, mostrar o erro e corrigir junto.
4. **Documento vivo.** Toda decisão e toda tabela criada é registrada aqui, com data.

## 2. Padrão de arquitetura (herdado do projeto — ver `migracao.md`)

- **Tabela** de dados fica em **schema privado** (`fechamento`) — o front **não** acessa direto.
- **Leitura/escrita do front** passa por **RPC `SECURITY DEFINER` em `tata_plus`** (`grant execute` só a `authenticated`, `revoke` de `public`/`anon`). **Nada de tabela em `tata_plus`.** RPC anônima (form público) vai no `public`.
- **Dashboard agrega no servidor** (a RPC devolve o resumo/net, poucas linhas). Nunca baixa a tabela inteira pra somar no front (teto de linhas do PostgREST).
- **Auditoria:** RPC de escrita carimba `criado_por` via `tata_plus.minha_matricula()` (não confia no front). `created_at timestamptz default now()`.

---

## 3. Decisões travadas ✅

| # | Decisão | Detalhe |
|---|---------|---------|
| 1 | **Schema novo: `fechamento`** | schema dedicado (privado), no padrão de `operacao`/`manutencao` |
| 2 | **Gorjeta lançada dia a dia por loja** | usuário digita o valor por dia/loja; o sistema soma no mês e calcula o valor do ponto |
| 3 | **Folha com catálogo de tipos flexível** | `folha_tipos` (várias categorias, o usuário cria as que quiser) + `folha_lancamentos`. Categorias iniciais: Adiantamento/Vale, Descontos, Hora extra/Extra, Prêmio/Bonificação — e outras a criar |
| 4 | **Faturamento entra, mas é coadjuvante** | base secundária no mesmo schema; não é o foco |

---

## 4. O que já existe no banco (reaproveitar)

Modelo de **pontos** de gorjeta/prêmio já montado no schema `dp_rh`:

| Objeto | Campos-chave |
|--------|--------------|
| `dp_rh.cargos` | `cargo_id`, `cargo`, `departamento`, `unidade`, `salario_fixo`, `periculosidade`, `insalubridade`, **`ponto_gorjeta`**, **`ponto_premio`**, `pct_fixo`, `pct_bruto` |
| `dp_rh.cargos_loja_pontos` | `loja_nome`, `salario_min`, `piso_cct`, `piso_tata`, **`valor_pt_gorjeta`**, **`valor_pt_premio`**, `vigente_desde` |
| `dp_rh.cargos_salarios` (view) | já calcula `gorjeta_total`, `premio_total`, `bruto`, `abaixo_piso` |
| `tata_plus.profiles` | `matricula`, `nome`, `cargo`, `cargo_id`, `status`, `unidade`, `departamento`, `data_admissao`, `data_demissao` |
| `tata_plus.colaborador_lotacao` | `matricula`, `unidade`, `departamento`, `desde` (lotação ao longo do tempo) |

**Lojas cadastradas:** Itaim · Pinheiros · Poke - Pinheiros · Tatá House Itaim · Tatá House Pinheiros · Administrativo.
**Gorjeta hoje** só distribui em **Itaim** e **Pinheiros** (`valor_pt_gorjeta = 230`). Poke e Tatá House estão com gorjeta = 0 (só prêmio). *(a confirmar no fechamento)*

**Fonte dos números hoje:** a página `compliance/kpis/rh/gorjeta.html` está com os valores **chumbados no HTML** (valor do ponto mês a mês, gorjeta arrecadada, pedidos iFood). O schema novo vira a fonte real desses números.

---

## 5. Estrutura proposta (RASCUNHO — vai ser lapidada na conversa)

> Ainda **não criado**. Só o desenho inicial pra guiar a conversa.

- **`fechamento.gorjeta_diaria`** — `data` · `loja` · `valor` · `pedidos_ifood` → alimenta o cálculo mensal do valor do ponto.
- **`fechamento.folha_tipos`** — catálogo: `nome`, `sentido` (entrada/saída), ativo.
- **`fechamento.folha_lancamentos`** — `matricula` · `competencia` · `tipo_id` · `valor` · obs.
- **`fechamento.faturamento_diario`** — `data` · `loja` · `valor` (base secundária).
- **`fechamento.fechamento_mensal`** — consolidado por colaborador/competência (fixo + gorjeta + prêmio + extras − descontos − vales = líquido).

---

## 6. Perguntas em aberto (a conversar, sem pressa)

- [ ] **Processo atual de fechamento**, passo a passo: onde estão os números, o que soma, o que desconta, o que sai no final (por pessoa ou resumo por loja?).
- [ ] **Gorjeta diária:** de onde vem o valor (digitado? % do faturamento / taxa de serviço?). Rateio só por **pontos do cargo** ou considera **presença** (dias trabalhados no mês)?
- [ ] **Ciclo/competência:** mês cheio (1–30) ou corte (ex.: 21–20)? Quando roda o fechamento?
- [ ] **Poke / Tatá House:** entram só com **prêmio**, ou ficam fora do fechamento?
- [ ] **Faturamento:** grão (dia/loja) e se separa por canal/forma de pagamento (salão, iFood, etc.).
- [ ] **Entrada do dado:** página manual no portal, importação de planilha, ou n8n?

---

## 7. Log de progresso

- [x] **20/08** — Levantamento do banco: schemas, referências de RH (cargos/pontos/colaboradores), lojas. Nenhuma tabela de gorjeta/folha/fechamento existe ainda.
- [x] **20/08** — Decisões 1–4 travadas com o usuário. Documento vivo criado.
- [ ] Criar schema `fechamento` (vazio).
- [ ] Tabelas, uma a uma, conforme definido.
