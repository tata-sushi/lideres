// ============================================================
//  RHiD — Relatório de Horas em Feriados
//  Automático — detecta feriados da semana passada
//  + Saldo do banco de horas no dia anterior ao feriado
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
//  Funciona corretamente rodando na seg ou terça
// ──────────────────────────────────────────────
function fer_getPeriodo() {
  const hoje   = new Date();
  const diaSem = hoje.getDay(); // 0=dom, 1=seg...6=sab

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
// ──────────────────────────────────────────────
function fer_gravarResultado(linhas, dataIni, dataFim) {
  const ss    = SpreadsheetApp.openById(CONFIG_FER.SHEET_ID);
  const sheet = ss.getSheetByName("Feriados") || ss.insertSheet("Feriados");
  sheet.clearContents();

  sheet.getRange("A1").setValue("Horas Trabalhadas em Feriados")
    .setFontSize(13).setFontWeight("bold");
  sheet.getRange("B1")
    .setValue("Período: " + dataIni.split("-").reverse().join("/") +
              " a "       + dataFim.split("-").reverse().join("/"))
    .setFontColor("#666666");

  const headers = ["Data", "Feriado", "Colaborador", "Matrícula", "Horas", "Unidade", "Departamento", "Saldo Dia Anterior"];
  sheet.getRange(2, 1, 1, headers.length).setValues([headers]);
  sheet.getRange(2, 1, 1, headers.length)
    .setBackground("#1a73e8").setFontColor("#ffffff")
    .setFontWeight("bold").setHorizontalAlignment("center");
  sheet.setFrozenRows(2);

  if (linhas.length === 0) {
    sheet.getRange("A3").setValue("Nenhum colaborador trabalhou em feriados no período.")
      .setFontColor("#888888").setFontStyle("italic");
    return;
  }

  linhas.sort(function(a, b) {
    if (a[0] !== b[0]) return a[0].localeCompare(b[0]);
    return a[2].localeCompare(b[2]);
  });

  sheet.getRange(3, 1, linhas.length, headers.length).setValues(linhas);

  for (let i = 0; i < linhas.length; i++) {
    sheet.getRange(i + 3, 1, 1, headers.length)
      .setBackground(i % 2 === 0 ? "#f8f9fa" : "#ffffff");
  }

  // Horas trabalhadas — azul
  sheet.getRange(3, 5, linhas.length, 1)
    .setFontWeight("bold").setFontColor("#1a73e8").setHorizontalAlignment("center");

  // Saldo dia anterior — verde se positivo, vermelho se negativo
  for (let i = 0; i < linhas.length; i++) {
    const saldo = linhas[i][7] || "";
    const cor   = saldo.startsWith("-") ? "#d32f2f" : "#2e7d32";
    sheet.getRange(i + 3, 8)
      .setFontWeight("bold").setFontColor(cor).setHorizontalAlignment("center");
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
