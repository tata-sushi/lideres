// ──────────────────────────────────────────────
//  ⚙️  CONFIGURAÇÕES — preencha aqui
// ──────────────────────────────────────────────
var CONFIG = {
  BASE_URL    : "https://rhid.com.br/v2/api.svc",
  BASE_URL_DB : "https://rhid.com.br/v2/customerdb",
  EMAIL       : "victor.carvalho@tatasushi.com.br",
  PASSWORD    : "Tata@123",
  DOMAIN      : "",
  PAGE_SIZE   : 100
};

// ──────────────────────────────────────────────
//  MAPA DE CENTROS DE CUSTO (id → nome)
// ──────────────────────────────────────────────
var CENTROS_DE_CUSTO = {
  "2": "Itaim",
  "5": "Tatá House",
  "6": "Administrativo",
  "7": "Pinheiros",
  "8": "Poke - Pinheiros"
};

// ──────────────────────────────────────────────
//  IDs DE PESSOA PARA FORÇAR STATUS "BLOQUEADO"
// ──────────────────────────────────────────────
var IDS_FORCAR_BLOQUEADO = {
  "319": true,
  "71" : true
};

// ──────────────────────────────────────────────
//  PESSOAS FIXAS — sempre incluídas (sócios fora do ponto)
// ──────────────────────────────────────────────
var PESSOAS_FIXAS = [
  {
    name          : "Luiz Claudio Mori",
    registration  : "9",
    cargo         : "Diretor de Operações",
    status        : 1,
    _idCostCenter : "6",
    departmentName: "Operações",
    idDepartment  : "16",
    admissionDate : "01/08/2016",
    idPersonBoss  : "",
    idPersonRH    : "",
    nomeSuperior  : "",
    birthDate     : "10/05/1974",
    dismissalDate : ""
  },
  {
    name          : "Leo Partel Young",
    registration  : "10",
    cargo         : "Diretor de Marketing",
    status        : 1,
    _idCostCenter : "6",
    departmentName: "Operações",
    idDepartment  : "16",
    admissionDate : "01/08/2016",
    idPersonBoss  : "",
    idPersonRH    : "",
    nomeSuperior  : "",
    birthDate     : "",
    dismissalDate : ""
  }
];

// ──────────────────────────────────────────────
//  FUNÇÃO PRINCIPAL
// ──────────────────────────────────────────────
function sincronizarColaboradores() {
  try {
    var token = login();
    if (!token) throw new Error("Falha na autenticação. Verifique e-mail, senha e domínio.");

    var pessoas = buscarTodasAsPessoas(token);
    pessoas = enriquecerComAdmissao(pessoas, token);

    var mapaDepts      = buscarMapaDepartamentos(token, pessoas);
    var mapaSuperiores = resolverNomesSuperiores(pessoas, token);

    pessoas.forEach(function(p) {
      p.departmentName = mapaDepts[String(p.idDepartment)] || "";
      p.unidade        = (p._idCostCenter !== null && p._idCostCenter !== undefined)
                       ? String(p._idCostCenter) : "";
      p.nomeSuperior   = mapaSuperiores[String(p.idPersonBoss)] || "";
    });

    // Injeta pessoas fixas no início da lista
    pessoas = PESSOAS_FIXAS.concat(pessoas);

    var total          = gravarNaPlanilha(pessoas);
    var totalAdmissoes = atualizarAbaAdmissoes(pessoas);

    Logger.log("✅ Sincronização concluída! Colaboradores: " + total + " | Admissões novas: " + totalAdmissoes);

  } catch (e) {
    Logger.log("❌ Erro: " + e.message);
    throw e;
  }
}

// ──────────────────────────────────────────────
//  AUTENTICAÇÃO
// ──────────────────────────────────────────────
function login() {
  var url     = CONFIG.BASE_URL + "/login";
  var payload = { email: CONFIG.EMAIL, password: CONFIG.PASSWORD };
  if (CONFIG.DOMAIN) payload.domain = CONFIG.DOMAIN;

  var response = UrlFetchApp.fetch(url, {
    method     : "post",
    contentType: "application/json",
    payload    : JSON.stringify(payload),
    muteHttpExceptions: true
  });

  var code = response.getResponseCode();
  var body = JSON.parse(response.getContentText());

  if (code !== 200 || !body.accessToken) {
    Logger.log("Login falhou. Código: " + code + " | Resposta: " + JSON.stringify(body));
    return null;
  }

  Logger.log("Login OK.");
  return body.accessToken;
}

