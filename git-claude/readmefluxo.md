# hflow — Padrão de Fluxograma Interativo · Portal Líderes TATÁ

**Versão atual:** v1.0a  
**Última atualização:** 2026-05-11  
**Referências canônicas:** `compliance/conceitos/5s.html` · `compliance/areas/rh/sancoes.html`

---

## 1. Visão Geral

O `hflow` é o padrão de fluxograma interativo com navegação horizontal por slides (cards). Permite transformar conteúdo longo e sequencial em etapas didáticas com:

- Barra de progresso + trilha de dots numerados no topo (sticky)
- Navegação por swipe (scroll-snap), botões Anterior/Próximo e teclado
- Suporte a cards normais, bloqueados (com ou sem desbloqueio) e card de capa e fechamento
- Interação de checkbox em listas (check verde animado)
- Modo fullscreen (ocupa toda a viewport, botões ancorados no rodapé)

**Princípio:** cada instância é autocontida num `<div class="hflow-outer">` com um único IIFE de JS. A classe `hflow-*` não vaza para fora do padrão.

---

## 2. Anatomia Completa

```
┌──────────────────────────────────────────────────────────────┐
│  STICKY (hflow-sticky)                                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Etapa 2 de 5 — Seiton · Organização          40%   │   │
│  │  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │   │
│  │  [01✓] ─── [02●] ─── [03] ─── [04🔒] ─── [05🔒] ─── [✓🔒] │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  OUTER (hflow-outer)  ← position:relative; overflow:hidden  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ [⛶ expand]                                           │   │
│  │  ← TRACK (hflow-track) scroll-snap horizontal →      │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐  │   │
│  │  │ CAPA     │ │ CARD 1   │ │ CARD 2…5 │ │ FINAL  │  │   │
│  │  │ (carbon) │ │ [01] Ti  │ │ [0X] Ti  │ │ ✓ Done │  │   │
│  │  │ Timeline │ │ ☐ item   │ │ ☐ item   │ │ carbon │  │   │
│  │  │ [Começar]│ │ [callout]│ │ [callout]│ │[Reinic]│  │   │
│  │  │          │ │ [← | →]  │ │ [← | →]  │ │        │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Tipos de Card

| Tipo | Classe(s) | Descrição |
|---|---|---|
| Capa | `is-cover` | Slide 0 carbon com timeline/intro e CTA Começar |
| Normal | *(sem classe extra)* | Conteúdo com checkbox list + callout |
| Bloqueado desbloqueável | `is-locked` + `data-unlockable="true"` | Lock overlay com botão Desbloquear |
| Bloqueado permanente | `is-locked` | Lock overlay sem botão ("Disponível em breve") |
| Final | `is-final` | Carbon centralizado com ícone ✓ e botão Reiniciar |

---

## 4. Estrutura HTML Completa

### 4.1 Sticky (fora do outer, antes dele)

```html
<div class="hflow-sticky">
  <div class="hflow-prog-row">
    <span class="hflow-prog-name" id="hf-step-name">
      <strong>Etapa 1 de 5</strong> — Nome · Subtítulo
    </span>
    <span class="hflow-prog-pct" id="hf-pct">0%</span>
  </div>
  <div class="hflow-prog-bar">
    <div class="hflow-prog-fill" id="hf-fill"></div>
  </div>
  <div class="hflow-dots" id="hf-dots"></div>
  <!-- dots gerados por JS -->
</div>
```

### 4.2 Outer + botão fullscreen

```html
<div class="hflow-outer" id="hf-outer">
  <button class="flow-expand" id="flow-expand" type="button" aria-label="Expandir tela cheia">
    <!-- SVG expand (substituído por compress quando ativo) -->
    <svg viewBox="0 0 24 24"><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/></svg>
  </button>
  <div class="hflow-track" id="hf-track">
    <!-- cards aqui -->
  </div>
</div>
```

### 4.3 Card 0 — Capa (carbon)

```html
<div class="hflow-card is-cover" id="hf-card-0">
  <div class="flow-cover-card">
    <div class="flow-cover-headline">TÍTULO</div>
    <div class="flow-cover-sub">Subtítulo da capa</div>
    <!-- timeline (opcional — ver seção 5) -->
    <div class="flow-cover-list" id="hf-cover-list"></div>
    <button class="flow-cover-cta" type="button" onclick="hfGo(1)">
      Começar
      <span class="cta-chevrons">
        <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
        <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
        <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
      </span>
    </button>
  </div>
