# Mapa do schema `dp_rh` — Supabase TATÁ SUSHI | TATÁ POKE

Projeto Supabase: `aoqsbusfrffapjglpqjk`. Levantamento feito em 27/10/2026.
Total: **79 objetos** (78 tabelas + 1 view `cargos_salarios`). Contagens de linhas são do dia do levantamento.

Notação das colunas: `nome:tipo`. Tipos abreviados: `tstz` = timestamp com fuso, `ts` = timestamp sem fuso, `bool`, `num` = numeric, `arr` = array, `jsonb`.
**PK** = chave primária. **UQ** = unique. **FK** = chave estrangeira declarada.

---

## 1. Convenções gerais (leia antes de consultar)

- **`matricula` (text)** é a chave de pessoa em quase todas as tabelas. Aponta para `tata_plus.profiles.matricula` **sem FK declarada**. Sempre texto, nunca número. Pessoas ativas: `tata_plus.profiles.status = 'Ativo'`.
- **Cadastro de colaboradores NÃO fica em `dp_rh`**: fica em `tata_plus.profiles` (nome, cargo, unidade, departamento, status, `lider` bool, `perfil`). Foto: `tata_plus.auth_users.avatar_url` via view `tata_plus.colaboradores_publicos`.
- **Unidades** (texto livre, sem tabela de domínio): `Itaim`, `Pinheiros`, `Poke - Pinheiros`, `Tatá House`, `Administrativo`, `Central`. Em `armarios` aparecem `Itaim Bibi` e `TATÁ House`. Em `cargos` existem `Tatá House Itaim` e `Tatá House Pinheiros`. Ao cruzar tabelas, não assumir que o texto da unidade é idêntico.
- **Tabelas `*_kanban`**: ligam um registro a um card do kanban (`card_id`). Têm PK igual à chave do registro de origem. Maioria tem FK com `ON DELETE CASCADE` para a tabela de origem; `avaliacao_exp_kanban`, `experiencia_kanban`, `aniversario_kanban`, `assistencia_medica_kanban`, `exame_kanban` e `rec_devolutiva_kanban` **não têm FK** (limpeza manual).
- **`criado_por` / `atualizado_por`**: guardam nome ou matrícula do autor. Valor `7` = matrícula do Victor (People & HR Manager). `sandbox` = ações feitas pelo portal sem identidade. Não é confiável para saber "quem agendou/fez".
- **Triggers**: `armarios`/`armarios_hist` não têm trigger. O histórico precisa ser inserido manualmente em cada movimentação.
- **CPF** guardado só com dígitos (11).
- **Dinheiro**: `banco_horas.salario`/`custo` são congelados no insert (a partir de `cargos_salarios`). `bruto` NÃO é gravado em `cargos`; é calculado na view `cargos_salarios`.
- **Acesso a valores**: `perm_ver_valores` define quem vê números monetários (`area='geral'` cobre tudo; tabela vazia = todos bloqueados).
- **Tabelas sensíveis** (não expor sem necessidade): `ouvidoria`, `alinhamento_transcricao`, `reclamacoes`, `sancoes`, `demissoes`, `desligamento_respostas`, `admissoes`/`admissao_respostas`/`admissao_documentos` (CPF e documentos), `cargos`/`cargos_salarios` (salários), `banco_horas` (salário/custo), `avaliacoes`.
- **Regra de trabalho**: qualquer DELETE ou alteração em lote deve ser mostrada antes (prévia) e confirmada. O MCP `execute_sql` pode retornar `{"status":"cancelled"}` em DELETE; nesse caso entregar o SQL para rodar manualmente.
- Rotinas RHiD (ponto): edge functions `rhid-ausencias-sync`, `rhid-banco-horas-sync`, `rhid-feriados-sync`, `sync-rhid`, disparadas por pg_cron. Período padrão = segunda a domingo anteriores. `banco_horas` usa `ON CONFLICT DO NOTHING`; `ausencias` e `feriados_horas` fazem upsert.

---

## 2. Recrutamento e seleção

Fluxo: **vaga** → **candidatura** (1 linha por candidato) → **entrevistas** (N) → **dias de teste** (N) → status final "Contratado" → **admissão**.

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `vagas` | 435 | Controle de vagas. `status_vaga` ∈ Aberta/Fechada (45 abertas). `lider_responsavel` é texto livre (nome). | PK `id` |
| `rec_candidaturas` | 5.343 | 1 candidatura = entrevista + teste unificados. Contém contato, CPF, responsável (recrutador), status de entrevista/teste/final com autor e data. | PK `id` |
| `rec_entrevistas` | 5.050 | Cada agendamento de entrevista (inclui remarcações). | PK `id`; FK `candidatura_id`→`rec_candidaturas` (cascade) |
| `rec_teste_dias` | 2.239 | Dias de teste do candidato (`candidatura_id` repete por dia): unidade, cargo, valor da diária, pago. | PK `id`; FK `candidatura_id` (cascade) |
| `rec_agenda_lideres` | 19 | Agenda de entrevista por líder, unidade e departamento (dias, horário, duração). | PK `id` |
| `rec_devolutiva_kanban` | 219 | Card do kanban de devolutivas por candidatura e tipo. | PK `candidatura_id, tipo` |