// ──────────────────────────────────────────────
//  BUSCA PAGINADA DE PESSOAS
// ──────────────────────────────────────────────
function buscarTodasAsPessoas(token) {
  var todos = [];
  var start = 0;
  var total = null;

  do {
    var url = CONFIG.BASE_URL + "/person?start=" + start + "&length=" + CONFIG.PAGE_SIZE;

    var response = UrlFetchApp.fetch(url, {
      method : "get",
      headers: { "Authorization": "Bearer " + token },
      muteHttpExceptions: true
    });

    if (response.getResponseCode() !== 200) {
      throw new Error("Erro ao buscar pessoas. HTTP " + response.getResponseCode());
    }

    var body      = JSON.parse(response.getContentText());
    if (total === null) total = body.totalRecords || 0;

    var registros = body.records || [];
    todos = todos.concat(registros);

    Logger.log("Pessoas: start=" + start + " | obtidos=" + registros.length + " | total=" + total);
    start += CONFIG.PAGE_SIZE;

  } while (start < total);

  return todos;
}

// ──────────────────────────────────────────────
//  BUSCA DEPARTAMENTOS — retorna mapa id → nome
// ──────────────────────────────────────────────
function buscarMapaDepartamentos(token, pessoas) {
  var mapa = {};

  var idsUnicos = {};
  pessoas.forEach(function(p) {
    if (p.idDepartment) idsUnicos[String(p.idDepartment)] = true;
  });

  Object.keys(idsUnicos).forEach(function(id) {
    try {
      var response = UrlFetchApp.fetch(CONFIG.BASE_URL + "/department/" + id, {
        method : "get",
        headers: { "Authorization": "Bearer " + token },
        muteHttpExceptions: true
      });
      if (response.getResponseCode() === 200) {
        var dept = JSON.parse(response.getContentText());
        mapa[id] = dept.name || "";
        Logger.log("Dept id=" + id + " → " + mapa[id]);
      }
    } catch(e) {
      Logger.log("Erro dept id=" + id + ": " + e.message);
    }
  });

  return mapa;
}

// ──────────────────────────────────────────────
//  RESOLVE NOMES DOS SUPERIORES
// ──────────────────────────────────────────────
function resolverNomesSuperiores(pessoas, token) {
  var mapa = {};

  var idsUnicos = {};
  pessoas.forEach(function(p) {
    var boss = p.idPersonBoss;
    if (boss && boss !== 0) idsUnicos[String(boss)] = true;
  });

  var ids = Object.keys(idsUnicos);
  Logger.log("IDs únicos de superior (idPersonBoss): " + ids.join(", "));

  ids.forEach(function(id) {
    try {
      var response = UrlFetchApp.fetch(CONFIG.BASE_URL + "/person/" + id, {
        method : "get",
        headers: { "Authorization": "Bearer " + token },
        muteHttpExceptions: true
      });
      if (response.getResponseCode() === 200) {
        var person = JSON.parse(response.getContentText());
        mapa[id]   = toTitleCase(person.name || "");
        Logger.log("Superior id=" + id + " → " + mapa[id]);
      } else {
        Logger.log("Superior id=" + id + " → HTTP " + response.getResponseCode());
      }
    } catch(e) {
      Logger.log("Erro superior id=" + id + ": " + e.message);
    }
  });

  Logger.log("Mapa de superiores: " + Object.keys(mapa).length + " registros.");
  return mapa;
}

