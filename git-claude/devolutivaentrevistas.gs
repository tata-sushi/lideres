function atualizarStatusDevolutivaEntrevistas() {
  const aba = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("CONTROLE DE ENTREVISTAS");
  if (!aba) {
    Logger.log("Aba não encontrada.");
    return;
  }

  const linhaInicial = 2;
  const ultimaLinha = aba.getLastRow();

  if (ultimaLinha < linhaInicial) {
    Logger.log("Sem linhas para processar.");
    return;
  }

  const quantidadeLinhas = ultimaLinha - linhaInicial + 1;

  const datas = aba.getRange(linhaInicial, 9, quantidadeLinhas, 1).getValues();      // I = data
  const horarios = aba.getRange(linhaInicial, 10, quantidadeLinhas, 1).getValues();  // J = horário
  const status = aba.getRange(linhaInicial, 12, quantidadeLinhas, 1).getValues();    // L = status

  const agora = new Date();
  let alteradas = 0;

  for (let i = 0; i < quantidadeLinhas; i++) {
    const valorData = datas[i][0];
    const valorHorario = horarios[i][0];
    const statusAtual = String(status[i][0]).trim();

    if (statusAtual !== "Aguardando Entrevista") continue;
    if (!valorData) continue;

    const dataHoraEntrevista = new Date(valorData);

    if (isNaN(dataHoraEntrevista.getTime())) {
      Logger.log(`Linha ${linhaInicial + i}: data inválida -> ${valorData}`);
      continue;
    }

    if (valorHorario instanceof Date && !isNaN(valorHorario.getTime())) {
      dataHoraEntrevista.setHours(
        valorHorario.getHours(),
        valorHorario.getMinutes(),
        valorHorario.getSeconds(),
        0
      );
    } else {
      dataHoraEntrevista.setHours(0, 0, 0, 0);
    }

    Logger.log(
      `Linha ${linhaInicial + i} | status="${statusAtual}" | entrevista=${Utilities.formatDate(
        dataHoraEntrevista,
        Session.getScriptTimeZone(),
        "dd/MM/yyyy HH:mm:ss"
      )}`
    );

    if (dataHoraEntrevista <= agora) {
      status[i][0] = "Aguardando devolutiva";
      alteradas++;
    }
  }

  if (alteradas > 0) {
    aba.getRange(linhaInicial, 12, quantidadeLinhas, 1).setValues(status);
  }

  Logger.log(`Total de linhas alteradas: ${alteradas}`);
}
