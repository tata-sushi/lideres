// ─── CONFIG ──────────────────────────────────────────────────────────────────
const CONFIG_AUS3 = {
  BASE_URL    : "https://rhid.com.br/v2/api.svc",
  BASE_URL_DB : "https://rhid.com.br/v2/customerdb",
  EMAIL       : "victor.carvalho@tatasushi.com.br",
  PASSWORD    : "Tata@123",
  DOMAIN      : "",
  PAGE_SIZE   : 100,
  SS_ID       : "1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw",
  ABA_DADOS   : "Ausências",
};

const CENTROS_DE_CUSTO_AUS3 = {
  "2": "Itaim",
  "5": "Tatá House",
  "6": "Administrativo",
  "7": "Pinheiros",
  "8": "Poke - Pinheiros"
};

const NOMES_EXCLUIR_AUS3      = ["ID2ID", "CLOUD", "id2"];
const MATRICULAS_EXCLUIR_AUS3 = ["0"];

const COLUNAS_AUS3 = [
  "MT", "COLABORADOR", "UNIDADE", "DEPARTAMENTO", "DATA_FALTA", "TIPO DE AUSÊNCIA", "STATUS"
];

const MAPA_TIPOS_AUS3 = {
  "falta"                     : "Falta",
  "medico"                    : "Atestado Médico",
  "atestado médico"           : "Atestado Médico",
  "atestado medico"           : "Atestado Médico",
  "afastamento inss"          : "Afastamento INSS",
  "suspensão"                 : "Suspensão",
  "suspensao"                 : "Suspensão",
  "suspensão de contrato"     : "Suspensão de Contrato",
  "suspensao de contrato"     : "Suspensão de Contrato",
  "licença casamento"         : "Licença Casamento",
  "licenca casamento"         : "Licença Casamento",
  "licença maternidade"       : "Licença Maternidade",
  "licenca maternidade"       : "Licença Maternidade",
  "licença nojo"              : "Licença Nojo",
  "licenca nojo"              : "Licença Nojo",
  "licença paternidade"       : "Licença Paternidade",
  "licenca paternidade"       : "Licença Paternidade",
  "acompanhamento familiar"   : "Acompanhamento Familiar",
  "declaração de horas"       : "Declaração de Horas",
  "declaracao de horas"       : "Declaração de Horas",
  "folga aniversário"         : "Folga Aniversário",
  "folga aniversario"         : "Folga Aniversário",
};

// ─── SEMANAL (últimos 10 dias) ────────────────────────────────────────────────
function importarAusenciasSemanal3() {
  const { dataIni, dataFinal } = _getUltimos10Dias();
  _executarImportacaoAus3(dataIni, dataFinal);
}

// ─── HISTÓRICO DESDE 26/04/2026 ───────────────────────────────────────────────
function importarAusenciasDesde26Abril() {
  const dataIni   = "2026-04-26";
  const dataFinal = Utilities.formatDate(new Date(), "America/Sao_Paulo", "yyyy-MM-dd");
  Logger.log("Ausências | Histórico: " + dataIni + " → " + dataFinal);
  _executarImportacaoAus3(dataIni, dataFinal);
}