// ──────────────────────────────────────────────
//  ENRIQUECE PESSOAS
// ──────────────────────────────────────────────
function enriquecerComAdmissao(pessoas, token) {
  Logger.log("Enriquecendo " + pessoas.length + " pessoas...");

  for (var i = 0; i < pessoas.length; i++) {
    var p   = pessoas[i];
    var url = CONFIG.BASE_URL_DB + "/personrolehistory.svc/by_person/" + p.id;

    try {
      var response = UrlFetchApp.fetch(url, {
        method : "get",
        headers: { "Authorization": "Bearer " + token },
        muteHttpExceptions: true
      });

      if (response.getResponseCode() === 200) {
        var data      = JSON.parse(response.getContentText());
        var registros = Array.isArray(data) ? data : [data];
        var registro  = registros[registros.length - 1];

        if (registro && registro.person) {
          var person = registro.person;

          p.cargo          = registro.personRoleName
                          || (registro.personRole && registro.personRole.name)
                          || "";
          p.startStr       = registro.startStr || "";
          p.admissionDate  = parseMicrosoftDate(person.admissionDate)
                          || parseStartStr(registro.startStr)
                          || "";
          p.departmentName = person.departmentName || "";
          p._idCostCenter  = (person.idCostCenter !== null && person.idCostCenter !== undefined)
                          ? person.idCostCenter : null;
          p.costCenterName = person.costCenterName || "";
          p.unidade        = person.costCenterName || "";
          p.excluded       = person.excluded === true ? "Sim" : "Não";
          p.idPersonRH     = person.id || p.id || "";
          p.idPersonBoss   = person.idPersonBoss || registro.idPersonBoss || null;
          p.birthDate      = parseMicrosoftDate(person.dateOfBirth)   || "";
          p.dismissalDate  = parseMicrosoftDate(person.dismissalDate) || "";

        } else {
          p.cargo = ""; p.startStr = ""; p.admissionDate = "";
          p.departmentName = ""; p.unidade = ""; p._idCostCenter = null;
          p.costCenterName = ""; p.excluded = "Não";
          p.idPersonRH = p.id || ""; p.idPersonBoss = null;
          p.birthDate = ""; p.dismissalDate = "";
        }
      } else {
        p.cargo = ""; p.startStr = ""; p.admissionDate = "";
        p.departmentName = ""; p.unidade = ""; p._idCostCenter = null;
        p.costCenterName = ""; p.excluded = "Não";
        p.idPersonRH = p.id || ""; p.idPersonBoss = null;
        p.birthDate = ""; p.dismissalDate = "";
      }

    } catch (e) {
      Logger.log("Erro id=" + p.id + ": " + e.message);
      p.cargo = ""; p.startStr = ""; p.admissionDate = "";
      p.unidade = ""; p.departmentName = ""; p._idCostCenter = null;
      p.costCenterName = ""; p.excluded = "Não";
      p.idPersonRH = p.id || ""; p.idPersonBoss = null;
      p.birthDate = ""; p.dismissalDate = "";
    }

    if (i > 0 && i % 20 === 0) Utilities.sleep(500);
  }

  return pessoas;
}

// ──────────────────────────────────────────────
//  TITLE CASE — compatível com acentos portugueses
// ──────────────────────────────────────────────
function toTitleCase(str) {
  if (!str) return "";
  return str.replace(/\S+/g, function(word) {
    return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
  });
}

// ──────────────────────────────────────────────
//  PARSERS DE DATA
// ──────────────────────────────────────────────
function parseStartStr(startStr) {
  if (!startStr || startStr.length < 8) return "";
  try {
    return startStr.substring(6, 8) + "/" + startStr.substring(4, 6) + "/" + startStr.substring(0, 4);
  } catch(e) { return ""; }
}

function parseDateBR(dateStr) {
  if (!dateStr || dateStr.length < 10) return null;
  try {
    var p = dateStr.split("/");
    if (p.length !== 3) return null;
    var d = new Date(parseInt(p[2]), parseInt(p[1]) - 1, parseInt(p[0]));
    d.setHours(0, 0, 0, 0);
    return d;
  } catch (e) { return null; }
}