</div>
```

> **Capa é via de mão única:** uma vez que o usuário avançou, não é possível voltar via swipe ou teclado. O botão Anterior no card 1 é `visibility:hidden`.

### 4.4 Card normal

```html
<div class="hflow-card" id="hf-card-N">
  <div class="hflow-card-inner">
    <div class="hflow-card-top">
      <div class="hflow-card-num">0N</div>
      <div>
        <p class="hflow-card-title">Título do card</p>
        <p class="hflow-card-sub">Subtítulo ou descrição curta</p>
      </div>
    </div>
    <div class="hflow-card-body">
      <ul class="hflow-list">
        <!-- cada <li> é um checkbox interativo (ver seção 6) -->
        <li role="checkbox" tabindex="0" aria-checked="false">Texto do item</li>
        <li role="checkbox" tabindex="0" aria-checked="false"><strong>Negrito</strong> + texto</li>
      </ul>
      <!-- callout info (carbon) ou alert (amber) -->
      <div class="hflow-info"><strong>Label:</strong> conteúdo informativo.</div>
      <!-- ou: <div class="hflow-alert"><strong>Cuidado:</strong> aviso.</div> -->
    </div>
  </div>
  <div class="hflow-arrows">
    <button class="hflow-arrow-btn" onclick="hfGo(-1)">
      <svg viewBox="0 0 24 24"><polyline points="15 18 9 12 15 6"/></svg>Anterior
    </button>
    <button class="hflow-arrow-btn fwd" onclick="hfGo(1)">
      Próximo<svg viewBox="0 0 24 24"><polyline points="9 18 15 12 9 6"/></svg>
    </button>
  </div>
</div>
```

### 4.5 Card bloqueado desbloqueável

```html
<div class="hflow-card is-locked" id="hf-card-N" data-locked="true" data-unlockable="true">
  <div class="hflow-card-inner">
    <!-- conteúdo normal (fica borrado sob o overlay) -->
    ...
    <div class="hflow-lock">
      <div class="hflow-lock-icon"><svg><!-- cadeado fechado --></svg></div>
      <div class="hflow-lock-eyebrow">0N · Nome</div>
      <div class="hflow-lock-title">Conteúdo bloqueado</div>
      <div class="hflow-lock-text">Toque no botão para liberar este conteúdo.</div>
      <button class="hflow-lock-btn" type="button" onclick="hfUnlock(N)">
        <svg><!-- cadeado aberto --></svg>
        Desbloquear
      </button>
    </div>
  </div>
  <div class="hflow-arrows">...</div>
</div>
```

### 4.6 Card bloqueado permanente

```html
<div class="hflow-card is-locked" id="hf-card-N" data-locked="true">
  <div class="hflow-card-inner">
    <!-- conteúdo (borrado) -->
    ...
    <div class="hflow-lock">
      <div class="hflow-lock-icon"><svg><!-- cadeado --></svg></div>
      <div class="hflow-lock-eyebrow">0N · Nome</div>
      <div class="hflow-lock-title">Conteúdo bloqueado</div>
      <div class="hflow-lock-text">Disponível em breve.</div>
      <!-- sem botão Desbloquear -->
    </div>
  </div>
  <div class="hflow-arrows">...</div>
</div>
```

### 4.7 Card final

```html
<div class="hflow-card is-final" id="hf-card-LAST">
  <div class="hflow-final-icon">
    <svg width="44" height="44" viewBox="0 0 24 24" fill="none"
         stroke="#CFFF00" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
      <polyline points="22 4 12 14.01 9 11.01"/>
    </svg>
  </div>
  <p class="hflow-final-title">Ciclo Concluído</p>
  <p class="hflow-final-sub">Texto de encerramento — incentivo à aplicação ou próximos passos.</p>
  <button class="hflow-final-reset" type="button" onclick="hfGoTo(1)">
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor"
         stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
      <polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-3.54"/>
    </svg>
    Reiniciar
  </button>
  <!-- Lock overlay: aparece quando há etapas bloqueadas (gerenciado por hfRender) -->
  <div class="hflow-lock" id="hf-final-lock">
    <div class="hflow-lock-icon"><svg><!-- cadeado --></svg></div>
    <div class="hflow-lock-eyebrow">Conclusão</div>
    <div class="hflow-lock-title">Etapas pendentes</div>
    <div class="hflow-lock-text">Desbloqueie todas as etapas para concluir.</div>
  </div>