Colunas:
- `vagas`: id:uuid, data_solicitacao:date, unidade, departamento, cargo, escala, horario, salario_fixo:num, salario_bruto:num, colaborador_anterior, colaborador_contratado, data_contratacao:date, status_vaga, lider_responsavel, observacao, beneficios, criado_por, created_at:tstz, updated_at:tstz
- `rec_candidaturas`: id:uuid, criado_por, created_at, updated_at, nome, contato, cpf, responsavel, pretensao_salarial, unidade, departamento, cargo, selecionado, data_entrevista:date, horarios, status_entrevista, entrevistador, observacoes_entrevista, processos, resumo, empresa_anterior_lider, contato_referencia, check_referencia, feedback_referencia, tipo_referencia, observacoes_referencia, camiseta, status_teste, status_final, status_final_por, status_final_em:tstz, status_entrevista_por, status_entrevista_em:tstz, status_teste_por, status_teste_em:tstz, horario_vaga, beneficios, observacoes_vaga, vaga_id:uuid, data_proximo_teste:date
- `rec_entrevistas`: id:uuid, candidatura_id:uuid, data:date, hora:text, entrevistador, status, selecionado, observacoes, criado_por, created_at, updated_at
- `rec_teste_dias`: id:uuid, candidatura_id:uuid, data_teste:date, unidade, cargo, responsavel, horario, valor_diaria:num, status, devolutiva_por, devolutiva_em:tstz, pago:bool, pago_em:tstz, observacoes, criado_por, created_at, horario_saida, recibo_status
- `rec_agenda_lideres`: id:uuid, ordem:int, unidade, departamento, lider, dias, horario, duracao, ativo:bool, created_at, updated_at
- `rec_devolutiva_kanban`: candidatura_id:uuid, tipo, card_id:uuid, created_at

Observações:
- Quem é o recrutador: `rec_candidaturas.responsavel` (nome). `rec_entrevistas.criado_por` só tem `7` ou `sandbox` nos registros recentes.
- Status de entrevista vistos: Aguardando Entrevista, Aguardando devolutiva, Remarcada, Não entrou, Aprovado para teste, Não selecionado, Cancelada.
- `vagas` não tem FK para candidaturas; o vínculo é `rec_candidaturas.vaga_id` (sem FK declarada).
- Dropdown "Líder responsável" do formulário de Vagas vem da função `tata_plus.colaboradores_para_vaga()` (profiles ativos). Funções do portal: `tata_plus.vagas_listar()`, `tata_plus.vagas_salvar()`, `tata_plus.cargos_para_vaga()`, e as versões `public.*_sandbox_*`.

---

## 3. Admissão e documentos

Fluxo: candidatura com `status_final = 'Contratado'` gera uma **admissão** (link pessoal por `token`). O candidato responde a ficha pelo chat da Sara (EAV) e envia documentos; o RH valida. Depois da matrícula criada, os documentos migram para `colaborador_documentos`.

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `admissoes` | 29 | Cabeçalho da admissão: nome, CPF, cargo, unidade, status, tentativas de CPF, datas do fluxo. | PK `token`; UQ `candidatura_id`; FK `candidatura_id`→`rec_candidaturas` (set null) |
| `admissao_respostas` | 1.360 | Ficha em linhas (EAV): 1 linha por informação. Validada item a item pelo RH. | PK `id`; FK `admissao_token` (cascade) |
| `admissao_documentos` | 187 | Documentos enviados na admissão (bucket `dp-documentos`, prefixo `_admissao/<token>/`). | PK `id`; FK `admissao_token` (cascade); FK `tipo_id`→`doc_tipos` |
| `admissao_config` | 1 | Config do fluxo (`disparo_ativo`, `webhook_url`, `base_url`, `expira_horas`). | PK `id` |
| `colaborador_documentos` | 1.254 | "Pastinha" do colaborador: documentos efetivamente anexados. Um por tipo (ou tipo+competência se mensal). | PK `id`; FK `tipo_id`→`doc_tipos` |
| `colaborador_doc_excecoes` | 2 | Exceção por pessoa: um tipo de documento aplica ou não. | PK `id`; UQ `matricula, tipo_id`; FK `tipo_id` |
| `doc_tipos` | 42 | Catálogo de tipos de documento/termo (obrigatório, periodicidade, exige assinatura, exige admissão). | PK `id` |
| `doc_tipos_cargo_excecoes` | 0 | Exceção por cargo para um tipo de documento. | PK `id`; UQ `tipo_id, cargo`; FK `tipo_id` |
| `doc_eventos_regras` | 9 | Regras que geram documento a partir de eventos (origem/valor → nome do documento, tolerância em dias). | PK `id`; UQ `origem, valor` |
| `doc_eventos_cortes` | 1 | Data de corte por pessoa/origem/documento (evita cobrar documento retroativo). | PK `id`; UQ `matricula, origem, nome_documento, data_corte` |

