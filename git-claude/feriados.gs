// ============================================================
//  RHiD — Relatório de Horas em Feriados
//  Automático — detecta feriados da semana passada
//  + Saldo do banco de horas no dia anterior ao feriado
// ============================================================
//
//  Web App (doGet) — consumido por feriados.html:
//    Deploy: (preencher após publicar como Web App)
//    Planilha: https://docs.google.com/spreadsheets/d/1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw
//
//  Aba "Feriados" — layout esperado:
//    Row 1   : cabeçalho (A=Data, B=Feriado, C=Colaborador, D=Matrícula,
//               E=Horas, F=Unidade, G=Departamento, H=Saldo Dia Anterior,
//               I=Devolutiva, J=Líder)
//    Row 2+  : dados
// ============================================================

const CONFIG_FER = {
  BASE_URL    : "https://rhid.com.br/v2/api.svc",
  BASE_URL_DB : "https://rhid.com.br/v2/customerdb",
  EMAIL       : "victor.carvalho@tatasushi.com.br",
  PASSWORD    : "Tata@123",
  PAGE_SIZE   : 100,
  SHEET_ID    : "1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw"
};

const CENTROS_FER = {
  "2": "Itaim",
  "5": "Tatá House",
  "6": "Administrativo",
  "7": "Pinheiros",
  "8": "Poke - Pinheiros"
};

const NOMES_EXCLUIR_FER      = ["ID2ID", "CLOUD", "id2"];
const MATRICULAS_EXCLUIR_FER = [
  "0", "1", "2", "3", "4", "5", "7", "8",
  "24077", "24090", "24092", "24164", "24174", "24194", "24600"
];

// ──────────────────────────────────────────────
//  FUNÇÃO PRINCIPAL
// ──────────────────────────────────────────────
function relatórioFeriados() {
  const { dataIni, dataFim } = fer_getPeriodo();
  Logger.log("Período: " + dataIni + " → " + dataFim);

  const token = fer_login();
  if (!token) { Logger.log("Falha no login"); return; }

  const pessoas     = fer_getAllPersons(token);
  const mapaDepts   = fer_buscarDepartamentos(token, pessoas);
  const pessoasRich = fer_enriquecerPessoas(pessoas, token, mapaDepts);

  const ativos = pessoasRich.filter(function(p) {
    const mt = String(p.registration || "").trim();
    if (p.status !== 1) return false;
    if (NOMES_EXCLUIR_FER.some(function(n) {
      return (p.name || "").toUpperCase().includes(n.toUpperCase());
    })) return false;
    if (MATRICULAS_EXCLUIR_FER.includes(mt)) return false;
    return true;
  });

  Logger.log("Ativos filtrados: " + ativos.length);

  const feriadosDoPeriodo = fer_detectarFeriados(token, ativos[0].id, dataIni, dataFim);

  if (feriadosDoPeriodo.length === 0) {
    Logger.log("Nenhum feriado encontrado no período.");
    fer_gravarResultado([], dataIni, dataFim);
    return;
  }

  Logger.log("Feriados: " + feriadosDoPeriodo.map(function(f) {
    return f.data + " (" + f.nome + ")";
  }).join(", "));

  const linhas = [];

  feriadosDoPeriodo.forEach(function(feriado) {
    Logger.log("Buscando quem trabalhou em: " + feriado.data + " — " + feriado.nome);

    const diaAnterior = fer_getDiaAnterior(feriado.data);

    for (let i = 0; i < ativos.length; i++) {
      const p  = ativos[i];
      const mt = String(p.registration || "");

      const dias = fer_getApuracao(token, p.id, feriado.data, feriado.data);
      if (!dias || dias.length === 0) continue;

      const dia = dias[0];
      if (!dia.totalHorasTrabalhadas || dia.totalHorasTrabalhadas === 0) continue;

      const horasMin = dia.totalHorasTrabalhadas;
      const horas    = Math.floor(horasMin / 60);
      const min      = horasMin % 60;
      const horasFmt = horas + "h" + (min > 0 ? String(min).padStart(2, "0") + "m" : "");

      // Saldo do banco de horas no dia ANTERIOR ao feriado
      let saldoAnterior = "";
      try {
        const apuracaoAntes = fer_getApuracao(token, p.id, diaAnterior, diaAnterior);
        if (apuracaoAntes && apuracaoAntes.length > 0) {
          const saldoMin = Math.round(apuracaoAntes[0].saldoBancoFinalDia || 0);
          const sinal    = saldoMin < 0 ? "-" : "+";
          const abs      = Math.abs(saldoMin);
          saldoAnterior  = sinal + Math.floor(abs / 60) + "h" + String(abs % 60).padStart(2, "0") + "m";
        }
      } catch(e) {
        Logger.log("Erro saldo anterior id=" + p.id + ": " + e.message);
      }

      Logger.log("✓ " + fer_titleCase(p.name) + " | MT " + mt + " | " + horasFmt + " | saldo anterior: " + saldoAnterior);

      linhas.push([
        feriado.data.split("-").reverse().join("/"),
        feriado.nome,
        fer_titleCase(p.name || ""),
        mt,
        horasFmt,
        p.unidade        || "",
        p.departmentName || "",
        saldoAnterior
      ]);

      if ((i + 1) % 20 === 0) Utilities.sleep(500);
    }
  });

  Logger.log("Total de registros: " + linhas.length);
  fer_gravarResultado(linhas, dataIni, dataFim);
  Logger.log("✅ Concluído!");
}