</div>
```

---

## 5. Timeline Zigzag da Capa (opcional)

Usado quando a capa precisa exibir um resumo visual das etapas (ex.: 5S). Gerado por JS.

**HTML necessário:** apenas `<div class="flow-cover-list" id="hf-cover-list"></div>`

**CSS estrutural:**
```css
.flow-cover-list {
  list-style:none; padding:8px 0 4px; margin:0;
  display:grid; grid-template-columns:repeat(N, 1fr);
  align-items:center; position:relative;
}
.flow-cover-list::before {               /* linha horizontal de fundo */
  content:""; position:absolute;
  left:10%; right:10%; top:50%; transform:translateY(-50%);
  height:2px; background:rgba(255,255,255,.18); z-index:0;
}
.flow-cover-tl-circle { grid-row:2; /* círculo com ícone */ }
/* textos alternados: row 1 (ímpares) / row 3 (pares) */
```

**JS de geração:**
```javascript
var html = '';
for (var i = 0; i < N_STEPS; i++) {
  var rowText = (i % 2 === 0) ? 1 : 3;
  html += '<div class="flow-cover-tl-text" style="grid-column:' + (i+1) + ';grid-row:' + rowText + ';">' +
    '<div class="flow-cover-tl-eb">' + (i+1) + 'º · ' + LABELS[i] + '</div>' +
    '<div class="flow-cover-tl-name">' + NAMES[i] + '</div>' +
  '</div>';
}
for (var j = 0; j < N_STEPS; j++) {
  html += '<div class="flow-cover-tl-circle" style="grid-column:' + (j+1) + ';">' + ICONS[j] + '</div>';
}
document.getElementById('hf-cover-list').innerHTML = html;
```

---

## 6. Interação de Checkbox nas Listas

Cada `<li>` da `.hflow-list` funciona como checkbox interativo via CSS + JS (sem `<input>`).

**Requisitos do `<li>`:**
```html
<li role="checkbox" tabindex="0" aria-checked="false">Texto do item</li>
```

**CSS — estado marcado:**
```css
.hflow-list li[data-checked="true"] { color:var(--t3); }
.hflow-list li[data-checked="true"] strong { color:var(--t2); }
.hflow-list li[data-checked="true"]::before { background:var(--green-tx); border-color:var(--green-tx); }
.hflow-list li[data-checked="true"]::after  { transform:rotate(-45deg) scale(1); }
```

**JS — event delegation no track (sem listener por item):**
```javascript
track.addEventListener('click', function(e) {
  var li = e.target.closest && e.target.closest('.hflow-list li');
  if (!li) return;
  var on = li.dataset.checked !== 'true';
  li.dataset.checked = on ? 'true' : 'false';
  li.setAttribute('aria-checked', on ? 'true' : 'false');
});
track.addEventListener('keydown', function(e) {
  if (e.key !== ' ' && e.key !== 'Enter') return;
  var li = e.target.closest && e.target.closest('.hflow-list li');
  if (li) {
    e.preventDefault();
    var on = li.dataset.checked !== 'true';
    li.dataset.checked = on ? 'true' : 'false';
    li.setAttribute('aria-checked', on ? 'true' : 'false');
  }
});
```

> Estado mantido **em memória** durante a sessão. Não persiste no reload (intencional).

---

## 7. JS Controller (IIFE)

Estrutura mínima do controlador. Adaptar `HF_TOTAL`, `HF_STEPS`, nomes e ícones conforme a instância.

```javascript
(function() {
  var HF_TOTAL = 7;   // 0=capa, 1..N=steps, N+1=final
  var HF_STEPS = 5;   // número de steps reais (sem capa e sem final)
  var hfCur = 0;
  var outer    = document.getElementById('hf-outer');
  var track    = document.getElementById('hf-track');
  var dotsEl   = document.getElementById('hf-dots');
  var stepName = document.getElementById('hf-step-name');
  var pctEl    = document.getElementById('hf-pct');
  var fillEl   = document.getElementById('hf-fill');
  if (!outer || !track) return;

  /* Constantes dos steps */
  var LABELS = ['Step 1', 'Step 2', /* ... */];   // nomes curtos
  var NAMES  = ['Nome 1', 'Nome 2', /* ... */];   // nomes longos
  var LOCK_DOT_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="9" rx="1.5"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>';

  /* --- Gerar dots (HF_STEPS dots + 1 dot ✓) --- */
  for (var k = 0; k < HF_STEPS + 1; k++) {
    (function(idx) {
      var isFinal = idx === HF_STEPS;
      var item = document.createElement('div');
      item.className = 'hflow-dot-item';
      var dot = document.createElement('div');
      dot.className = 'hflow-dot';
      dot.textContent = isFinal ? '✓' : String(idx + 1).padStart(2, '0');
      dot.title = isFinal ? 'Concluído' : (LABELS[idx] + ' · ' + NAMES[idx]);
      dot.addEventListener('click', function() { hfGoTo(isFinal ? HF_TOTAL - 1 : idx + 1); });
      item.appendChild(dot);
      if (idx < HF_STEPS) {   // linha entre dots (não após o ✓)
        var line = document.createElement('div');
        line.className = 'hflow-dot-line';
        item.appendChild(line);
      }
      dotsEl.appendChild(item);
    })(k);
  }

  /* --- Helpers --- */
  function isLocked(cardIdx) {
    var c = document.getElementById('hf-card-' + cardIdx);
    return c && c.dataset.locked === 'true';
  }

  function anyStepLocked() {
    for (var i = 1; i <= HF_STEPS; i++) { if (isLocked(i)) return true; }
    return false;
  }

  /* --- Render --- */
  function hfRender() {
    /* is-current nos cards */
    for (var i = 0; i < HF_TOTAL; i++) {
      var c = document.getElementById('hf-card-' + i);
      if (c) c.classList.toggle('is-current', i === hfCur);
    }

    /* dots */
    var dots  = dotsEl.querySelectorAll('.hflow-dot');
    var lines = dotsEl.querySelectorAll('.hflow-dot-line');
    var locked = anyStepLocked();
    dots.forEach(function(d, i) {
      d.classList.remove('current', 'visited', 'locked');
      var isFinalDot = i === HF_STEPS;
      if (isFinalDot) {
        if (locked) { d.classList.add('locked'); d.innerHTML = LOCK_DOT_SVG; }
        else { d.textContent = '✓'; }
        if (hfCur === HF_TOTAL - 1) d.classList.add('current');
      } else {
        var step = i + 1;
        if (isLocked(step)) { d.classList.add('locked'); d.innerHTML = LOCK_DOT_SVG; }
        else { d.textContent = String(step).padStart(2, '0'); }
        if (hfCur === step) d.classList.add('current');
        else if (hfCur > step) d.classList.add('visited');
      }
    });
    lines.forEach(function(l, i) {
      l.classList.toggle('passed', hfCur > i + 1);
    });

    /* lock do card final */
    var finalLock = document.getElementById('hf-final-lock');
    if (finalLock) finalLock.style.display = locked ? '' : 'none';

    /* barra de progresso (cap 100%) */
    var pct = hfCur === 0 ? 0 : Math.min(Math.round((hfCur / HF_STEPS) * 100), 100);
    fillEl.style.width = pct + '%';
    pctEl.textContent  = pct + '%';

    /* nome da etapa */
    if (hfCur === 0) {
      stepName.innerHTML = '<strong>Visão geral</strong>';
    } else if (hfCur === HF_TOTAL - 1) {
      stepName.innerHTML = '<strong>Concluído!</strong> — Ciclo completo';
    } else {
      stepName.innerHTML = '<strong>Etapa ' + hfCur + ' de ' + HF_STEPS + '</strong> — ' + LABELS[hfCur - 1] + ' · ' + NAMES[hfCur - 1];
    }

    /* scroll */
    track.scrollTo({ left: hfCur * track.offsetWidth, behavior: 'smooth' });

    /* botões Anterior */
    track.querySelectorAll('.hflow-arrow-btn:not(.fwd)').forEach(function(b) {
      var card = b.closest('.hflow-card');
      if (!card) return;
      var idx = parseInt(card.id.replace('hf-card-', ''), 10);
      if (idx <= 1) { b.style.visibility = 'hidden'; b.disabled = true; }
      else          { b.style.visibility = '';        b.disabled = false; }
    });

    /* botões Próximo */
    track.querySelectorAll('.hflow-arrow-btn.fwd').forEach(function(b) {
      var card = b.closest('.hflow-card');
      if (!card) return;
      var idx = parseInt(card.id.replace('hf-card-', ''), 10);
      b.disabled = idx === HF_TOTAL - 1;
    });
  }

  /* --- Navegação --- */
  function hfGo(dir) { hfGoTo(hfCur + dir); }
  function hfGoTo(i) {
    if (i < 0 || i >= HF_TOTAL) return;
    if (hfCur > 0 && i === 0) return;   // sem retorno à capa
    hfCur = i;
    hfRender();
  }
  window.hfGo   = hfGo;
  window.hfGoTo = hfGoTo;

  /* --- Desbloquear --- */
  window.hfUnlock = function(idx) {
    var card = document.getElementById('hf-card-' + idx);
    if (!card) return;
    card.dataset.locked = 'false';
    card.classList.remove('is-locked');
    var lock = card.querySelector('.hflow-lock');
    if (lock) lock.remove();
    hfRender();
  };

  /* --- Checkboxes (event delegation) --- */
  track.addEventListener('click', function(e) {
    var li = e.target.closest && e.target.closest('.hflow-list li');
    if (!li) return;
    var on = li.dataset.checked !== 'true';
    li.dataset.checked = on ? 'true' : 'false';
    li.setAttribute('aria-checked', on ? 'true' : 'false');
  });
  track.addEventListener('keydown', function(e) {
    if (e.key !== ' ' && e.key !== 'Enter') return;
    var li = e.target.closest && e.target.closest('.hflow-list li');
    if (li) {
      e.preventDefault();
      var on = li.dataset.checked !== 'true';
      li.dataset.checked = on ? 'true' : 'false';
      li.setAttribute('aria-checked', on ? 'true' : 'false');
    }
  });

  /* --- Scroll snap detection --- */
  var hfTimer;
  track.addEventListener('scroll', function() {
    clearTimeout(hfTimer);
    hfTimer = setTimeout(function() {
      var idx = Math.round(track.scrollLeft / track.offsetWidth);
      if (idx !== hfCur && idx >= 0 && idx < HF_TOTAL) {
        if (hfCur > 0 && idx === 0) { track.scrollTo({ left: hfCur * track.offsetWidth }); return; }
        hfCur = idx; hfRender();
      }
    }, 80);
  });

  /* --- Teclado --- */
  document.addEventListener('keydown', function(e) {
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
    if (e.key === 'ArrowRight' && hfCur < HF_TOTAL - 1) hfGo(1);
    if (e.key === 'ArrowLeft'  && hfCur > 1)             hfGo(-1);
  });

  /* --- Fullscreen --- */
  var expandBtn   = document.getElementById('flow-expand');
  var EXPAND_SVG  = '<svg viewBox="0 0 24 24"><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/></svg>';
  var COMPRESS_SVG= '<svg viewBox="0 0 24 24"><polyline points="4 14 10 14 10 20"/><polyline points="20 10 14 10 14 4"/><line x1="14" y1="10" x2="21" y2="3"/><line x1="3" y1="21" x2="10" y2="14"/></svg>';

  function setFullscreen(on) {
    outer.classList.toggle('is-fullscreen', on);
    document.body.classList.toggle('has-flow-fullscreen', on);
    document.documentElement.classList.toggle('has-flow-fullscreen', on);
    if (expandBtn) {
      expandBtn.innerHTML = on ? COMPRESS_SVG : EXPAND_SVG;
      expandBtn.setAttribute('aria-label', on ? 'Sair da tela cheia' : 'Expandir tela cheia');
    }
    setTimeout(function() { track.scrollTo({ left: hfCur * track.offsetWidth }); }, 60);
  }

  if (expandBtn) {
    expandBtn.addEventListener('click', function(e) {
      e.preventDefault(); e.stopPropagation();
      setFullscreen(!outer.classList.contains('is-fullscreen'));
    });
  }
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && outer.classList.contains('is-fullscreen')) setFullscreen(false);
  });
  window.addEventListener('resize', function() {
    track.scrollTo({ left: hfCur * track.offsetWidth });
  });

  /* --- Init --- */
  hfRender();
})();
```

---

## 8. CSS Completo

```css
/* ── Sticky ── */
.hflow-sticky { background:var(--bg); padding:13px 16px 10px; margin-bottom:8px; }
.hflow-prog-row { display:flex; justify-content:space-between; align-items:center; gap:10px; margin-bottom:7px; }
.hflow-prog-name { font-size:11px; color:var(--t3); line-height:1.3; }
.hflow-prog-name strong { color:var(--t1); font-weight:600; font-size:12px; }
.hflow-prog-pct { font-family:"DM Mono",monospace; font-size:11px; font-weight:500; color:var(--t2); flex-shrink:0; }
.hflow-prog-bar { height:5px; background:var(--border); border-radius:100px; overflow:hidden; }
.hflow-prog-fill { height:100%; background:var(--carbon); border-radius:100px; transition:width .35s ease; width:0%; }

