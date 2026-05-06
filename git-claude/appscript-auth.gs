// ══════════════════════════════════════════════════════════════════════════
//   APPS SCRIPT — Auth (Mapa de Liderança)
// ══════════════════════════════════════════════════════════════════════════
//
//   Lê a aba do Mapa de Liderança e expõe dois endpoints:
//     ?action=auth&usuario=<nome>&senha=<senha>
//        → autentica e devolve todos os campos do líder
//     ?action=listUsers
//        → devolve lista de nomes dos usuários ATIVOS (para o dropdown)
//
//   Colunas da aba (linha 1 = cabeçalho, dados a partir da linha 2):
//     A=Usuário | B=Unidade | C=Perfil | D=Páginas | E=Ativo
//     F=Senha   | G=Cargo   | H=Departamento | I=Variações | J=Departamentos
//
//   Campos devolvidos pelo ?action=auth (quando ok: true):
//     nome, unidade, perfil, cargo, departamento,
//     variacoes (string), departamentos (array), paginas (array)
//
//   Deploy:
//     1. script.google.com → abrir o projeto do auth
//     2. Substituir o conteúdo de Code.gs por este arquivo
//     3. Implantar → Gerenciar implantações → ✏️ Editar
//        → Versão: Nova versão → Implantar  (a URL não muda)
//
// ══════════════════════════════════════════════════════════════════════════

// ── Configuração ──────────────────────────────────────────────────────────
var MAPA_SHEET_ID = 'SEU_SHEET_ID_AQUI';  // ← ID da planilha Mapa de Liderança
var MAPA_ABA      = 'Mapa de Liderança';  // ← nome da aba (tab)

// Índices das colunas (base 0)
var COL_USUARIO      = 0;  // A
var COL_UNIDADE      = 1;  // B
var COL_PERFIL       = 2;  // C
var COL_PAGINAS      = 3;  // D
var COL_ATIVO        = 4;  // E
var COL_SENHA        = 5;  // F
var COL_CARGO        = 6;  // G
var COL_DEPARTAMENTO = 7;  // H
var COL_VARIACOES    = 8;  // I
var COL_DEPARTAMENTOS= 9;  // J

// ── Entrada principal ─────────────────────────────────────────────────────
function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) || '';
  var result;

  if (action === 'auth') {
    var usuario = (e.parameter.usuario || '').trim();
    var senha   = (e.parameter.senha   || '').trim();
    result = autenticar(usuario, senha);

  } else if (action === 'listUsers') {
    result = listarUsuarios();

  } else {
    result = { ok: false, erro: 'Ação desconhecida: ' + action };
  }

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── Autentica usuário e devolve todos os campos ───────────────────────────
function autenticar(usuario, senha) {
  try {
    var ss    = SpreadsheetApp.openById(MAPA_SHEET_ID);
    var sheet = ss.getSheetByName(MAPA_ABA);
    if (!sheet) return { ok: false, erro: 'Aba "' + MAPA_ABA + '" não encontrada.' };

    var dados = sheet.getDataRange().getValues();

    for (var i = 1; i < dados.length; i++) {
      var row = dados[i];

      var nome         = String(row[COL_USUARIO]       || '').trim();
      var unidade      = String(row[COL_UNIDADE]        || '').trim();
      var perfil       = String(row[COL_PERFIL]         || '').trim();
      var paginasRaw   = String(row[COL_PAGINAS]        || '').trim();
      var ativo        = String(row[COL_ATIVO]          || '').trim().toLowerCase();
      var senhaCad     = String(row[COL_SENHA]          || '').trim();
      var cargo        = String(row[COL_CARGO]          || '').trim();
      var departamento = String(row[COL_DEPARTAMENTO]   || '').trim();
      var variacoes    = String(row[COL_VARIACOES]      || '').trim();
      var deptosRaw    = String(row[COL_DEPARTAMENTOS]  || '').trim();

      if (ativo !== 's') continue;
      if (!nome) continue;

      if (_norm(nome) === _norm(usuario) && senhaCad === senha) {
        var paginas      = paginasRaw ? paginasRaw.split(',').map(function(p){ return p.trim(); }).filter(Boolean) : [];
        var departamentos= deptosRaw  ? deptosRaw.split(',').map(function(d){ return d.trim(); }).filter(Boolean) : [];

        return {
          ok:            true,
          nome:          nome,
          unidade:       unidade,
          perfil:        perfil,
          cargo:         cargo,
          departamento:  departamento,
          variacoes:     variacoes,
          departamentos: departamentos,
          paginas:       paginas
        };
      }
    }

    return { ok: false, erro: 'Usuário ou senha incorretos.' };

  } catch (err) {
    return { ok: false, erro: err.toString() };
  }
}

// ── Lista nomes dos usuários ATIVOS (para o dropdown de login) ────────────
function listarUsuarios() {
  try {
    var ss    = SpreadsheetApp.openById(MAPA_SHEET_ID);
    var sheet = ss.getSheetByName(MAPA_ABA);
    if (!sheet) return { ok: false, erro: 'Aba "' + MAPA_ABA + '" não encontrada.' };

    var dados    = sheet.getDataRange().getValues();
    var usuarios = [];

    for (var i = 1; i < dados.length; i++) {
      var nome  = String(dados[i][COL_USUARIO] || '').trim();
      var ativo = String(dados[i][COL_ATIVO]   || '').trim().toLowerCase();
      if (nome && ativo === 's') usuarios.push(nome);
    }

    return { ok: true, usuarios: usuarios };

  } catch (err) {
    return { ok: false, erro: err.toString() };
  }
}

// ── Remove acentos + lowercase para comparação insensível ────────────────
function _norm(s) {
  return String(s || '')
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .trim().toLowerCase();
}