// ─── NÚCLEO COMPARTILHADO ─────────────────────────────────────────────────────
function _executarImportacaoAus3(dataIni, dataFinal) {
  const ss  = SpreadsheetApp.openById(CONFIG_AUS3.SS_ID);
  const aba = _getOrCreateSheetAus3(ss, CONFIG_AUS3.ABA_DADOS);

  if (aba.getLastRow() === 0) {
    aba.getRange(1, 1, 1, COLUNAS_AUS3.length).setValues([COLUNAS_AUS3]);
    aba.getRange(1, 1, 1, COLUNAS_AUS3.length)
      .setFontWeight("bold")
      .setBackground("#35383F")
      .setFontColor("#CFFF00");
    aba.setFrozenRows(1);
  }

  Logger.log("Período: " + dataIni + " → " + dataFinal);

  const token = _loginAus3();
  if (!token) { Logger.log("Falha no login."); return; }

  const pessoas     = _getAllPersonsAus3(token);
  const mapaDepts   = _buscarMapaDepartamentosAus3(token, pessoas);
  const pessoasRich = _enriquecerPessoasAus3(pessoas, token, mapaDepts);

  const elegiveis = pessoasRich.filter(p =>
    !NOMES_EXCLUIR_AUS3.some(n => (p.name || "").toUpperCase().includes(n.toUpperCase())) &&
    !MATRICULAS_EXCLUIR_AUS3.includes(String(p.registration || "").trim())
  );

  Logger.log("Elegíveis: " + elegiveis.length);

  const chaves       = _carregarChavesComLinha(aba);
  const novasLinhas  = [];
  let   atualizacoes = 0;

  for (let i = 0; i < elegiveis.length; i++) {
    const p      = elegiveis[i];
    const mt     = String(p.registration || "");
    const status = _traduzirStatusAus3(p.status, mt);

    const dias = _getApuracaoAus3(token, p.id, dataIni, dataFinal);
    if (!dias || dias.length === 0) continue;

    dias.forEach(d => {
      const lista = d.listAfdtManutencao;
      if (!lista || lista.length === 0) return;

      const temJustificativa = lista.some(item =>
        item.idJustification && item.idJustification !== 0
      );
      if (!temJustificativa) return;

      const dataFalta    = _formatarDataAus3(d.date || "");
      const tipoAusencia = _extrairTipoAusencia3(d);
      if (!tipoAusencia) return;

      const chave = mt + "|" + dataFalta;

      if (chaves[chave]) {
        if (chaves[chave].tipo !== tipoAusencia) {
          aba.getRange(chaves[chave].linha, 6).setValue(tipoAusencia);
          atualizacoes++;
        }
        aba.getRange(chaves[chave].linha, 7).setValue(status);
      } else {
        chaves[chave] = true;
        novasLinhas.push([
          mt,
          toTitleCaseAus3(p.name || ""),
          p.unidade                        || "",
          toTitleCaseAus3(p.departmentName || ""),
          dataFalta,
          tipoAusencia,
          status,
        ]);
      }
    });

    if ((i + 1) % 10 === 0) Utilities.sleep(500);
  }

  if (novasLinhas.length > 0) {
    const proximaLinha = aba.getLastRow() + 1;
    aba.getRange(proximaLinha, 1, novasLinhas.length, COLUNAS_AUS3.length).setValues(novasLinhas);
    aba.autoResizeColumns(1, COLUNAS_AUS3.length);
  }

  Logger.log("Concluído! Novas: " + novasLinhas.length + " | Atualizações: " + atualizacoes);
}

// ─── ÚLTIMOS 10 DIAS ──────────────────────────────────────────────────────────
function _getUltimos10Dias() {
  const hoje   = new Date();
  const inicio = new Date(hoje);
  inicio.setDate(hoje.getDate() - 10);
  inicio.setHours(0, 0, 0, 0);
  const fmt = d => Utilities.formatDate(d, "America/Sao_Paulo", "yyyy-MM-dd");
  return { dataIni: fmt(inicio), dataFinal: fmt(hoje) };
}

// ─── TRADUZIR STATUS ──────────────────────────────────────────────────────────
function _traduzirStatusAus3(status, matricula) {
  const MATRICULAS_FORCAR_ATIVO = {
    "07": true, "01": true, "03": true, "24174": true,
    "04": true, "24600": true, "24092": true, "24194": true,
    "24090": true, "02": true, "24077": true, "05": true
  };
  if (matricula && MATRICULAS_FORCAR_ATIVO[String(matricula).trim()]) return "Ativo";
  switch (status) {
    case 0: return "Inativo";
    case 1: return "Ativo";
    case 2: return "Bloqueado";
    default: return status !== undefined ? String(status) : "—";
  }
}

// ─── EXTRAIR E PADRONIZAR TIPO ────────────────────────────────────────────────
function _extrairTipoAusencia3(dia) {
  const lista = dia.listAfdtManutencao;
  if (!lista || lista.length === 0) return null;

  for (let i = 0; i < lista.length; i++) {
    const abrev = lista[i].abreviationJustification;
    if (abrev && abrev.trim() !== "" && abrev !== "null") {
      const padronizado = MAPA_TIPOS_AUS3[abrev.trim().toLowerCase()];
      if (padronizado) return padronizado;
    }
  }

  for (let i = 0; i < lista.length; i++) {
    const item = lista[i];
    if (!item.afdtLogs || item.afdtLogs.length === 0) continue;
    for (let j = 0; j < item.afdtLogs.length; j++) {
      const detalhe = item.afdtLogs[j].detalheDiferencaConsiderada;
      if (!detalhe || detalhe.trim() === "") continue;
      if (/horário previsto alterado/i.test(detalhe)) continue;
      if (/tolerância|tolerancia/i.test(detalhe)) continue;
      if (/batida/i.test(detalhe)) continue;
      if (/descontada/i.test(detalhe)) continue;
      if (/diferença|diferenca/i.test(detalhe)) continue;
      const padronizado = MAPA_TIPOS_AUS3[detalhe.trim().toLowerCase()];
      if (padronizado) return padronizado;
    }
  }

  return null;
}