/* ── Dots ── */
.hflow-dots { display:flex; align-items:center; margin-top:11px; }
.hflow-dot-item { display:flex; align-items:center; flex:1; }
.hflow-dot {
  width:28px; height:28px; border-radius:50%; flex-shrink:0;
  border:2px solid var(--border); background:var(--white);
  display:flex; align-items:center; justify-content:center;
  font-family:"DM Mono",monospace; font-size:10px; font-weight:500; color:var(--t3);
  transition:all .25s; cursor:pointer; user-select:none;
}
.hflow-dot:hover  { border-color:var(--t2); color:var(--t2); }
.hflow-dot.visited{ border-color:var(--carbon); background:var(--carbon); color:var(--citric); }
.hflow-dot.current{ border-color:var(--carbon); background:var(--carbon); color:var(--citric); box-shadow:0 0 0 3px rgba(53,56,63,.15); }
.hflow-dot.locked { border-style:dashed; background:rgba(53,56,63,.03); color:var(--t3); }
.hflow-dot.locked svg { width:11px; height:13px; stroke:var(--t3); fill:none; stroke-width:2; }
.hflow-dot-line { flex:1; height:2px; background:var(--border); transition:background .35s; }
.hflow-dot-line.passed { background:var(--carbon); }

/* ── Outer + Track ── */
.hflow-outer {
  position:relative; overflow:hidden;
  border-radius:8px; border:1px solid var(--border);
  background:var(--white); margin:0 16px;
}
.hflow-track {
  display:flex; overflow-x:auto;
  scroll-snap-type:x mandatory; -webkit-overflow-scrolling:touch; scrollbar-width:none;
}
.hflow-track::-webkit-scrollbar { display:none; }