// ──────────────────────────────────────────────
//  DETECTAR FERIADOS NO PERÍODO
// ──────────────────────────────────────────────
function fer_detectarFeriados(token, idPerson, dataIni, dataFim) {
  const feriados = [];
  const atual    = new Date(dataIni);
  const fim      = new Date(dataFim);

  while (atual <= fim) {
    const dia      = fer_formatData(new Date(atual));
    const apuracao = fer_getApuracao(token, idPerson, dia, dia);

    if (apuracao && apuracao.length > 0) {
      const reg = apuracao[0];
      if (reg.isHoliday === 1 && reg.holiday && reg.holiday.name) {
        feriados.push({ data: dia, nome: reg.holiday.name });
      }
    }

    atual.setDate(atual.getDate() + 1);
  }

  return feriados;
}

// ──────────────────────────────────────────────
//  SEMANA PASSADA (seg → dom)
// ──────────────────────────────────────────────
function fer_getPeriodo() {
  const hoje   = new Date();
  const diaSem = hoje.getDay();

  const diasAteSeg = diaSem === 0 ? 7 : diaSem;
  const seg = new Date(hoje);
  seg.setDate(hoje.getDate() - diasAteSeg - 6);

  const dom = new Date(seg);
  dom.setDate(seg.getDate() + 6);

  return { dataIni: fer_formatData(seg), dataFim: fer_formatData(dom) };
}

// ──────────────────────────────────────────────
//  DIA ANTERIOR
// ──────────────────────────────────────────────
function fer_getDiaAnterior(dataStr) {
  const d = new Date(dataStr);
  d.setDate(d.getDate() - 1);
  return fer_formatData(d);
}

function fer_formatData(d) {
  return d.getFullYear() + "-" +
    String(d.getMonth() + 1).padStart(2, "0") + "-" +
    String(d.getDate()).padStart(2, "0");
}

