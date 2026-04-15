// ══════════════════════════════════════════════════════════════════════════
//   APPS SCRIPT — Mapa de Liderança (autenticação + permissões do portal)
// ══════════════════════════════════════════════════════════════════════════
//
//   Planilha: https://docs.google.com/spreadsheets/d/14UsviSQbpJBPUNW1cuvCDnem7IRknSHBcxZg6jnq7pk
//
//   Endpoints expostos via doGet:
//     ?action=auth&usuario=<nome>&senha=<senha>  → autentica e retorna perfil + páginas + cargo
//     ?action=listUsers                          → lista líderes ativos (popula dropdown)
//
//   Deploy atual (mantenha o mesmo URL ao publicar nova versão):
//     https://script.google.com/macros/s/AKfycbykOWkQ3ceH_50bmc_3dcLjUrE9V4Ropbraxc0yykMIp6W8eDVtpyo2XmN1Y_KJQzol/exec
//
//   Colunas da aba "Mapa de Liderança":
//     A=Usuário | B=Unidade | C=Perfil | D=Páginas(override) | E=Ativo | F=Senha | G=Cargo
//
// ══════════════════════════════════════════════════════════════════════════

var SHEET_ID  = '14UsviSQbpJBPUNW1cuvCDnem7IRknSHBcxZg6jnq7pk';
var ABA_MAPA  = 'Mapa de Liderança';
var ABA_PAGES = 'Páginas';

// ── Entrada principal ──────────────────────────────────────────
function doGet(e) {
  var action = e && e.parameter && e.parameter.action ? e.parameter.action : '';

  var result;

  if (action === 'auth') {
    var usuario = e.parameter.usuario || '';
    var senha   = e.parameter.senha   || '';
    result = autenticar(usuario, senha);
  } else if (action === 'listUsers') {
    result = listarUsuarios();
  } else {
    result = { erro: 'Ação desconhecida: ' + action };
  }

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── Autentica e retorna páginas do perfil ─────────────────────
function autenticar(usuario, senha) {
  try {
    var ss = SpreadsheetApp.openById(SHEET_ID);

    // 1. Lê aba Mapa de Liderança
    var sheetMapa = ss.getSheetByName(ABA_MAPA);
    if (!sheetMapa) return { ok: false, erro: 'Aba "' + ABA_MAPA + '" não encontrada.' };

    var dadosMapa = sheetMapa.getDataRange().getValues();
    // Colunas: A=Usuário, B=Unidade, C=Perfil, D=Páginas(override), E=Ativo, F=Senha, G=Cargo

    var usuarioEncontrado = null;

    for (var i = 1; i < dadosMapa.length; i++) {
      var row     = dadosMapa[i];
      var nomeRow = String(row[0] || '').trim();
      if (!nomeRow) continue;

      if (nomeRow.toLowerCase() !== usuario.toLowerCase()) continue;

      // Usuário encontrado — verifica ativo
      var ativo = String(row[4] || '').trim().toLowerCase();
      if (ativo === 'n' || ativo === 'não' || ativo === 'nao' || ativo === 'false') {
        return { ok: false, erro: 'Usuário inativo.' };
      }

      // Verifica senha (coluna F)
      var senhaRow = String(row[5] || '').trim();
      if (senhaRow !== String(senha).trim()) {
        return { ok: false, erro: 'Senha incorreta.' };
      }

      // Autenticado — monta dados do usuário
      usuarioEncontrado = {
        nome:           nomeRow,
        unidade:        String(row[1] || '').trim(),
        perfil:         String(row[2] || '').trim().toLowerCase(),
        paginasOverride: String(row[3] || '').trim(), // coluna D — exceção individual
        cargo:          String(row[6] || '').trim()   // coluna G — cargo do líder
      };
      break;
    }

    if (!usuarioEncontrado) {
      return { ok: false, erro: 'Usuário não encontrado.' };
    }

    // 2. Lê aba Páginas
    var sheetPages = ss.getSheetByName(ABA_PAGES);
    if (!sheetPages) return { ok: false, erro: 'Aba "' + ABA_PAGES + '" não encontrada.' };

    var dadosPages = sheetPages.getDataRange().getValues();
    // Colunas: A=ID, B=Nome, C=URL, D=Perfis (separados por vírgula)

    var perfil  = usuarioEncontrado.perfil;
    var paginas = [];

    // admin vê tudo
    if (perfil === 'admin') {
      for (var j = 1; j < dadosPages.length; j++) {
        var pg = dadosPages[j];
        var id  = String(pg[0] || '').trim();
        if (!id) continue;
        paginas.push({
          id:   id,
          nome: String(pg[1] || '').trim(),
          url:  String(pg[2] || '').trim()
        });
      }
    } else {
      // Filtra por perfil
      for (var j = 1; j < dadosPages.length; j++) {
        var pg      = dadosPages[j];
        var id      = String(pg[0] || '').trim();
        if (!id) continue;
        var perfisCell = String(pg[3] || '').trim().toLowerCase();
        var perfisArr  = perfisCell.split(',').map(function(p){ return p.trim(); });

        // Página visível se perfil está na lista OU célula é '*'
        if (perfisCell === '*' || perfisArr.indexOf(perfil) !== -1) {
          paginas.push({
            id:   id,
            nome: String(pg[1] || '').trim(),
            url:  String(pg[2] || '').trim()
          });
        }
      }
    }

    return {
      ok:      true,
      nome:    usuarioEncontrado.nome,
      unidade: usuarioEncontrado.unidade,
      perfil:  perfil,
      cargo:   usuarioEncontrado.cargo,
      paginas: paginas  // array de { id, nome, url }
    };

  } catch (err) {
    return { ok: false, erro: err.toString() };
  }
}

// ── Lista líderes ativos (popula o dropdown do login) ──────────
function listarUsuarios() {
  try {
    var ss = SpreadsheetApp.openById(SHEET_ID);
    var sheet = ss.getSheetByName(ABA_MAPA);
    if (!sheet) return { ok: false, erro: 'Aba "' + ABA_MAPA + '" não encontrada.' };

    var dados = sheet.getDataRange().getValues();
    var usuarios = [];

    for (var i = 1; i < dados.length; i++) {
      var row  = dados[i];
      var nome = String(row[0] || '').trim();
      if (!nome) continue;

      var ativo = String(row[4] || '').trim().toLowerCase();
      if (ativo === 'n' || ativo === 'não' || ativo === 'nao' || ativo === 'false') continue;

      usuarios.push(nome);
    }

    usuarios.sort(function(a, b) { return a.localeCompare(b, 'pt-BR'); });
    return { ok: true, usuarios: usuarios };
  } catch (err) {
    return { ok: false, erro: err.toString() };
  }
}