/* ── Botão fullscreen ── */
.flow-expand {
  position:absolute; top:8px; right:8px; z-index:20;
  width:32px; height:32px; padding:0;
  background:rgba(255,255,255,.92); color:var(--t1);
  border:1px solid var(--border); border-radius:6px;
  display:flex; align-items:center; justify-content:center;
  cursor:pointer; transition:background .15s, border-color .15s;
}
.flow-expand svg { width:14px; height:14px; stroke:currentColor; fill:none; stroke-width:2; stroke-linecap:round; stroke-linejoin:round; }

/* ── Cards ── */
.hflow-card {
  flex:0 0 100%; scroll-snap-align:start;
  padding:24px 24px 20px; min-height:280px;
  display:flex; flex-direction:column; gap:14px;
  background:var(--white); position:relative;
}
.hflow-card-inner {
  position:relative; flex:1; display:flex; flex-direction:column;
  gap:14px; min-width:0; justify-content:center;
}
.hflow-card-top { display:flex; align-items:flex-start; gap:14px; }
.hflow-card-num {
  width:40px; height:40px; border-radius:50%; flex-shrink:0;
  background:var(--bg); border:2px solid var(--border);
  display:flex; align-items:center; justify-content:center;
  font-family:"DM Mono",monospace; font-size:11px; font-weight:500; color:var(--t3);
}
.hflow-card.is-current .hflow-card-num { background:var(--carbon); border-color:var(--carbon); color:var(--citric); }
.hflow-card-title { font-size:16px; font-weight:700; color:var(--t1); line-height:1.25; margin-bottom:3px; }
.hflow-card.is-current .hflow-card-title { color:var(--carbon); }
.hflow-card-sub { font-size:12px; color:var(--t3); line-height:1.45; }
.hflow-card-body { display:grid; grid-template-columns:1fr; gap:12px; align-items:start; flex:1; }
@media (min-width:768px) { .hflow-card-body { grid-template-columns:1fr 1fr; } }