Colunas:
- `admissoes`: token:uuid, candidatura_id:uuid, nome, cpf, contato, cargo, unidade, departamento, status, tentativas_cpf:int, protocolo, dados:jsonb, documentos:jsonb, criado_em, liberado_em, expira_em, disparo_em, acessado_em, enviado_em, concluido_em, criado_por, updated_at
- `admissao_respostas`: id:uuid, admissao_token:uuid, grupo, campo, rotulo, valor, ordem:smallint, sentido, validado:bool, validado_por, validado_em, validacao_obs, created_at, updated_at
- `admissao_documentos`: id:uuid, admissao_token:uuid, tipo_id:uuid, link, link_bucket, nome_arquivo, mime, tamanho:bigint, status, versao:int, validade:date, observacao, enviado_por, enviado_em, migrado_em, colaborador_documento_id:uuid, created_at, updated_at
- `admissao_config`: id:bool, disparo_ativo:bool, webhook_url, base_url, expira_horas:int
- `colaborador_documentos`: id:uuid, matricula, tipo_id:uuid, competencia, nome_arquivo, link, mime, tamanho:bigint, status, validade:date, observacao, enviado_por, enviado_em, created_at, updated_at, evento_origem, evento_id:uuid, link_bucket, assinatura_atribuicao_id:uuid, versao:int
- `colaborador_doc_excecoes`: id:uuid, matricula, tipo_id:uuid, aplica:bool, criado_por, created_at
- `doc_tipos`: id:uuid, categoria, nome, obrigatorio:bool, periodicidade, origem, ativo:bool, ordem:int, criado_por, created_at, updated_at, categoria_ordem:int, aplica_somente_inativo:bool, intervalo_meses:int, requer_assinatura:bool, exige_admissao:bool
- `doc_tipos_cargo_excecoes`: id:uuid, tipo_id:uuid, cargo, aplica:bool, criado_por, created_at
- `doc_eventos_regras`: id:uuid, origem, valor, nome_documento, tolerancia_dias:int
- `doc_eventos_cortes`: id:uuid, matricula, origem, nome_documento, data_corte:date, criado_por, created_at

Storage (fora do schema): buckets `dp-documentos` (privado), `admissao-docs`, `avatares` (público).

---

## 4. Cargos, salários e benefícios

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `cargos` | 241 | Cargos & Salários (definição + valores): salário fixo por cargo, nível (`niveis` JR/PL/SR/SR 2/SR 3), unidade, departamento, CBO, pontos de gorjeta/prêmio, descrição, EPIs, uniforme. | PK `cargo_id` |
| `cargos_loja_pontos` | 16 | Valor do ponto (gorjeta/prêmio) e pisos (CCT, TATÁ, mínimo) por loja, com histórico (`vigente_desde`). | PK `id` |
| `cargos_salarios` (**view**) | 241 | `cargos` + pontos vigentes da loja, com `bruto`, `gorjeta_total`, `premio_total` e alerta `abaixo_piso`. | — |
| `beneficios_premiacoes` | 11 | Premiações por tempo de casa (marcos em meses: 6, 12, 24...). | PK `id`; UQ `marco_meses` |
| `beneficios_premiacao_itens` | 11 | Itens de cada premiação; custo da faixa = soma dos itens. | PK `id`; FK `marco_meses` (cascade) |
| `hc_programado` | 31 | Headcount programado por unidade e departamento (líder, especialista, auxiliares, aprendizes, estagiários) e escalas. | PK `id`; UQ `id_externo` |
| `perm_ver_valores` | 11 | Quem pode ver valores monetários, por área. | PK `matricula, area` |