function parseMicrosoftDate(dateStr) {
  if (!dateStr) return "";
  try {
    var match = dateStr.match(/\/Date\((-?\d+)([+-]\d+)?\)\//);
    if (!match) return "";
    var date = new Date(parseInt(match[1], 10));
    return String(date.getUTCDate()).padStart(2, "0") + "/" +
           String(date.getUTCMonth() + 1).padStart(2, "0") + "/" +
           date.getUTCFullYear();
  } catch (e) {
    Logger.log("Erro ao parsear data: " + dateStr + " | " + e.message);
    return "";
  }
}

// ──────────────────────────────────────────────
//  GRAVAR NA PLANILHA
//
//  A  Nome                 J  — (separador)
//  B  Matrícula            K  ID Superior
//  C  Cargo                L  ID Pessoa
//  D  Status               M  Nome do Superior
//  E  Unidade              N  Data de Nascimento
//  F  Departamento         O  Data de Demissão
//  G  ID Centro de Custo
//  H  ID Departamento
//  I  Data de Admissão
// ──────────────────────────────────────────────
function gravarNaPlanilha(pessoas) {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName("Colaboradores");
  if (!sheet) sheet = ss.insertSheet("Colaboradores");
  sheet.clearContents();

  var headers = [
    "Nome", "Matrícula", "Cargo", "Status", "Unidade",
    "Departamento", "ID Centro de Custo", "ID Departamento",
    "Data de Admissão",
    "",
    "ID Superior", "ID Pessoa", "Nome do Superior",
    "Data de Nascimento", "Data de Demissão"
  ];

  sheet.appendRow(headers);

  sheet.getRange(1, 1, 1, 9)
    .setBackground("#1a73e8").setFontColor("#ffffff")
    .setFontWeight("bold").setHorizontalAlignment("center");

  sheet.getRange(1, 11, 1, 3)
    .setBackground("#0d47a1").setFontColor("#ffffff")
    .setFontWeight("bold").setHorizontalAlignment("center");

  sheet.getRange(1, 14, 1, 2)
    .setBackground("#37474f").setFontColor("#ffffff")
    .setFontWeight("bold").setHorizontalAlignment("center");

  sheet.setFrozenRows(1);

  if (pessoas.length === 0) return 0;

  var linhas = pessoas.map(function(p) {
    var idCC    = (p._idCostCenter !== null && p._idCostCenter !== undefined) ? String(p._idCostCenter) : "";
    var unidade = CENTROS_DE_CUSTO[idCC] || idCC;

    return [
      toTitleCase(p.name)                      || "",  // A
      p.registration                            || "",  // B
      toTitleCase(p.cargo)                      || "",  // C
      traduzirStatus(p.status, p.idPersonRH),           // D
      unidade,                                          // E
      toTitleCase(p.departmentName)             || "",  // F
      idCC,                                             // G
      p.idDepartment                            || "",  // H
      p.admissionDate                           || "",  // I
      "",                                               // J separador
      p.idPersonBoss                            || "",  // K
      p.idPersonRH                              || "",  // L
      p.nomeSuperior                            || "",  // M
      p.birthDate                               || "",  // N
      p.dismissalDate                           || ""   // O
    ];
  });

  sheet.getRange(2, 1, linhas.length, headers.length).setValues(linhas);

  for (var i = 0; i < linhas.length; i++) {
    sheet.getRange(i + 2, 1, 1, headers.length)
      .setBackground(i % 2 === 0 ? "#f8f9fa" : "#ffffff");
  }

  sheet.getRange(2, 7, linhas.length, 2).setFontWeight("bold");
  sheet.getRange(2, 11, linhas.length, 3).setFontWeight("bold");
  sheet.autoResizeColumns(1, headers.length);

  return linhas.length;
}

// ──────────────────────────────────────────────
//  TRADUZ STATUS
// ──────────────────────────────────────────────
function traduzirStatus(status, idPessoa) {
  if (idPessoa && IDS_FORCAR_BLOQUEADO[String(idPessoa)]) return "Bloqueado";
  switch (status) {
    case 0:  return "Inativo";
    case 1:  return "Ativo";
    case 2:  return "Bloqueado";
    default: return status !== undefined ? String(status) : "—";
  }
}

// ──────────────────────────────────────────────
//  ABA "admissões" — SOMENTE INCLUSÃO DE NOVOS
// ──────────────────────────────────────────────
function atualizarAbaAdmissoes(pessoas) {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName("admissões");

  if (!sheet) {
    sheet = ss.insertSheet("admissões");
    var h = ["MT", "UNIDADE", "DEPARTAMENTO", "NOME_COLABORADOR", "DATA_ADMISSAO"];
    sheet.appendRow(h);
    sheet.getRange(1, 1, 1, h.length)
      .setBackground("#1a73e8").setFontColor("#ffffff")
      .setFontWeight("bold").setHorizontalAlignment("center");
    sheet.setFrozenRows(1);
  }

  var ultimaLinha   = sheet.getLastRow();
  var mtsExistentes = {};

  if (ultimaLinha >= 2) {
    sheet.getRange(2, 1, ultimaLinha - 1, 1).getValues().forEach(function(row) {
      var mt = String(row[0]).trim();
      if (mt) mtsExistentes[mt] = true;
    });
  }

  var hoje = new Date();
  hoje.setHours(0, 0, 0, 0);

  var novos = pessoas.filter(function(p) {
    if (p.status !== 0) return false;
    var mt = String(p.registration || "").trim();
    if (!mt || mtsExistentes[mt]) return false;
    var d = parseDateBR(p.admissionDate);
    return d && d >= hoje;
  });

  if (novos.length === 0) { Logger.log("Nenhum novo para 'admissões'."); return 0; }

  novos.sort(function(a, b) { return (a.name || "").localeCompare(b.name || "", "pt-BR"); });

  var linhas = novos.map(function(p) {
    return [
      String(p.registration         || ""),
      toTitleCase(p.unidade)        || "",
      toTitleCase(p.departmentName) || "",
      toTitleCase(p.name)           || "",
      p.admissionDate               || ""
    ];
  });

  var primeira = sheet.getLastRow() + 1;
  sheet.getRange(primeira, 1, linhas.length, 5).setValues(linhas);

  for (var i = 0; i < linhas.length; i++) {
    sheet.getRange(primeira + i, 1, 1, 5)
      .setBackground((primeira + i) % 2 === 0 ? "#f8f9fa" : "#ffffff");
  }

  sheet.autoResizeColumns(1, 5);
  Logger.log("Aba 'admissões': " + linhas.length + " novos incluídos.");
  return linhas.length;
}