// ──────────────────────────────────────────────
//  GRAVAR NA PLANILHA
//  Layout: row 1 = cabeçalho, row 2+ = dados
//  Preserva devolutiva (col I) e líder (col J)
// ──────────────────────────────────────────────
function fer_gravarResultado(linhas, dataIni, dataFim) {
  const ss    = SpreadsheetApp.openById(CONFIG_FER.SHEET_ID);
  const sheet = ss.getSheetByName("Feriados") || ss.insertSheet("Feriados");

  // Preserva devolutivas já registradas (chave: colaborador|data)
  var devolutivaMap = {};
  try {
    var existing = sheet.getDataRange().getValues();
    for (var ei = 1; ei < existing.length; ei++) {
      var er = existing[ei];
      if (!er[2] || !er[0]) continue;
      var chave = String(er[2]).trim() + "|" + String(er[0]).trim();
      if (er[8]) devolutivaMap[chave] = { decisao: String(er[8]), lider: String(er[9] || "") };
    }
  } catch(e) {
    Logger.log("Aviso ao ler devolutivas: " + e.message);
  }

  sheet.clearContents();

  // Cabeçalho na linha 1 (inclui Devolutiva e Líder)
  const headers = ["Data", "Feriado", "Colaborador", "Matrícula", "Horas",
                   "Unidade", "Departamento", "Saldo Dia Anterior", "Devolutiva", "Líder"];
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  sheet.getRange(1, 1, 1, headers.length)
    .setBackground("#1a73e8").setFontColor("#ffffff")
    .setFontWeight("bold").setHorizontalAlignment("center");
  sheet.setFrozenRows(1);

  if (linhas.length === 0) {
    sheet.getRange("A2").setValue("Nenhum colaborador trabalhou em feriados no período.")
      .setFontColor("#888888").setFontStyle("italic");
    return;
  }

  linhas.sort(function(a, b) {
    if (a[0] !== b[0]) return a[0].localeCompare(b[0]);
    return a[2].localeCompare(b[2]);
  });

  // Dados colunas A-H (linhas 2+)
  sheet.getRange(2, 1, linhas.length, 8).setValues(linhas);

  // Formatação zebra
  for (let i = 0; i < linhas.length; i++) {
    sheet.getRange(i + 2, 1, 1, 8)
      .setBackground(i % 2 === 0 ? "#f8f9fa" : "#ffffff");
  }

  // Horas — azul
  sheet.getRange(2, 5, linhas.length, 1)
    .setFontWeight("bold").setFontColor("#1a73e8").setHorizontalAlignment("center");

  // Saldo — verde se positivo, vermelho se negativo
  for (let i = 0; i < linhas.length; i++) {
    const saldo = linhas[i][7] || "";
    sheet.getRange(i + 2, 8)
      .setFontWeight("bold")
      .setFontColor(saldo.charAt(0) === "-" ? "#d32f2f" : "#2e7d32")
      .setHorizontalAlignment("center");
  }

  // Restaura devolutivas nas novas linhas pelo mesmo colaborador+data
  for (let i = 0; i < linhas.length; i++) {
    var chave = String(linhas[i][2]).trim() + "|" + String(linhas[i][0]).trim();
    if (devolutivaMap[chave]) {
      sheet.getRange(i + 2, 9).setValue(devolutivaMap[chave].decisao);
      sheet.getRange(i + 2, 10).setValue(devolutivaMap[chave].lider);
    }
  }

  sheet.autoResizeColumns(1, headers.length);
}

// ──────────────────────────────────────────────
//  LOGIN
// ──────────────────────────────────────────────
function fer_login() {
  try {
    const resp = UrlFetchApp.fetch(CONFIG_FER.BASE_URL + "/login", {
      method: "POST", contentType: "application/json",
      payload: JSON.stringify({ email: CONFIG_FER.EMAIL, password: CONFIG_FER.PASSWORD }),
      muteHttpExceptions: true
    });
    return JSON.parse(resp.getContentText()).accessToken || null;
  } catch(e) { return null; }
}