Colunas:
- `cargos`: cargo_id:text, cargo, departamento, unidade, cbo, niveis, hierarquia, salario_fixo:num, periculosidade:num, insalubridade:num, ponto_gorjeta:num, ponto_premio:num, pct_fixo:num, pct_bruto:num, obs, objetivos, responsabilidades, formacao, experiencia, comp_tecnicas, comp_comportamentais, uniforme, epis, ultima_atualizacao, criado_por, created_at, updated_at, lider_imediato, salario_fixo_pre_dissidio:num
- `cargos_salarios` (view): mesmas colunas de `cargos` (exceto lider_imediato e salario_fixo_pre_dissidio) + valor_pt_gorjeta, valor_pt_premio, piso_cct, piso_tata, salario_min, gorjeta_total, premio_total, bruto, abaixo_piso:bool
- `cargos_loja_pontos`: id:uuid, loja_nome, salario_min:num, piso_cct:num, piso_tata:num, valor_pt_gorjeta:num, valor_pt_premio:num, vigente_desde:date, criado_por, created_at
- `beneficios_premiacoes`: id:uuid, marco_meses:int, marco_label, ativo:bool, ordem:int, created_at, updated_at, updated_por
- `beneficios_premiacao_itens`: id:uuid, marco_meses:int, item, valor:num, ativo:bool, ordem:int, created_at, updated_at, updated_por
- `hc_programado`: id:uuid, id_externo, unidade, departamento, escala, lider:int, especialista:int, auxiliares:int, aprendizes:int, estagiarios:int, total:int, criado_por, created_at, updated_at, escala_lider, escala_especialista, escala_auxiliares, escala_aprendizes, escala_estagiarios, cargos:jsonb
- `perm_ver_valores`: matricula, area, liberado:bool, criado_por, created_at

Atenção: o banco **não guarda salário individual**. O salário de uma pessoa se obtém pelo cargo+nível+unidade dela em `cargos_salarios`.

---

## 5. Ponto, banco de horas, ausências, feriados, férias e exames

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `banco_horas` | 16.941 | Saldo diário de banco de horas por pessoa (sincronizado do RHiD). `salario` e `custo` congelados no insert. | PK `data, matricula, tipo` |
| `ausencias` | 5.242 | Faltas/ausências (tipo, status, devolutiva do líder). Origem RHiD ou manual. | PK `id`; UQ `matricula, data_falta` |
| `ausencia_kanban` | 532 | Card do kanban por ausência. | PK `ausencia_id`; FK (cascade) |
| `feriados_horas` | 415 | Horas trabalhadas em feriado e decisão (folga/pagamento). | PK `id`; UQ `matricula, data_feriado` |
| `feriado_kanban` | 70 | Card do kanban por feriado. | PK `feriado_id`; FK (cascade) |
| `ferias` | 214 | Controle de férias: período aquisitivo, concessivo, fracionamento (até 3 períodos), abono, aprovação. | PK `matricula, ini_aqui` |
| `exames` | 217 | Exames ocupacionais por pessoa (tipo, periodicidade, último, próximo, agendamento). | PK `matricula` |
| `exame_kanban` | 36 | Card do kanban por exame. | PK `matricula, proxima_realizacao` |
| `assistencia_medica_kanban` | 21 | Card de assistência médica por evento. | PK `matricula, evento_em` |
| `vt_semanal` | 55 | Vale-transporte semanal por pessoa (ano/mês/semana, valor). | PK `id`; UQ `matricula, ano, mes, semana` |

Colunas:
- `banco_horas`: data:date, matricula, tipo, saldo:num, salario:num, custo:num, origem, created_at
- `ausencias`: id:uuid, matricula, colaborador, unidade, departamento, data_falta:date, tipo, status, devolutiva, devolutiva_por, devolutiva_em, origem, created_at, updated_at
- `feriados_horas`: id:uuid, matricula, colaborador, unidade, departamento, data_feriado:date, feriado_nome, horas:text, saldo_anterior:text, decisao, decisao_por, data_folga:date, decisao_em, origem, created_at, updated_at
- `ferias`: matricula, ini_aqui, fim_aqui, ini_conc, fim_conc, direito:text, frac:text, ini1, ini2, ini3, fim1, fim2, fim3, abono:text, aprovado:text, obs, nome_hist, atualizado_por, atualizado_em
- `exames`: matricula, realiza_exame:bool, tipo_exame, periodicidade:int, ultimo_exame:date, proxima_realizacao:date, atualizado_por, created_at, updated_at, data_agendada:date, agendado_por, agendado_em
- `vt_semanal`: id:uuid, matricula, nome, unidade, departamento, ano:int, mes:int, semana:int, valor:num, criado_em, atualizado_em, admissao:date
- kanbans: ver chaves na tabela acima + card_id:uuid + created_at/criado_em

Atenção: `ausencias.tipo = 'Falta'` com `status = 'Ativo'` e `devolutiva` vazia = falta pendente de devolutiva do líder.

---

