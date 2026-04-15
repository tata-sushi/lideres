/**
 * Apps Script — Autenticação Hub de Líderes TATÁ Sushi
 * ────────────────────────────────────────────────────
 * Planilha de usuários (colunas esperadas):
 *   A: Usuário       (nome de exibição / login)
 *   B: Unidade       (Pinheiros, Itaim, ...)
 *   C: Perfil        (lider, administrativo, ...)
 *   D: Páginas       (lista separada por vírgula, opcional)
 *   E: Ativo         ("s" / "n")
 *   F: Senha         (texto simples)
 *   G: Cargo         (Gerente de Restaurante, Líder de Sushi, ...)
 *
 * Endpoints (GET):
 *   ?action=listUsers
 *     → { ok:true, usuarios:[{nome, unidade, perfil, cargo}, ...] }
 *
 *   ?action=auth&usuario=<nome>&senha=<senha>
 *     → { ok:true, nome, unidade, perfil, paginas:[], cargo }
 *     → { ok:false, erro:"..." }
 *
 * Deploy:
 *   1. Abra a planilha → Extensões → Apps Script
 *   2. Cole este arquivo como Code.gs
 *   3. Implantar → Nova implantação → Tipo: Aplicativo da Web
 *      - Executar como: Eu
 *      - Quem tem acesso: Qualquer pessoa
 *   4. Copie a URL e atualize AUTH_URL no index.html
 */

// ═══════════════════════════════════════════════
// CONFIGURAÇÃO
// ═══════════════════════════════════════════════

// Nome da aba da planilha com os usuários
var SHEET_NAME = 'Usuários';

// Índice das colunas (base 0)
var COL = {
  USUARIO: 0,
  UNIDADE: 1,
  PERFIL:  2,
  PAGINAS: 3,
  ATIVO:   4,
  SENHA:   5,
  CARGO:   6
};

// ═══════════════════════════════════════════════
// ROTEADOR PRINCIPAL
// ═══════════════════════════════════════════════

function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) || '';
  try {
    if (action === 'listUsers') return _json(listUsers());
    if (action === 'auth')      return _json(auth(e.parameter));
    return _json({ ok: false, erro: 'Ação desconhecida: ' + action });
  } catch (err) {
    return _json({ ok: false, erro: 'Erro interno: ' + err.message });
  }
}

// Permite preflight e POST caso algum dia seja necessário
function doPost(e) {
  return doGet(e);
}

// ═══════════════════════════════════════════════
// AÇÕES
// ═══════════════════════════════════════════════

/**
 * Lista todos os usuários ativos (sem devolver senha).
 */
function listUsers() {
  var rows = _getRows();
  var usuarios = [];
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    if (!_isAtivo(r[COL.ATIVO])) continue;
    var nome = String(r[COL.USUARIO] || '').trim();
    if (!nome) continue;
    usuarios.push({
      nome:    nome,
      unidade: String(r[COL.UNIDADE] || '').trim(),
      perfil:  String(r[COL.PERFIL]  || '').trim(),
      cargo:   String(r[COL.CARGO]   || '').trim()
    });
  }
  // ordena alfabeticamente
  usuarios.sort(function (a, b) { return a.nome.localeCompare(b.nome, 'pt-BR'); });
  return { ok: true, usuarios: usuarios };
}

/**
 * Autentica um usuário por nome + senha.
 */
function auth(params) {
  var usuario = String((params && params.usuario) || '').trim();
  var senha   = String((params && params.senha)   || '').trim();

  if (!usuario || !senha) {
    return { ok: false, erro: 'Usuário e senha são obrigatórios.' };
  }

  var rows = _getRows();
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    var nomeLinha  = String(r[COL.USUARIO] || '').trim();
    var senhaLinha = String(r[COL.SENHA]   || '').trim();
    if (!nomeLinha) continue;
    if (!_isAtivo(r[COL.ATIVO])) continue;

    if (_normalizar(nomeLinha) === _normalizar(usuario) && senhaLinha === senha) {
      return {
        ok:      true,
        nome:    nomeLinha,
        unidade: String(r[COL.UNIDADE] || '').trim(),
        perfil:  String(r[COL.PERFIL]  || '').trim(),
        paginas: _parsePaginas(r[COL.PAGINAS]),
        cargo:   String(r[COL.CARGO]   || '').trim()
      };
    }
  }
  return { ok: false, erro: 'Usuário ou senha incorretos.' };
}

// ═══════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════

function _getRows() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME) || ss.getSheets()[0];
  var data  = sheet.getDataRange().getValues();
  // pula o cabeçalho (linha 1)
  return data.slice(1);
}

function _isAtivo(v) {
  var s = String(v || '').trim().toLowerCase();
  return s === 's' || s === 'sim' || s === 'true' || s === '1' || s === 'y' || s === 'yes';
}

function _parsePaginas(v) {
  var s = String(v || '').trim();
  if (!s) return [];
  return s.split(/[,;]/).map(function (p) { return p.trim(); }).filter(Boolean);
}

// remove acentos, espaços extras e normaliza pra comparação case-insensitive
function _normalizar(s) {
  return String(s || '')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .trim().toLowerCase().replace(/\s+/g, ' ');
}

function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
