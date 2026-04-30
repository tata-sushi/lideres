# readmecss — TATÁ Sushi Design System

---

## Pílulas de Status

### Propriedades base

| Propriedade | Valor |
|---|---|
| `font-family` | DM Mono |
| `font-size` | 10px |
| `font-weight` | 500 |
| `letter-spacing` | 0.3px |
| `padding` | 3px 9px |
| `border-radius` | 100px |

```css
.status-badge {
  display: inline-flex;
  align-items: center;
  padding: 3px 9px;
  border-radius: 100px;
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  font-weight: 500;
  letter-spacing: 0.3px;
  white-space: nowrap;
  flex-shrink: 0;
}
```

---

### Tokens de cor

| Variante | bg | text | Uso semântico |
|---|---|---|---|
| Carbon + Citric | `#35383F` | `#CFFF00` | Positivo / aprovado / clicado |
| Azul | `#E8F0FA` | `#1A3A5C` | Pendente / aguardando |
| Âmbar | `#FFF4DC` | `#7A4A00` | Atenção / em análise |
| Vermelho | `#FDEAEA` | `#7A1A1A` | Negativo / rejeitado / não clicado |

```css
/* Carbon + Citric — positivo / aprovado / clicado */
background: #35383F; color: #CFFF00;

/* Azul — pendente / aguardando */
background: #E8F0FA; color: #1A3A5C;

/* Âmbar — atenção / em análise */
background: #FFF4DC; color: #7A4A00;

/* Vermelho — negativo / rejeitado / não clicado */
background: #FDEAEA; color: #7A1A1A;
```

---

### Exemplo de uso — Recrutamento & Seleção

```css
/* Entrevistas — prefixo s- */
.s-aprovado-para-teste   { background: #35383F; color: #CFFF00; }
.s-aguardando-entrevista { background: #E8F0FA; color: #1A3A5C; }
.s-aguardando-devolutiva { background: #FFF4DC; color: #7A4A00; }
.s-nao-selecionado       { background: #FDEAEA; color: #7A1A1A; }
.s-nao-entrou            { background: #FDEAEA; color: #7A1A1A; }

/* Testes — prefixo sf- */
.sf-contratado           { background: #35383F; color: #CFFF00; }
.sf-aguardando-teste     { background: #E8F0FA; color: #1A3A5C; }
.sf-aguardando-aprovacao { background: #FFF4DC; color: #7A4A00; }
.sf-nao-contratado       { background: #FDEAEA; color: #7A1A1A; }
.sf-nao-compareceu       { background: #FDEAEA; color: #7A1A1A; }
.sf-cancelado            { background: #FDEAEA; color: #7A1A1A; }
```

---

## KPI Cards

### Estrutura HTML

```html
<div class="kpi-card">
  <span class="kpi-label">Label</span>
  <span class="kpi-number">00</span>
  <span class="kpi-sub"><strong>0</strong> hoje / <strong>0</strong> mês</span>
</div>
```

### CSS

```css
.kpi-card {
  background: #F4F4F4;
  border: 1px solid #E2E2E2;
  border-radius: 8px;
  padding: 12px 14px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  gap: 4px;
}

.kpi-label {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  font-weight: 500;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: #555555;
}

.kpi-number {
  font-size: 28px;
  font-weight: 700;
  color: #35383F;
  line-height: 1;
  letter-spacing: -1px;
  font-variant-numeric: tabular-nums;
}

.kpi-sub {
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  color: #999999;
}

.kpi-sub strong {
  color: #35383F;
  font-weight: 600;
}
```