## 6. Escalas

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `escala_plano` | 80 | Plano de escala da pessoa: ciclo em semanas, âncora, vigência (`efetivo_desde`). | PK `id`; UQ `matricula, efetivo_desde` |
| `escala_plano_dia` | 574 | Dias do ciclo do plano (semana do ciclo + dia da semana: entrada, saída, folga, marcações). | PK `plano_id, semana_ciclo, dia_semana`; FK `plano_id` (cascade) |
| `escala_dias` | 5.880 | Escala real dia a dia por pessoa (entrada, saída, folga, tipo de folga, `origem` = `padrao` projetado do plano ou `manual`). | PK `matricula, data` |
| `escala_horarios` | 38 | Catálogo de horários (entrada/saída) disponíveis para escolher. | PK `id` |
| `escala_pessoa` | 60 | Define se a pessoa tem a escala controlada no sistema (`controla`). | PK `matricula` |
| `escala_pontos_log` | 439 | Log de pontos (gamificação) por chave. | PK `chave` |

Colunas:
- `escala_dias`: matricula, data:date, unidade, entrada:time, saida:time, folga:bool, origem, plano_id:bigint, atualizado_em, marcacoes:jsonb, folga_tipo
- `escala_plano`: id:bigint, matricula, unidade, efetivo_desde:date, semanas_ciclo:smallint, ancora:date, criado_por, criado_em
- `escala_plano_dia`: plano_id:bigint, semana_ciclo:smallint, dia_semana:smallint, entrada:time, saida:time, folga:bool, marcacoes:jsonb
- `escala_horarios`: id:bigint, entrada:time, saida:time, ativo:bool, ordem:smallint, criado_por, criado_em, marcacoes:jsonb, chave
- `escala_pessoa`: matricula, controla:bool, atualizado_em
- `escala_pontos_log`: chave, matricula, pontos:int, criado_em

Atenção: líderes (ex.: encarregados) podem estar lançados em `escala_dias` sem horário e sem folga.

---

## 7. Avaliações, clima e liderança

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `avaliacao_modelos` | 8 | Catálogo data-driven dos instrumentos (`form` jsonb com blocos/perguntas, escala, periodicidade, papéis). `slug` identifica (ex.: `lideranca`). | PK `id`; UQ `slug` |
| `avaliacao_ciclos` | 0 | Ciclos de avaliação por modelo (abre/fecha). | PK `id`; UQ `modelo_id, rotulo`; FK `modelo_id` |
| `avaliacoes` | 418 | Uma avaliação de um alvo (`alvo_matricula`) por período: estado, média, faixa, resultado, decisão, devolutiva, ciência. **Tabela atual de avaliação de experiência.** | PK `id`; FK `modelo_id`, `ciclo_id` |
| `avaliacao_respostas` | 404 | Respostas por papel/avaliador (`respostas` jsonb, soma, média). | PK `id`; UQ `avaliacao_id, papel, avaliador_matricula`; FK (cascade) |
| `avaliacao_eventos` | 156 | Trilha de eventos da avaliação. | PK `id`; FK (cascade) |
| `avaliacao_kanban` | 0 | Card do kanban da avaliação. | PK `avaliacao_id`; FK (cascade) |
| `avaliacao_exp_kanban` | 5 | Card do kanban das avaliações de experiência. **Sem FK**: limpar manualmente. | PK `avaliacao_id` |
| `experiencia_avaliacoes_hist` | 413 | **Legado**: histórico de avaliações de experiência (migrado de planilha). | PK `id`; UQ `periodo, matricula, form_ts` |
| `experiencia_kanban` | 0 | **Legado**: card do kanban de experiência. | PK `avaliacao_id` |
| `clima_tokens` | 216 | Links únicos da pesquisa de clima (por pessoa, disparo e ciclo). | PK `token` |
| `clima_respostas` | 63 | Respostas de clima (jsonb + texto livre), por unidade/departamento/dia. | PK `id` |
| `reconhecimentos` | 86 | Reconhecimento entre pares (sem nota). `motivo` ∈ equipe, proatividade, atendimento, qualidade, apoio, cultura, outro. | PK `id` |
| `score_lideres` | 52 | Score mensal por unidade/departamento (headcount, desligados, faltas, atestados, sanções, reclamações, banco de horas negativo). | PK `id`; UQ `competencia, unidade, departamento` |
| `brainstorm_palavras` | 34 | Palavras de dinâmicas de brainstorm por sessão. | PK `id` |