// ──────────────────────────────────────────────
//  BUSCAR PESSOAS
// ──────────────────────────────────────────────
function fer_getAllPersons(token) {
  const pessoas = [];
  let start = 0;

  while (true) {
    const url  = CONFIG_FER.BASE_URL + "/person?start=" + start + "&length=" + CONFIG_FER.PAGE_SIZE;
    const resp = UrlFetchApp.fetch(url, {
      headers: { Authorization: "Bearer " + token }, muteHttpExceptions: true
    });
    if (resp.getResponseCode() !== 200) break;

    const data = JSON.parse(resp.getContentText());
    const arr  = data.records || [];
    if (arr.length === 0) break;

    arr.forEach(function(p) {
      pessoas.push({
        id           : p.id,
        name         : p.name || "",
        registration : String(p.registration || ""),
        status       : p.status,
        idDepartment : p.idDepartment || ""
      });
    });

    Logger.log("Pessoas: start=" + start + " | obtidos=" + arr.length);
    if (arr.length < CONFIG_FER.PAGE_SIZE) break;
    start += CONFIG_FER.PAGE_SIZE;
    Utilities.sleep(300);
  }

  return pessoas;
}

// ──────────────────────────────────────────────
//  BUSCAR DEPARTAMENTOS
// ──────────────────────────────────────────────
function fer_buscarDepartamentos(token, pessoas) {
  const mapa = {};
  const ids  = {};
  pessoas.forEach(function(p) { if (p.idDepartment) ids[String(p.idDepartment)] = true; });

  Object.keys(ids).forEach(function(id) {
    try {
      const resp = UrlFetchApp.fetch(CONFIG_FER.BASE_URL + "/department/" + id, {
        headers: { Authorization: "Bearer " + token }, muteHttpExceptions: true
      });
      if (resp.getResponseCode() === 200) mapa[id] = JSON.parse(resp.getContentText()).name || "";
    } catch(e) {}
  });

  return mapa;
}

// ──────────────────────────────────────────────
//  ENRIQUECER COM UNIDADE E DEPARTAMENTO
// ──────────────────────────────────────────────
function fer_enriquecerPessoas(pessoas, token, mapaDepts) {
  for (let i = 0; i < pessoas.length; i++) {
    const p = pessoas[i];
    try {
      const resp = UrlFetchApp.fetch(
        CONFIG_FER.BASE_URL_DB + "/personrolehistory.svc/by_person/" + p.id,
        { headers: { Authorization: "Bearer " + token }, muteHttpExceptions: true }
      );
      if (resp.getResponseCode() === 200) {
        const data = JSON.parse(resp.getContentText());
        const regs = Array.isArray(data) ? data : [data];
        const reg  = regs[regs.length - 1];
        if (reg && reg.person) {
          p.departmentName = reg.person.departmentName || mapaDepts[String(p.idDepartment)] || "";
          p.unidade        = CENTROS_FER[String(reg.person.idCostCenter)] || reg.person.costCenterName || "";
        } else {
          p.departmentName = mapaDepts[String(p.idDepartment)] || "";
          p.unidade        = "";
        }
      } else {
        p.departmentName = mapaDepts[String(p.idDepartment)] || "";
        p.unidade        = "";
      }
    } catch(e) {
      p.departmentName = ""; p.unidade = "";
    }
    if (i > 0 && i % 20 === 0) Utilities.sleep(500);
  }
  return pessoas;
}

// ──────────────────────────────────────────────
//  APURAÇÃO DE PONTO
// ──────────────────────────────────────────────
function fer_getApuracao(token, idPerson, dataIni, dataFinal) {
  const url = CONFIG_FER.BASE_URL + "/apuracao_ponto"
            + "?dataIni="   + dataIni
            + "&dataFinal=" + dataFinal
            + "&idPerson="  + idPerson;
  try {
    const resp = UrlFetchApp.fetch(url, {
      headers: { Authorization: "Bearer " + token }, muteHttpExceptions: true
    });
    if (resp.getResponseCode() !== 200) return null;
    let parsed = JSON.parse(resp.getContentText());
    if (typeof parsed === "string") parsed = JSON.parse(parsed);
    return Array.isArray(parsed) ? parsed : [];
  } catch(e) { return null; }
}