/* ── Lista checkbox ── */
.hflow-list { list-style:none; display:flex; flex-direction:column; gap:4px; }
.hflow-list li {
  position:relative; padding:6px 8px 6px 28px;
  font-size:12.5px; line-height:1.55; color:var(--t2);
  cursor:pointer; user-select:none; border-radius:5px;
  transition:background .15s, color .15s; outline:none;
}
.hflow-list li::before {
  content:""; position:absolute; left:6px; top:9px;
  width:14px; height:14px; border:1.5px solid var(--carbon);
  border-radius:3px; background:var(--white);
  transition:background .15s, border-color .15s;
}
.hflow-list li::after {
  content:""; position:absolute; left:9px; top:11px;
  width:8px; height:5px;
  border-left:2px solid var(--white); border-bottom:2px solid var(--white);
  transform:rotate(-45deg) scale(0); transform-origin:center;
  transition:transform .18s cubic-bezier(.5,1.6,.5,1);
}
.hflow-list li:hover { background:rgba(0,0,0,.03); }
.hflow-list li:focus-visible { box-shadow:0 0 0 2px rgba(207,255,0,.4); }
.hflow-list li[data-checked="true"] { color:var(--t3); }
.hflow-list li[data-checked="true"] strong { color:var(--t2); }
.hflow-list li[data-checked="true"]::before { background:var(--green-tx); border-color:var(--green-tx); }
.hflow-list li[data-checked="true"]::after  { transform:rotate(-45deg) scale(1); }

/* ── Callouts ── */
.hflow-info {
  background:var(--bg); border:1px solid var(--border);
  border-left:3px solid var(--carbon);
  border-radius:0 var(--r) var(--r) 0;
  padding:10px 13px; font-size:12px; color:var(--t2); line-height:1.6;
}
.hflow-info strong { font-weight:600; color:var(--t1); }
.hflow-alert {
  background:var(--amber-bg); border:1px solid rgba(122,74,0,.2);
  border-left:3px solid var(--amber-tx);
  border-radius:0 var(--r) var(--r) 0;
  padding:10px 13px; font-size:12px; color:var(--amber-tx); line-height:1.6;
}
.hflow-alert strong { font-weight:600; }

/* ── Arrows ── */
.hflow-arrows { display:flex; align-items:center; justify-content:space-between; gap:10px; margin-top:auto; padding-top:10px; }
.hflow-arrow-btn {
  display:flex; align-items:center; gap:5px; background:none; border:none;
  cursor:pointer; font-family:"DM Mono",monospace; font-size:10px; font-weight:500;
  text-transform:uppercase; letter-spacing:.06em; color:var(--t3); padding:4px 0;
  transition:color .2s;
}
.hflow-arrow-btn:hover:not(:disabled) { color:var(--t1); }
.hflow-arrow-btn:disabled { opacity:.25; cursor:default; }
.hflow-arrow-btn.fwd { background:var(--carbon); color:var(--citric); padding:7px 14px; border-radius:var(--r); font-size:11px; }
.hflow-arrow-btn.fwd:hover:not(:disabled) { opacity:.85; }
.hflow-arrow-btn.fwd:disabled { background:var(--border); color:var(--t3); opacity:1; }
.hflow-arrow-btn svg { width:14px; height:14px; stroke:currentColor; fill:none; stroke-width:2.5; stroke-linecap:round; stroke-linejoin:round; }

