function atualizarStatusTestes() {
  const nomeAba = "CONTROLE DE TESTES";
  const aba = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(nomeAba);

  if (!aba) {
    throw new Error(`A aba "${nomeAba}" não foi encontrada.`);
  }

  const ultimaLinha = aba.getLastRow();
  if (ultimaLinha < 2) return;

  // Coluna H = 8 | Coluna J = 10
  const datasTeste = aba.getRange(2, 8, ultimaLinha - 1, 1).getValues();
  const status = aba.getRange(2, 10, ultimaLinha - 1, 1).getValues();

  const hoje = new Date();
  hoje.setHours(0, 0, 0, 0);

  let houveAlteracao = false;

  for (let i = 0; i < datasTeste.length; i++) {
    const dataTeste = datasTeste[i][0];
    const statusAtual = status[i][0];

    // Só altera quem está como "Aguardando teste"
    if (statusAtual === "Aguardando teste" && dataTeste instanceof Date) {
      const dataComparacao = new Date(dataTeste);
      dataComparacao.setHours(0, 0, 0, 0);

      if (dataComparacao < hoje) {
        status[i][0] = "Aguardando aprovação";
        houveAlteracao = true;
      }
    }
  }

  if (houveAlteracao) {
    aba.getRange(2, 10, status.length, 1).setValues(status);
  }
}