Colunas:
- `avaliacao_modelos`: id:uuid, slug, nome, frente:smallint, fluxo, escala, onde, periodicidade, gatilho:jsonb, papeis:arr, gera_media:bool, gera_card:bool, form:jsonb, form_versao:smallint, ativo:bool, ordem:smallint, created_at, updated_at
- `avaliacao_ciclos`: id:uuid, modelo_id:uuid, rotulo, abre_em:date, fecha_em:date, status, created_at
- `avaliacoes`: id:uuid, modelo_id:uuid, ciclo_id:uuid, alvo_matricula, periodo:smallint, snapshot:jsonb, estado, data_referencia:date, media:num, faixa, resultado:jsonb, decisao:jsonb, devolutiva, devolutiva_por, devolutiva_em, ciente_em, ciencia_ref, criado_por, created_at, updated_at
- `avaliacao_respostas`: id:uuid, avaliacao_id:uuid, papel, avaliador_matricula, anonimo:bool, respostas:jsonb, soma:num, media:num, estado, enviada_em, created_at, updated_at
- `avaliacao_eventos`: id:uuid, avaliacao_id:uuid, tipo, ator_matricula, dados:jsonb, created_at
- `avaliacao_kanban` / `avaliacao_exp_kanban`: avaliacao_id:uuid, card_id:uuid, created_at
- `experiencia_avaliacoes_hist`: id:uuid, matricula, nome, unidade, departamento, periodo:int, data_avaliacao:date, efetivar:bool, respostas:jsonb, obs, avaliador_nome, avaliador_matricula, soma:num, origem, form_ts, criado_por, created_at
- `clima_tokens`: token:uuid, matricula, unidade, disparo, perguntas:arr, criado_em, expira_em, usado_em, cancelado_em, ciclo:int
- `clima_respostas`: id:uuid, disparo, unidade, respostas:jsonb, texto, dia:date, matricula, departamento
- `reconhecimentos`: id:uuid, de_matricula, para_matricula, motivo, mensagem, created_at
- `score_lideres`: id:uuid, competencia:date, unidade, departamento, headcount:int, desligados:int, faltas:int, atestados:int, sancoes:int, dispensados1:int, colab_acima100:int, score:num, created_at, colab_bh_neg:int, recl_abertas:int, recl_procedentes:int, classificacao
- `brainstorm_palavras`: id:bigint, sessao, palavra, autor, descricao, categoria, criado_em

Ao apagar uma avaliação em `avaliacoes`, respostas, eventos e `avaliacao_kanban` caem em cascata; `avaliacao_exp_kanban` não.

---

## 8. Desligamento e jurídico

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `demissoes` | 488 | Desligamentos: data, tipo, rescisão, homologação, valores, pagamento, saldo devedor. | PK `id`; UQ `matricula, data_demissao, tipo` |
| `desligamento_tokens` | 0 | Link único da entrevista de desligamento (não guarda respostas). | PK `token` |
| `desligamento_respostas` | 93 | Respostas da entrevista de desligamento; histórico migrado entra com `fonte='historico'` e sem matrícula. | PK `id` |
| `homologacao_janelas` | 0 | Janelas de horário para agendar homologação (por unidade e dia da semana ou data específica). | PK `id` |
| `homologacao_tokens` | 2 | Link único para o colaborador agendar a homologação. | PK `token`; FK `demissao_id`→`demissoes` (cascade) |
| `sancoes` | 478 | Advertências/suspensões (tipo, dias de suspensão, líder). | PK `id`; UQ `id_externo` |
| `sancao_kanban` | 46 | Card do kanban por sanção. | PK `sancao_id`; FK (cascade) |
| `reclamacoes` | 29 | Reclamações trabalhistas (datas, reclamante, resultado, valores). | PK `id` |

Colunas:
- `demissoes`: id:uuid, matricula, nome, unidade, departamento, cargo, data_demissao:date, tipo, status_homologacao, data_homologacao:date, valor_rescisao:num, valor_grrf:num, data_pagamento:date, obs, origem, created_at, updated_at, rescisao_tipo, saldo_devedor:num, homologacao_agendada_em:tstz, homologacao_tentativas:int, status_pagamento
- `desligamento_tokens`: token:uuid, matricula, nome, unidade, criado_em, criado_por, expira_em, usado_em, cancelado_em, tipo, enviado_em
- `desligamento_respostas`: id:uuid, token:uuid, matricula, nome, unidade, tipo, respostas:jsonb, media:num, faixa, fonte, respondido_em, criado_em
- `homologacao_janelas`: id:uuid, unidade, dia_semana:int, hora_inicio:time, hora_fim:time, duracao_min:int, ativo:bool, created_at, data_especifica:date
- `homologacao_tokens`: token:uuid, demissao_id:uuid, matricula, nome, unidade, criado_por, expira_em, usado_em, cancelado_em, agendado_em, criado_em
- `sancoes`: id:uuid, id_externo, data_ocorrencia:date, matricula, nome_colaborador, cargo_colaborador, unidade, departamento, tipo_sancao, dias_suspensao:int, descricao, lider, cargo_lider, criado_por, created_at, updated_at
- `reclamacoes`: id:uuid, data_notificacao:date, data_audiencia:date, reclamante, solicitacoes, resultado, resolucao, valor_causa:num, valor_quitacao:num, unidade, departamento, obs, criado_por, criado_em, atualizado_por, atualizado_em

---

