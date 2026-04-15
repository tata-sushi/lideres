# Apps Script — Autenticação Hub de Líderes

Script do Google Apps Script que alimenta o login de `lideres.tatasushi.tech`.

## Arquivos

- `auth.gs` — código-fonte do Web App que serve as rotas `listUsers` e `auth`.

## Planilha esperada

Aba **`Usuários`** com as colunas:

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| Usuário | Unidade | Perfil | Páginas | Ativo | Senha | Cargo |

- **Ativo** aceita `s`, `sim`, `true`, `1`.
- **Páginas** é lista opcional separada por vírgula ou ponto-e-vírgula.
- **Cargo** é usado para autopreencher formulários (ex.: PDF de sanções).

## Deploy

1. Abrir a planilha → **Extensões → Apps Script**.
2. Colar o conteúdo de `auth.gs` no `Code.gs`.
3. **Implantar → Nova implantação**
   - Tipo: **Aplicativo da Web**
   - Executar como: **Eu**
   - Quem tem acesso: **Qualquer pessoa**
4. Copiar a URL gerada e atualizar `AUTH_URL` em `/index.html`.

Cada alteração na planilha é refletida instantaneamente — **não é necessário
re-implantar** o script para atualizar usuários, senhas ou cargos.

## Endpoints

### `GET ?action=listUsers`

```json
{ "ok": true, "usuarios": [ { "nome": "...", "unidade": "...", "perfil": "...", "cargo": "..." } ] }
```

### `GET ?action=auth&usuario=<nome>&senha=<senha>`

```json
{ "ok": true, "nome": "...", "unidade": "...", "perfil": "...", "paginas": [], "cargo": "..." }
```

ou, em caso de falha:

```json
{ "ok": false, "erro": "Usuário ou senha incorretos." }
```