// ──────────────────────────────────────────────
//  TITLE CASE
// ──────────────────────────────────────────────
function fer_titleCase(str) {
  if (!str) return "";
  return str.toLowerCase().replace(/\b\w/g, function(c) { return c.toUpperCase(); });
}

// ══════════════════════════════════════════════════════════════════════════
//  WEB APP — consumido por feriados.html
//  Deploy: Executar como "Eu", Acesso: "Qualquer pessoa"
//  AÇÕES (parâmetro GET "acao"):
//    listar-feriados  — retorna registros com saldo positivo (col H ≥ 0)
//    decisao-feriado  — grava devolutiva (col I) e líder (col J)
// ══════════════════════════════════════════════════════════════════════════

var _WA_SHEET_NAME = "Feriados";

function doGet(e) {
  var p = (e && e.parameter) ? e.parameter : {};
  try {
    if (p.acao === "listar-feriados") return _wa_json(wa_listarFeriados());
    if (p.acao === "decisao-feriado") return _wa_json(wa_salvarDecisao(p));
    return _wa_json({ success: false, message: "acao_desconhecida: " + (p.acao || "") });
  } catch (err) {
    return _wa_json({ success: false, message: String(err) });
  }
}

function wa_listarFeriados() {
  var ss    = SpreadsheetApp.openById(CONFIG_FER.SHEET_ID);
  var sheet = ss.getSheetByName(_WA_SHEET_NAME);
  if (!sheet) return { success: false, message: "Aba não encontrada: " + _WA_SHEET_NAME };

  var data = sheet.getDataRange().getValues();
  if (data.length < 2) return { success: true, rows: [] };

  var rows = [];
  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (!row[0] && !row[2]) continue;

    // Filtra saldo negativo (col H)
    var saldo = String(row[7] || "").trim();
    if (saldo.charAt(0) === "-") continue;

    var dataBR   = _wa_formatDateBR(row[0]);
    var feriNome = String(row[1] || "").trim();
    var feriId   = _wa_slugify(feriNome) + "-" + dataBR.replace(/\//g, "");

    rows.push({
      _linha:       i + 1,
      feriado_id:   feriId,
      feriado_nome: feriNome,
      feriado_data: dataBR,
      nome:         String(row[2] || "").trim(),
      mt:           String(row[3] || "").trim(),
      horas:        String(row[4] || "").trim(),
      unidade:      String(row[5] || "").trim(),
      depto:        String(row[6] || "").trim(),
      saldo:        saldo,
      decisao:      String(row[8] || "").trim(),
      lider:        String(row[9] || "").trim()
    });
  }

  return { success: true, rows: rows };
}

function wa_salvarDecisao(p) {
  var linha   = parseInt(p.linha, 10);
  var decisao = String(p.decisao     || "").trim();
  var lider   = String(p.responsavel || p.lider || "").trim();

  if (!linha || linha < 2) return { success: false, message: "Linha inválida: " + p.linha };
  if (!decisao)            return { success: false, message: "Decisão não informada." };

  var ss    = SpreadsheetApp.openById(CONFIG_FER.SHEET_ID);
  var sheet = ss.getSheetByName(_WA_SHEET_NAME);
  if (!sheet) return { success: false, message: "Aba não encontrada: " + _WA_SHEET_NAME };

  sheet.getRange(linha, 9).setValue(decisao);  // col I — Devolutiva
  sheet.getRange(linha, 10).setValue(lider);   // col J — Líder

  return { success: true };
}

function _wa_formatDateBR(value) {
  if (!value) return "";
  if (value instanceof Date) {
    var d = ("0" + value.getDate()).slice(-2);
    var m = ("0" + (value.getMonth() + 1)).slice(-2);
    return d + "/" + m + "/" + value.getFullYear();
  }
  return String(value);
}

function _wa_slugify(s) {
  return String(s || "")
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .toLowerCase().trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function _wa_json(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