## 9. Canais internos (ouvidoria, solicitações, agenda, reuniões de DP/RH)

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `ouvidoria` | 26 | Ouvidoria (privado; acesso via RPC em `tata_plus`). Pode ser identificada ou anônima. | PK `id`; UQ `id_externo` |
| `ouvidoria_kanban` | 7 | Card do kanban por ouvidoria. | PK `ouvidoria_id`; FK (cascade) |
| `solicitacoes` | 656 | Solicitações das unidades ao RH (tipo, urgência, status, devolutiva). | PK `id` |
| `solicitacoes_kanban` | 170 | Card do kanban por solicitação. | PK `solicitacao_id`; FK (cascade) |
| `agenda_eventos` | 53 | Agenda de eventos do RH (data, hora, local, categoria; `mostrar_no_app`). | PK `id` |
| `agenda_evento_kanban` | 3 | Card do kanban por evento. | PK `evento_id`; FK (cascade) |
| `aniversario_kanban` | 44 | Card de aniversário/tempo de casa por pessoa e data. | PK `matricula, tipo, evento_em` |
| `alinhamento_transcricao` | 32 | Transcrições/atas das **reuniões de DP/RH** (sensível; acesso via RPC em `tata_plus`). | PK `id`; UQ `id_externo` |

Colunas:
- `ouvidoria`: id:uuid, id_externo, created_at, identificado:bool, nome, matricula, data_ocorrido:date, descricao, quer_devolutiva:bool, forma_devolutiva, contato, devolutiva, status, updated_at
- `solicitacoes`: id:uuid, id_card, abertura:tstz, email, unidade, solicitante, departamento, tipo, descricao, urgente, status, devolutiva, data_conclusao:date, criado_por, criado_em, atualizado_por, atualizado_em
- `agenda_eventos`: id:uuid, titulo, data:date, hora_inicio, hora_fim, local, categoria, responsavel, descricao, criado_por, created_at, updated_at, mostrar_no_app:bool
- `alinhamento_transcricao`: id:uuid, id_externo, data_reuniao:date, conteudo, created_at
- `aniversario_kanban`: matricula, tipo, evento_em:date, card_id:uuid, criado_em

---

## 10. Operação de unidade (armários, limpeza, estoque)

| Tabela | Linhas | Para que serve | Chaves |
|---|---|---|---|
| `armarios` | 174 | Estado atual de cada armário: `status` ∈ livre/ocupado/manut, colaborador, matrícula, termo assinado. | PK `id`; UQ `unidade, num` |
| `armarios_hist` | 132 | Log de movimentações (`tipo` ∈ Atribuição/Devolução/Troca/Manutenção). Inserir manualmente a cada mudança. | PK `id` |
| `estoque_admin` | 2.330 | Movimentos do estoque administrativo (uniformes/EPI): entrada/saída, item, tamanho, CA, custo. | PK `id`; UQ `id_externo` |
| `banheiros` | 14 | Banheiros cadastrados por unidade, com token (QR) para o check de limpeza. | PK `id`; UQ `token` |
| `limpeza_checks` | 349 | Checks de limpeza feitos pelos colaboradores (fotos, itens, pontos). | PK `id`; FK `banheiro_id`→`banheiros` (restrict) |
| `limpeza_itens` | 7 | Itens do checklist de limpeza. | PK `id`; UQ `chave` |
| `limpeza_config` | 1 | Configuração do sorteio/pontuação da limpeza. | PK `id` |

Colunas:
- `armarios`: id:bigint, unidade, num, status, colaborador, matricula, obs, termo_assinado:bool, atualizado_por, created_at, updated_at
- `armarios_hist`: id:bigint, data_mov:date, unidade, num, tipo, colaborador, matricula, responsavel, obs, criado_por, created_at
- `estoque_admin`: id:uuid, id_externo, data:date, unidade, colaborador, matricula, tipo, categoria, item, tamanho, quantidade:num, custo_unit:num, cargo, ca, obs, origem_ts, responsavel, created_at, custo_total:num, criado_por
- `banheiros`: id:uuid, nome, unidade, token, ativo:bool, ordem:int, criado_em
- `limpeza_checks`: id:uuid, banheiro_id:uuid, banheiro_nome, unidade, matricula, criado_em, foto_tipo, foto_url, observacao, foto_obs_url, itens:jsonb, pontos:int
- `limpeza_itens`: id:uuid, chave, label, ordem:int, ativo:bool
- `limpeza_config`: id:int, contador:int, alvo:int, proximo_tipo, min_intervalo:int, max_intervalo:int, pontos_check:int, pontos_foto:int, pontos_janela_horas:int

Padrão de devolução de armário: `armarios` → `status='livre'`, `colaborador=''`, `matricula=''`, `obs=''`, `termo_assinado=false`, `atualizado_por='7'`, `updated_at=now()`; `armarios_hist` → `tipo='Devolução'`, `colaborador='—'`, `matricula=''`, `responsavel='Victor Augusto Di Sessa Carvalho'`, `criado_por='7'`, `data_mov` = hoje (America/Sao_Paulo).