// ─── CARREGAR CHAVES COM LINHA E TIPO ────────────────────────────────────────
function _carregarChavesComLinha(aba) {
  const chaves = {};
  const ultima = aba.getLastRow();
  if (ultima < 2) return chaves;
  aba.getRange(2, 1, ultima - 1, 6).getValues().forEach((row, idx) => {
    const mt   = String(row[0] || "").trim();
    const data = String(row[4] || "").trim();
    const tipo = String(row[5] || "").trim();
    if (mt && data) chaves[mt + "|" + data] = { linha: idx + 2, tipo: tipo };
  });
  return chaves;
}

// ─── FORMATAR DATA ────────────────────────────────────────────────────────────
function _formatarDataAus3(v) {
  if (!v) return "";
  const matchISO = String(v).match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (matchISO) return matchISO[3] + "/" + matchISO[2] + "/" + matchISO[1];
  const matchMS = String(v).match(/\/Date\((-?\d+)([+-]\d+)?\)\//);
  if (matchMS) {
    const date = new Date(parseInt(matchMS[1], 10));
    return String(date.getUTCDate()).padStart(2, "0") + "/" +
           String(date.getUTCMonth() + 1).padStart(2, "0") + "/" +
           date.getUTCFullYear();
  }
  return String(v).substring(0, 10);
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────
function _loginAus3() {
  try {
    const resp = UrlFetchApp.fetch(CONFIG_AUS3.BASE_URL + "/login", {
      method: "POST", contentType: "application/json",
      payload: JSON.stringify({
        email   : CONFIG_AUS3.EMAIL,
        password: CONFIG_AUS3.PASSWORD,
        domain  : CONFIG_AUS3.DOMAIN,
      }),
      muteHttpExceptions: true,
    });
    if (resp.getResponseCode() !== 200) return null;
    const data = JSON.parse(resp.getContentText());
    return data.accessToken || data.token || data.access_token || null;
  } catch(e) { Logger.log("Exceção login: " + e.message); return null; }
}

// ─── BUSCAR TODOS OS COLABORADORES ───────────────────────────────────────────
function _getAllPersonsAus3(token) {
  const pessoas = [];
  let start = 0;
  while (true) {
    try {
      const resp = UrlFetchApp.fetch(
        CONFIG_AUS3.BASE_URL + "/person?start=" + start + "&length=" + CONFIG_AUS3.PAGE_SIZE, {
        headers: { Authorization: "Bearer " + token },
        muteHttpExceptions: true,
      });
      if (resp.getResponseCode() !== 200) break;
      let data = JSON.parse(resp.getContentText());
      if (typeof data === "string") data = JSON.parse(data);
      const arr = data.records || data.data || (Array.isArray(data) ? data : []);
      if (arr.length === 0) break;
      arr.forEach(p => pessoas.push({
        id          : p.id,
        name        : p.name || "id_" + p.id,
        registration: String(p.registration || ""),
        status      : p.status,
        idDepartment: p.idDepartment || "",
      }));
      if (arr.length < CONFIG_AUS3.PAGE_SIZE) break;
      start += CONFIG_AUS3.PAGE_SIZE;
      Utilities.sleep(300);
    } catch(e) { Logger.log("Exceção /person: " + e.message); break; }
  }
  return pessoas;
}

// ─── ENRIQUECER PESSOAS ───────────────────────────────────────────────────────
function _enriquecerPessoasAus3(pessoas, token, mapaDepts) {
  for (let i = 0; i < pessoas.length; i++) {
    const p = pessoas[i];
    try {
      const resp = UrlFetchApp.fetch(
        CONFIG_AUS3.BASE_URL_DB + "/personrolehistory.svc/by_person/" + p.id, {
        headers: { Authorization: "Bearer " + token },
        muteHttpExceptions: true,
      });
      if (resp.getResponseCode() === 200) {
        const data = JSON.parse(resp.getContentText());
        const regs = Array.isArray(data) ? data : [data];
        const reg  = regs[regs.length - 1];
        if (reg && reg.person) {
          const person     = reg.person;
          p.departmentName = person.departmentName || mapaDepts[String(p.idDepartment)] || "";
          p.unidade        = CENTROS_DE_CUSTO_AUS3[String(person.idCostCenter)] || person.costCenterName || "";
        } else {
          p.departmentName = mapaDepts[String(p.idDepartment)] || "";
          p.unidade = "";
        }
      } else {
        p.departmentName = mapaDepts[String(p.idDepartment)] || "";
        p.unidade = "";
      }
    } catch(e) { p.departmentName = ""; p.unidade = ""; }
    if (i > 0 && i % 20 === 0) Utilities.sleep(500);
  }
  return pessoas;
}

// ─── BUSCAR DEPARTAMENTOS ─────────────────────────────────────────────────────
function _buscarMapaDepartamentosAus3(token, pessoas) {
  const mapa = {};
  const ids  = {};
  pessoas.forEach(p => { if (p.idDepartment) ids[String(p.idDepartment)] = true; });
  Object.keys(ids).forEach(id => {
    try {
      const resp = UrlFetchApp.fetch(CONFIG_AUS3.BASE_URL + "/department/" + id, {
        headers: { Authorization: "Bearer " + token },
        muteHttpExceptions: true,
      });
      if (resp.getResponseCode() === 200) mapa[id] = JSON.parse(resp.getContentText()).name || "";
    } catch(e) {}
  });
  return mapa;
}

// ─── APURACAO PONTO ───────────────────────────────────────────────────────────
function _getApuracaoAus3(token, idPerson, dataIni, dataFinal) {
  const url = CONFIG_AUS3.BASE_URL + "/apuracao_ponto"
    + "?dataIni="   + encodeURIComponent(dataIni)
    + "&dataFinal=" + encodeURIComponent(dataFinal)
    + "&idPerson="  + idPerson;
  try {
    const resp = UrlFetchApp.fetch(url, {
      headers: { Authorization: "Bearer " + token },
      muteHttpExceptions: true,
    });
    if (resp.getResponseCode() !== 200) return null;
    let parsed = JSON.parse(resp.getContentText());
    if (typeof parsed === "string") parsed = JSON.parse(parsed);
    return Array.isArray(parsed) ? parsed : (parsed.records || parsed.data || []);
  } catch(e) { return null; }
}

// ─── WEB APP — salvar devolutiva ─────────────────────────────────────────────
function doGet(e) {
  var p = (e && e.parameter) ? e.parameter : {};
  try {
    if (p.acao === 'devolutiva-ausencia') return _json(_salvarDevolutiva(p));
    return _json({ success: false, message: 'acao_desconhecida: ' + (p.acao || '') });
  } catch (err) {
    return _json({ success: false, message: String(err) });
  }
}

function _salvarDevolutiva(p) {
  var linha      = parseInt(p.linha, 10);
  var devolutiva = (p.devolutiva || '').trim();
  if (!linha || linha < 2) return { success: false, message: 'linha_invalida' };
  if (!devolutiva)         return { success: false, message: 'devolutiva_vazia' };

  var ss  = SpreadsheetApp.openById(CONFIG_AUS3.SS_ID);
  var aba = ss.getSheetByName(CONFIG_AUS3.ABA_DADOS);
  if (!aba) return { success: false, message: 'aba_nao_encontrada' };

  var tipoAtual  = (aba.getRange(linha, 6).getValue() || '').toString().trim();
  var msgColH    = (tipoAtual && tipoAtual.toLowerCase() !== devolutiva.toLowerCase())
    ? 'Era ' + tipoAtual + ' alterou para ' + devolutiva
    : devolutiva;

  aba.getRange(linha, 6).setValue(devolutiva); // col F — TIPO DE AUSÊNCIA
  aba.getRange(linha, 8).setValue(msgColH);    // col H — DEVOLUTIVA

  return { success: true };
}

function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}


function _getOrCreateSheetAus3(ss, name) {
  return ss.getSheetByName(name) || ss.insertSheet(name);
}

function toTitleCaseAus3(str) {
  if (!str) return "";
  const minusculas = ["de","da","do","das","dos","e","a","o"];
  return str.toLowerCase().replace(/(?:^|\s)\S/g, function(c, i) {
    const word = str.toLowerCase().slice(i).match(/\S+/)[0];
    return (i === 0 || !minusculas.includes(word)) ? c.toUpperCase() : c;
  });
}