/* ── Lock overlay ── */
.hflow-card.is-locked .hflow-card-top,
.hflow-card.is-locked .hflow-card-body { filter:blur(4px); pointer-events:none; user-select:none; opacity:.6; }
.hflow-lock {
  position:absolute; inset:0;
  display:flex; flex-direction:column; align-items:center; justify-content:center;
  gap:10px; padding:24px 20px; text-align:center;
  background:rgba(244,244,244,.55);
  -webkit-backdrop-filter:blur(2px); backdrop-filter:blur(2px); z-index:5;
}
.hflow-lock-icon {
  width:52px; height:52px; background:var(--carbon); border-radius:50%;
  display:flex; align-items:center; justify-content:center;
  box-shadow:0 4px 18px rgba(53,56,63,.18);
}
.hflow-lock-icon svg { width:22px; height:22px; stroke:var(--citric); fill:none; stroke-width:2; stroke-linecap:round; stroke-linejoin:round; }
.hflow-lock-eyebrow { font-family:"DM Mono",monospace; font-size:9px; font-weight:500; letter-spacing:.16em; text-transform:uppercase; color:var(--t3); }
.hflow-lock-title { font-size:15px; font-weight:700; color:var(--t1); line-height:1.25; }
.hflow-lock-text { font-size:12.5px; line-height:1.5; color:var(--t2); max-width:260px; }
.hflow-lock-btn {
  display:inline-flex; align-items:center; gap:8px; margin-top:6px;
  background:var(--carbon); color:var(--citric); border:0; border-radius:100px;
  padding:11px 20px; font-family:"DM Mono",monospace; font-size:11px; font-weight:600;
  letter-spacing:.08em; text-transform:uppercase; cursor:pointer;
  transition:transform .15s, background .15s; box-shadow:0 4px 14px rgba(53,56,63,.25);
}
.hflow-lock-btn:hover { background:#1c1d22; transform:translateY(-1px); }
.hflow-lock-btn svg { width:13px; height:13px; stroke:currentColor; fill:none; stroke-width:2; stroke-linecap:round; stroke-linejoin:round; }

/* ── Capa carbon ── */
.hflow-card.is-cover { padding:0; gap:0; min-height:0; background:var(--carbon); }
.flow-cover-card { background:var(--carbon); color:var(--white); padding:32px 18px 36px; text-align:center; }
.flow-cover-headline { font-size:44px; font-weight:700; color:var(--citric); line-height:1; margin-bottom:6px; letter-spacing:-1.5px; }
.flow-cover-sub { font-size:13px; line-height:1.45; color:rgba(255,255,255,.7); margin-bottom:22px; }
.flow-cover-cta {
  display:inline-flex; align-items:center; gap:8px; margin-top:22px;
  background:var(--citric); color:var(--carbon); border:0; border-radius:100px;
  padding:12px 22px; font-family:"DM Mono",monospace; font-size:11px; font-weight:700;
  letter-spacing:.08em; text-transform:uppercase; cursor:pointer;
  transition:transform .15s, box-shadow .15s; box-shadow:0 4px 14px rgba(207,255,0,.22);
}
.flow-cover-cta:hover { transform:translateY(-1px); box-shadow:0 6px 18px rgba(207,255,0,.32); }

/* ── Chevrons animados do CTA ── */
@keyframes hfChevron {
  0%, 60%, 100% { opacity:.25; }
  30% { opacity:1; }
}
.cta-chevrons { display:inline-flex; align-items:center; gap:0; margin-left:2px; }
.cta-chevrons svg { flex-shrink:0; }
.cta-chevrons svg:nth-child(1) { animation:hfChevron 1.4s ease-in-out infinite 0s; }
.cta-chevrons svg:nth-child(2) { animation:hfChevron 1.4s ease-in-out infinite .2s; }
.cta-chevrons svg:nth-child(3) { animation:hfChevron 1.4s ease-in-out infinite .4s; }

/* ── Card final ── */
.hflow-card.is-final {
  background:var(--carbon); align-items:center; justify-content:center;
  text-align:center; min-height:260px; gap:0;
}
.hflow-final-icon { margin-bottom:14px; }
.hflow-final-title { font-size:20px; font-weight:700; color:var(--citric); margin-bottom:8px; font-family:"DM Mono",monospace; letter-spacing:.03em; text-transform:uppercase; }
.hflow-final-sub { font-size:13px; color:rgba(255,255,255,.6); line-height:1.6; max-width:310px; }
.hflow-final-reset {
  margin-top:20px; display:inline-flex; align-items:center; gap:6px;
  background:none; border:1px solid rgba(207,255,0,.3); border-radius:var(--r);
  padding:7px 14px; font-family:"DM Mono",monospace; font-size:10px; font-weight:500;
  text-transform:uppercase; letter-spacing:.06em; color:rgba(207,255,0,.7);
  cursor:pointer; transition:all .2s;
}
.hflow-final-reset:hover { border-color:var(--citric); color:var(--citric); }

/* ── Fullscreen ── */
.hflow-outer.is-fullscreen {
  position:fixed; top:0; right:0; bottom:0; left:0;
  width:auto; height:auto; z-index:9999;
  border-radius:0; border:0; max-width:none; margin:0; background:var(--white);
}
.hflow-outer.is-fullscreen .hflow-track,
.hflow-outer.is-fullscreen .hflow-card { height:100vh; min-height:100vh; max-height:100vh; }
.hflow-outer.is-fullscreen .hflow-card { padding:60px 24px 0; overflow:hidden; }
.hflow-outer.is-fullscreen .hflow-card.is-cover { padding:0; }
.hflow-outer.is-fullscreen .hflow-card.is-cover .flow-cover-card {
  height:100%; display:flex; flex-direction:column; justify-content:center; padding:60px 28px 40px;
}
.hflow-outer.is-fullscreen .hflow-card-inner {
  flex:1; min-height:0; overflow-y:auto; -webkit-overflow-scrolling:touch;
  margin:0 -24px; padding:0 24px; justify-content:flex-start;
}
.hflow-outer.is-fullscreen .hflow-arrows {
  flex-shrink:0; background:var(--white);
  margin:0 -24px; padding:14px 24px; border-top:1px solid var(--border);
}
.hflow-outer.is-fullscreen .flow-expand {
  position:fixed; top:12px; right:12px; width:36px; height:36px;
  background:var(--carbon); color:var(--white); border-color:var(--carbon);
}
body.has-flow-fullscreen .hflow-sticky { display:none; }
html.has-flow-fullscreen, body.has-flow-fullscreen { overflow:hidden; }
body.has-flow-fullscreen .page,
body.has-flow-fullscreen .page > * { transform:none !important; animation:none !important; filter:none !important; }

/* ── Responsive ── */
@media (max-width:540px) {
  .hflow-card { padding:20px 16px 16px; }
}
@media (min-width:768px) {
  .hflow-sticky { padding:13px 40px 10px; max-width:1100px; margin-left:auto; margin-right:auto; }
  .hflow-outer  { margin:0 40px; max-width:1020px; margin-left:auto; margin-right:auto; }
}
```

---

## 9. Tokens necessários na página

```css
:root {
  --carbon:#35383F; --citric:#CFFF00;
  --bg:#F4F4F4; --white:#FFFFFF; --border:#E2E2E2;
  --t1:#111111; --t2:#555555; --t3:#999999;
  --green-bg:#EAF4ED; --green-tx:#1A5C2A;
  --amber-bg:#FFF4DC; --amber-tx:#7A4A00;
  --r:6px;
}
```

---

## 10. Checklist de Implementação

### Nova página do zero

- [ ] Copiar bloco CSS completo da seção 8 (não inventar variações)
- [ ] Adicionar tokens `:root` da seção 9
- [ ] Adicionar HTML: sticky → outer → track → cards na ordem
- [ ] Instanciar IIFE da seção 7 ajustando `HF_TOTAL`, `HF_STEPS`, `LABELS`, `NAMES`
- [ ] Para capa: adicionar HTML do card 0 e chamar gerador de timeline se necessário
- [ ] Para cards bloqueados: `data-locked="true"` + `data-unlockable="true"` se desbloqueável
- [ ] Para card final: adicionar `id="hf-final-lock"` no overlay interno
- [ ] Testar: swipe mobile, teclado ← →, ESC fullscreen, unlock, checkboxes, barra de progresso

### Adicionar à página existente com hflow antigo

- [ ] **Checkboxes:** verificar se `<li>` tem `role="checkbox" tabindex="0" aria-checked="false"` + event delegation no track
- [ ] **Dot ✓ final:** loop de dots deve ir até `HF_STEPS + 1` (último = ✓); render trata `isFinalDot`
- [ ] **Lock do card final:** adicionar `id="hf-final-lock"` no card final; hfRender faz toggle do display
- [ ] **`anyStepLocked()`:** substituir lógica pontual por helper que percorre todos os steps
- [ ] **Cap de progresso:** `Math.min(..., 100)` para evitar >100% no card final
- [ ] **`justify-content:center`** em `.hflow-card-inner` (conteúdo centralizado verticalmente)
- [ ] **Fullscreen:** copiar blocos `is-fullscreen` + `has-flow-fullscreen` se ausentes

---

## 11. Páginas com hflow ativo

| Arquivo | Steps | Capa | Locks | Final | Fullscreen | Checkboxes |
|---|---|---|---|---|---|---|
| `compliance/conceitos/5s.html` | 5 | ✓ | 2 (4 desbloq, 5 perm) | ✓ | ✓ | ✓ |
| `compliance/areas/rh/sancoes.html` | 5 | — | 0* | ✓ | — | ✓ |

*Sanções não tem cards bloqueados ativos, mas o pattern de `anyStepLocked()` + `hf-final-lock` está implementado e pronto para uso futuro.

---

## 12. Histórico de Versões

| Versão | Data | Mudança |
|---|---|---|
| v1.0a | 2026-05-11 | Documentação inicial baseada na implementação completa do 5S |