---

## 11. Agente de WhatsApp (Sam) — no ar desde 28/10

Guia completo: `docs/AGENTE-WHATSAPP.md`. O Sam responde em grupos liberados, consultando só as **visões** dos schemas
`agente` (nível básico) e `agente_restrito` (nível completo), com o papel só-leitura `agente_leitor` / `agente_leitor_total`.
Toda tabela nova que o Sam deva enxergar precisa de uma visão nesses schemas (com comentário — vira explicação para a IA).

| Tabela | Para que serve | Chaves |
|---|---|---|
| `agente_grupos` | Grupos de WhatsApp onde o Sam responde: `ativo` (liberado) e `nivel` (`basico` / `completo`). Grupo novo nasce pendente e básico. | PK `chat_id` |
| `agente_mensagens` | Histórico/auditoria: pergunta (com autor em `meta`), resposta, SQL rodado, modelo, tokens. `telefone` = id da conversa (grupo). | PK `id`; UQ `msg_id` |
| `agente_webhook_log` | Eventos ignorados para diagnóstico (grupo pendente, falha), guarda 7 dias. | PK `id` |
| `agente_config` | Senhas do webhook/teste, token da instância `sam`, `prompt_estilo` (jeito de responder) e `bot_ids`. | PK `chave` |
| `agente_usuarios` | Sem uso (era do modo privado). | PK `telefone` |

O que o Sam vê (28/10): **básico = 38 visões** (colaboradores, recrutamento, escalas, ausências, férias, banco de horas
sem valores, feriados, exames, HC, cargos sem salário, admissões e documentos sem arquivo, demissões sem valores, sanções,
solicitações, armários + histórico, estoque sem custo, limpeza sem fotos, agenda, score de líderes, reconhecimentos,
treinamentos, manutenção, líderes responsáveis); **completo = +14 restritas** (atas das reuniões de DP/RH, avaliações,
salários por cargo, pontos da loja, banco de horas com custo, diárias/pretensão, salário de vagas, valores de rescisão,
VT, custo de estoque e manutenção, premiações com valor, reclamações trabalhistas).
Fora em qualquer nível: `ouvidoria`, `clima_respostas`, `desligamento_respostas`, CPF/telefone/e-mail, ficha da admissão.

---

## 12. Relações principais (resumo)

```
rec_candidaturas ─┬─< rec_entrevistas        (candidatura_id, cascade)
                  ├─< rec_teste_dias         (candidatura_id, cascade)
                  ├─1 admissoes              (candidatura_id, unique)
                  └── vaga_id → vagas        (sem FK)
admissoes ─┬─< admissao_respostas  (token, cascade)
           └─< admissao_documentos (token, cascade) ─> doc_tipos
doc_tipos ─┬─< colaborador_documentos
           ├─< colaborador_doc_excecoes
           └─< doc_tipos_cargo_excecoes
avaliacao_modelos ─< avaliacao_ciclos ─< avaliacoes ─┬─< avaliacao_respostas
                                                     ├─< avaliacao_eventos
                                                     └─1 avaliacao_kanban
demissoes ─< homologacao_tokens
escala_plano ─< escala_plano_dia ;  escala_plano ··> escala_dias (plano_id, sem FK)
banheiros ─< limpeza_checks
beneficios_premiacoes ─< beneficios_premiacao_itens (marco_meses)
cargos ─(view)→ cargos_salarios ←─ cargos_loja_pontos (por loja)
*_kanban: 1 linha por registro de origem, com card_id do kanban
matricula (text) em ~40 tabelas ··> tata_plus.profiles.matricula (sem FK)
```

---

## 13. Objetos relacionados fora de `dp_rh`

- `tata_plus.profiles`: cadastro de colaboradores (fonte de verdade de nome, cargo, unidade, status, perfil, flag `lider`).
- `tata_plus.pendencia_responsavel`: líder responsável por unidade/departamento para pendências (`matricula_lider`).
- `tata_plus.colaborador_lotacao`, `tata_plus.eventos`, `tata_plus.destaque_semana_vencedor`, `tata_plus.radio_semana_vencedora`.
- Funções (RPC) do portal: `tata_plus.vagas_listar/vagas_salvar/cargos_para_vaga/colaboradores_para_vaga`, `tata_plus.av_lideranca_*`, `tata_plus.score_lideres_calcular/listar`, `tata_plus.organograma_lideres`, `public.pendencias_lideres`, `public.*_sandbox_*`.
- Outros schemas do projeto: `tata_refeicoes`, `tata_abastecimento`, `tata_kanban`, `operacao`, `manutencao`.
