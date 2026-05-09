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
};

// ─── SEMANAL (seg–dom da semana anterior) ─────────────────────────────────────
// Agendar: toda sexta-feira no Google Apps Script
// Processa em lotes de 50 para não exceder o limite de 6 min do Apps Script
const LOTE_SIZE_AUS3 = 100;

function importarAusenciasSemanal3() {
  // Limpa estado anterior e inicia do zero
  PropertiesService.getScriptProperties().deleteAllProperties();
  const { dataIni, dataFinal } = _getSemanAnterior();
  PropertiesService.getScriptProperties().setProperties({
    AUS3_DATINI   : dataIni,
    AUS3_DATFINAL : dataFinal,
    AUS3_INDEX    : "0",
  });
  _processarLoteAus3();
}

function _processarLoteAus3() {
  const props    = PropertiesService.getScriptProperties();
  const dataIni  = props.getProperty("AUS3_DATINI");
  const dataFinal= props.getProperty("AUS3_DATFINAL");
  const startIdx = parseInt(props.getProperty("AUS3_INDEX") || "0", 10);

  if (!dataIni || !dataFinal) { Logger.log("Nenhuma execução em andamento."); return; }

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

  const token = _loginAus3();
  if (!token) { Logger.log("Falha no login."); return; }

  // Busca pessoas apenas no primeiro lote e salva no cache
  let elegiveisJSON = props.getProperty("AUS3_ELEGIVEIS");
  let elegiveis;
  if (!elegiveisJSON) {
    const pessoas     = _getAllPersonsAus3(token);
    const mapaDepts   = _buscarMapaDepartamentosAus3(token, pessoas);
    const pessoasRich = _enriquecerPessoasAus3(pessoas, token, mapaDepts);
    elegiveis = pessoasRich.filter(p =>
      !NOMES_EXCLUIR_AUS3.some(n => (p.name || "").toUpperCase().includes(n.toUpperCase())) &&
      !MATRICULAS_EXCLUIR_AUS3.includes(String(p.registration || "").trim())
    );
    props.setProperty("AUS3_ELEGIVEIS", JSON.stringify(elegiveis));
    Logger.log("Elegíveis: " + elegiveis.length);
  } else {
    elegiveis = JSON.parse(elegiveisJSON);
  }

  const lote    = elegiveis.slice(startIdx, startIdx + LOTE_SIZE_AUS3);
  const chaves  = _carregarChavesComLinha(aba);
  const novasLinhas = [];
  let   atualizacoes = 0;

  Logger.log("Processando lote: " + (startIdx + 1) + " → " + (startIdx + lote.length) + " de " + elegiveis.length);

  for (let i = 0; i < lote.length; i++) {
    const p      = lote[i];
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
        const unidadeNova = p.unidade || "";
        const deptoNovo   = toTitleCaseAus3(p.departmentName || "");
        if (chaves[chave].unidade !== unidadeNova) {
          aba.getRange(chaves[chave].linha, 3).setValue(unidadeNova);
          atualizacoes++;
        }
        if (chaves[chave].depto !== deptoNovo) {
          aba.getRange(chaves[chave].linha, 4).setValue(deptoNovo);
          atualizacoes++;
        }
        if (chaves[chave].tipo !== tipoAusencia) {
          aba.getRange(chaves[chave].linha, 6).setValue(tipoAusencia);
          atualizacoes++;
        }
        aba.getRange(chaves[chave].linha, 7).setValue(status);
      } else {
        chaves[chave] = { linha: aba.getLastRow() + 1 + novasLinhas.length, tipo: tipoAusencia, unidade: p.unidade || "", depto: toTitleCaseAus3(p.departmentName || "") };
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

    if ((i + 1) % 10 === 0) Utilities.sleep(300);
  }

  if (novasLinhas.length > 0) {
    const proximaLinha = aba.getLastRow() + 1;
    aba.getRange(proximaLinha, 1, novasLinhas.length, COLUNAS_AUS3.length).setValues(novasLinhas);
    aba.autoResizeColumns(1, COLUNAS_AUS3.length);
  }

  Logger.log("Lote concluído. Novas: " + novasLinhas.length + " | Atualizações: " + atualizacoes);

  const proximoIdx = startIdx + LOTE_SIZE_AUS3;
  if (proximoIdx < elegiveis.length) {
    // Ainda há lotes — agenda próxima execução em 1 minuto
    props.setProperty("AUS3_INDEX", String(proximoIdx));
    ScriptApp.newTrigger("_processarLoteAus3")
      .timeBased()
      .after(60 * 1000)
      .create();
    Logger.log("Próximo lote agendado: a partir do índice " + proximoIdx);
  } else {
    // Concluído — limpa estado e triggers temporários
    props.deleteAllProperties();
    _limparTriggersAus3();
    Logger.log("Importação completa!");
  }
}

function _limparTriggersAus3() {
  ScriptApp.getProjectTriggers().forEach(t => {
    if (t.getHandlerFunction() === "_processarLoteAus3") {
      ScriptApp.deleteTrigger(t);
    }
  });
}



// ─── DUAS SEMANAS ANTERIORES (seg–dom) ───────────────────────────────────────
// Pega o último domingo completo e volta 13 dias para a segunda de 2 semanas atrás.
// Registros já existentes só têm tipo/status atualizados se mudaram — sem duplicatas.
function _getSemanAnterior() {
  const hoje      = new Date();
  const diaSemana = hoje.getDay(); // 0=dom, 1=seg ... 6=sab

  // Domingo da semana passada
  const dom = new Date(hoje);
  dom.setDate(hoje.getDate() - diaSemana);
  dom.setHours(23, 59, 59, 0);

  // Segunda de 2 semanas atrás (13 dias antes do domingo)
  const seg = new Date(dom);
  seg.setDate(dom.getDate() - 13);
  seg.setHours(0, 0, 0, 0);

  const fmt = d => Utilities.formatDate(d, "America/Sao_Paulo", "yyyy-MM-dd");
  return { dataIni: fmt(seg), dataFinal: fmt(dom) };
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

  // 1. Priorizar abreviationJustification
  for (let i = 0; i < lista.length; i++) {
    const abrev = lista[i].abreviationJustification;
    if (abrev && abrev.trim() !== "" && abrev !== "null") {
      const padronizado = MAPA_TIPOS_AUS3[abrev.trim().toLowerCase()];
      if (padronizado) return padronizado;
    }
  }

  // 2. Fallback: detalheDiferencaConsiderada filtrado
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
  aba.getRange(2, 1, ultima - 1, 7).getValues().forEach((row, idx) => {
    const mt      = String(row[0] || "").trim();
    const data    = String(row[4] || "").trim();
    const tipo    = String(row[5] || "").trim();
    const status  = String(row[6] || "").trim();
    const unidade = String(row[2] || "").trim();
    const depto   = String(row[3] || "").trim();
    if (mt && data) chaves[mt + "|" + data] = { linha: idx + 2, tipo: tipo, status: status, unidade: unidade, depto: depto };
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

// ─── UTILITÁRIOS ─────────────────────────────────────────────────────────────
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
