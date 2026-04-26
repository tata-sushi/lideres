# readmedrawer — Configuração do Drawer (menu lateral) nas páginas de Compliance

Guia operacional para aplicar e manter o **drawer padrão** em páginas de compliance do Portal Líderes. Seguir EXATAMENTE na ordem.

## 1. O que é o drawer

O drawer é o menu lateral direito que aparece ao clicar no botão `+` (header-plus) no canto superior direito das páginas de compliance. Ele exibe informações do portal: versão, descrição, KPIs e responsável.

## 2. Páginas que possuem drawer (atualizar esta lista ao adicionar/remover)

| Arquivo | Seção extra |
|---------|-------------|
| `compliance/index.html` | — |
| `compliance/menucompliance.html` | — |
| `compliance/areas/index.html` | — |
| `compliance/areas/institucional/index.html` | — |
| `compliance/areas/institucional/cartao.html` | — |
| `compliance/areas/institucional/idconceitual.html` | — |
| `compliance/areas/institucional/idvisual.html` | — |
| `compliance/areas/institucional/papelaria.html` | Sam |
| `compliance/areas/rh/index.html` | — |
| `compliance/areas/rh/ouvidoria.html` | — |
| `compliance/areas/rh/papeis.html` | — |
| `compliance/areas/rh/sancoes.html` | Ferramentas |
| `compliance/ferramentas/index.html` | Sugerir ferramenta |
| `compliance/kpis/index.html` | — |
| `compliance/kpis/caixa/index.html` | — |
| `compliance/kpis/manutencao/index.html` | Nova Solicitação |
| `compliance/kpis/rh/index.html` | — |
| `compliance/kpis/rh/armarios.html` | Registrar Movimentação |
| `compliance/kpis/rh/bancodehoras.html` | Nova Entrada |
| `compliance/kpis/rh/beneficios.html` | — |
| `compliance/kpis/rh/desligamentos.html` | Nova Rescisão |
| `compliance/kpis/rh/estoqueadm.html` | Nova Solicitação |
| `compliance/kpis/rh/experiencias.html` | — |
| `compliance/kpis/rh/gorjeta.html` | — |
| `compliance/kpis/rh/ouvidoria.html` | — |
| `compliance/kpis/rh/recrutamento.html` | — |
| `compliance/kpis/rh/solicitacoes.html` | Nova Solicitação |

**Todas as 27 páginas de compliance possuem drawer.**

## 3. Estrutura do drawer

O drawer tem 5 partes obrigatórias:

1. **Overlay** — fundo escuro que fecha o drawer ao clicar
2. **Header** — título "Sobre" + botão fechar (X)
3. **Body** — conteúdo rolável com seções:
   - **Versão Atual** — nome do portal + badge de versão
   - **O que é** — descrição do Governança de Processos
   - **Números** — grid 2 colunas com KPIs (Seções, Departamentos, Parceiros, Dashboards, Páginas)
4. **Footer** — fixo no fundo, com responsável (Victor Carvalho · Gestão & Inovação)
5. **JavaScript** — funções `openDrawer()` / `closeDrawer()`

> ⚠️ **REGRA CRÍTICA — o drawer é sobre a Governança, não sobre a página**
>
> O conteúdo do drawer é SEMPRE institucional do portal **Governança de Processos**:
> - Versão: `"Governança de Processos" v2.0c`
> - "O que é": descrição da Governança de Processos (texto padrão do §5)
> - **NUNCA** colocar descrição, base legal, links ou CTAs da página específica no drawer
> - Seções extras permitidas: apenas "Ferramentas" com ações do sistema (ver `sancoes.html`)

## 4. KPI "Páginas" (`id="kpi-pages"`)

O último KPI na grid de "Números" conta o total de `.html` dentro de `compliance/`.

- O elemento DEVE ter `id="kpi-pages"` para ser encontrado pela GitHub Action
- O valor é atualizado automaticamente (ver §8)
- Ao adicionar manualmente, contar os `.html` em `compliance/` para definir o valor inicial correto

## 5. Template do drawer (colar antes do `</body>`)

Copiar este bloco completo. Ajustar apenas a versão se necessário:

```html
<!-- DRAWER -->
<div class="drawer-overlay" id="drawer-overlay" onclick="closeDrawer()"></div>
<div class="drawer" id="drawer">
  <div class="drawer-header">
    <span class="drawer-title">Sobre</span>
    <button class="drawer-close" onclick="closeDrawer()">
      <svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
    </button>
  </div>
  <div class="drawer-body">

    <div class="drawer-section">
      <div class="drawer-section-label">Versão atual</div>
      <div class="drawer-version">
        <div>
          <div class="drawer-version-label">Portal</div>
          <div style="font-size:13px;font-weight:600;color:var(--white);margin-top:2px;">Governança de Processos</div>
        </div>
        <div class="drawer-version-val">v2.0c</div>
      </div>
    </div>

    <div class="drawer-section">
      <div class="drawer-section-label">O que é</div>
      <p class="drawer-about"><strong>Governança de Processos</strong> é a maneira pela qual consolidamos as iniciativas da gestão de processos do TATÁ Sushi, com papéis, diretrizes e mecanismos que orientam como os processos devem ser definidos, executados, monitorados e aprimorados continuamente.</p>
    </div>

    <div class="drawer-section">
      <div class="drawer-section-label">Números</div>
      <div class="drawer-kpi-grid">
        <div class="drawer-kpi"><div class="drawer-kpi-label">Seções</div><div class="drawer-kpi-value">7</div></div>
        <div class="drawer-kpi"><div class="drawer-kpi-label">Departamentos</div><div class="drawer-kpi-value">14</div></div>
        <div class="drawer-kpi"><div class="drawer-kpi-label">Parceiros</div><div class="drawer-kpi-value">3</div></div>
        <div class="drawer-kpi"><div class="drawer-kpi-label">Dashboards</div><div class="drawer-kpi-value">—</div></div>
        <div class="drawer-kpi"><div class="drawer-kpi-label">Páginas</div><div class="drawer-kpi-value" id="kpi-pages">CONTAR</div></div>
      </div>
    </div>

  </div>

  <div class="drawer-footer">
    <div class="drawer-footer-label">Responsável</div>
    <div class="drawer-footer-person">
      <div class="drawer-footer-avatar">VC</div>
      <div>
        <div class="drawer-footer-name">Victor Carvalho</div>
        <div class="drawer-footer-role">Gestão &amp; Inovação</div>
      </div>
    </div>
  </div>

</div>
```

## 6. CSS do drawer (incluir no `<style>` da página)

```css
/* ── DRAWER ── */
.drawer-overlay { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.3); z-index:300; opacity:0; transition:opacity .25s; }
.drawer-overlay.open { display:block; opacity:1; }
.drawer { position:fixed; top:0; right:0; bottom:0; width:88%; max-width:340px; background:var(--white); z-index:301; transform:translateX(100%); transition:transform .28s cubic-bezier(.4,0,.2,1); display:flex; flex-direction:column; overflow:hidden; }
.drawer.open { transform:translateX(0); }
.drawer-header { display:flex; align-items:center; justify-content:space-between; padding:0 16px; height:52px; border-bottom:1px solid var(--border); flex-shrink:0; }
.drawer-title { font-family:"DM Mono",monospace; font-size:10px; font-weight:500; letter-spacing:.14em; text-transform:uppercase; color:var(--t1); }
.drawer-close { width:28px; height:28px; background:var(--bg); border:1px solid var(--border); border-radius:var(--r); display:flex; align-items:center; justify-content:center; cursor:pointer; transition:border-color .15s; }
.drawer-close:hover { border-color:var(--carbon); }
.drawer-close svg { width:13px; height:13px; stroke:var(--t2); fill:none; stroke-width:2; stroke-linecap:round; }
.drawer-body { flex:1; overflow-y:auto; padding:20px 16px; }
.drawer-section { margin-bottom:24px; }
.drawer-section-label { font-family:"DM Mono",monospace; font-size:9px; font-weight:500; letter-spacing:.16em; text-transform:uppercase; color:var(--t3); margin-bottom:10px; display:flex; align-items:center; gap:8px; }
.drawer-section-label::after { content:""; flex:1; height:1px; background:var(--border); }
.drawer-about { font-size:13px; line-height:1.7; color:var(--t2); }
.drawer-kpi-grid { display:grid; grid-template-columns:1fr 1fr; gap:6px; }
.drawer-kpi { background:var(--bg); border:1px solid var(--border); border-radius:var(--r); padding:12px; }
.drawer-kpi-label { font-family:"DM Mono",monospace; font-size:8.5px; font-weight:500; letter-spacing:.12em; text-transform:uppercase; color:var(--t3); margin-bottom:5px; }
.drawer-kpi-value { font-size:26px; font-weight:700; color:var(--t1); line-height:1; }
.drawer-version { background:var(--carbon); border-radius:var(--r); padding:14px 16px; display:flex; align-items:center; justify-content:space-between; }
.drawer-version-label { font-family:"DM Mono",monospace; font-size:9px; letter-spacing:.12em; text-transform:uppercase; color:rgba(255,255,255,.4); }
.drawer-version-val { font-family:"DM Mono",monospace; font-size:20px; font-weight:300; color:var(--citric); letter-spacing:.04em; }
.drawer-footer { padding:12px 16px 16px; flex-shrink:0; background:var(--white); }
.drawer-footer-label { font-family:"DM Mono",monospace; font-size:9px; font-weight:500; letter-spacing:.16em; text-transform:uppercase; color:var(--t3); margin-bottom:10px; display:flex; align-items:center; gap:8px; }
.drawer-footer-label::after { content:""; flex:1; height:1px; background:var(--border); }
.drawer-footer-person { display:flex; align-items:center; gap:10px; }
.drawer-footer-avatar { width:32px; height:32px; border-radius:50%; background:var(--carbon); display:flex; align-items:center; justify-content:center; font-family:"DM Mono",monospace; font-size:10px; font-weight:500; color:var(--citric); flex-shrink:0; }
.drawer-footer-name { font-size:13px; font-weight:600; color:var(--t1); }
.drawer-footer-role { font-family:"DM Mono",monospace; font-size:9px; color:var(--t3); letter-spacing:.04em; margin-top:1px; }
```

Responsivo (adicionar dentro do `@media (min-width:768px)`):

```css
.drawer { max-width:420px; }
```

## 7. JavaScript do drawer (incluir no `<script>` final)

```js
function openDrawer() {
  document.getElementById('drawer').classList.add('open');
  document.getElementById('drawer-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
}
function closeDrawer() {
  document.getElementById('drawer').classList.remove('open');
  document.getElementById('drawer-overlay').classList.remove('open');
  document.body.style.overflow = '';
}
```

## 8. Botão de abertura no header

O header da página DEVE conter o botão `+` para abrir o drawer:

```html
<button class="header-plus" onclick="openDrawer()">
  <svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
</button>
```

CSS do botão (geralmente já existe no header):

```css
.header-plus { width:30px; height:30px; background:var(--carbon); border:none; border-radius:var(--r); display:flex; align-items:center; justify-content:center; cursor:pointer; flex-shrink:0; }
.header-plus svg { width:14px; height:14px; stroke:var(--citric); fill:none; stroke-width:2.5; stroke-linecap:round; }
```

## 9. Contagem automática de páginas (GitHub Action)

O workflow `.github/workflows/update-page-count.yml` roda automaticamente a cada push que altera `compliance/**/*.html`:

1. Conta todos os `.html` dentro de `compliance/`
2. Busca todos os arquivos que contêm `id="kpi-pages"` (auto-detecção)
3. Substitui o valor com `sed`
4. Faz commit automático se mudou

**Não é necessário manter lista fixa de arquivos** — qualquer página com `id="kpi-pages"` será atualizada.

## 10. Checklist ao aplicar drawer em página nova

1. Copiar o bloco CSS do §6 para o `<style>` da página.
2. Adicionar o botão `header-plus` no header (§8).
3. Colar o bloco HTML do §5 antes do `</body>`.
4. Contar os `.html` em `compliance/` e substituir `CONTAR` pelo número correto.
5. Adicionar as funções JS do §7 no `<script>` final.
6. Atualizar `id="kpi-pages"` nos demais drawers para o novo total.
7. Commit, push. A GitHub Action cuidará das próximas atualizações de contagem.

## 11. Checklist ao criar nova página em `compliance/` (mesmo sem drawer)

Se a página **não** terá drawer (ex.: PDF viewer, página auxiliar):
- O total de `id="kpi-pages"` nos drawers existentes será atualizado pela GitHub Action no próximo push.
- Nenhuma ação manual necessária.

## 12. Caso especial: `sancoes.html`

O drawer de `sancoes.html` tem uma seção extra **"Ferramentas"** entre "Números" e o footer, com botões de ação (ex.: "Gerar Medida Disciplinar"). Ao copiar o drawer para páginas que precisam de ferramentas, usar `sancoes.html` como referência.
