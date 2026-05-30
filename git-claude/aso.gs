function syncColaboradoresAtivos() {
  var COLABORADORES_ID = '1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw';
  var ASOS_ID = '1vRYt7Nz-RdeKdQOgflMNfQFK4-bweO7vVAda2WWgVzs';

  var ssColaboradores = SpreadsheetApp.openById(COLABORADORES_ID);
  var ssAsos = SpreadsheetApp.openById(ASOS_ID);

  var sheetColaboradores = ssColaboradores.getSheetByName('Colaboradores');
  var sheetAsos = ssAsos.getSheetByName('Controle_de_asos');

  if (!sheetAsos) {
    sheetAsos = ssAsos.insertSheet('Controle_de_asos');
  }

  var dados = sheetColaboradores.getDataRange().getValues();
  var header = dados[0];

  var idx = {
    nome: header.indexOf('Nome'),
    matricula: header.indexOf('Matrícula'),
    cargo: header.indexOf('Cargo'),
    status: header.indexOf('Status'),
    unidade: header.indexOf('Unidade'),
    departamento: header.indexOf('Departamento'),
    admissao: header.indexOf('Data de Admissão')
  };

  var ativos = dados.slice(1).filter(function(row) {
    return row[idx.status] === 'Ativo';
  });

  var asosDados = sheetAsos.getDataRange().getValues();
  var asoHeader = [
    'Matrícula', 'Nome', 'Cargo', 'Departamento', 'Unidade', 'Data de Admissão', 'Status',
    'Tipo de Exame', 'Periodicidade', 'Último exame realizado', 'Realiza exame', 'Próxima Realização'
  ];

  if (asosDados.length === 0 || asosDados[0][0] === '') {
    sheetAsos.getRange(1, 1, 1, asoHeader.length).setValues([asoHeader]);
    sheetAsos.getRange(1, 1, 1, asoHeader.length)
      .setFontWeight('bold')
      .setBackground('#2e4a7a')
      .setFontColor('#ffffff');
    asosDados = [asoHeader];
  }

  var mapaAsos = {};
  for (var i = 1; i < asosDados.length; i++) {
    var mat = String(asosDados[i][0]).trim();
    if (mat) mapaAsos[mat] = i;
  }

  var mapaAtivos = {};
  ativos.forEach(function(row) {
    var mat = String(row[idx.matricula]).trim();
    mapaAtivos[mat] = {
      matricula: mat,
      nome: row[idx.nome],
      cargo: row[idx.cargo],
      departamento: row[idx.departamento],
      unidade: row[idx.unidade],
      admissao: row[idx.admissao]
    };
  });

  // Atualiza colaboradores existentes (apenas colunas A-G para preservar dados de exame em H-K)
  for (var mat in mapaAsos) {
    var rowIdx = mapaAsos[mat];
    var sheetRow = rowIdx + 1;

    if (mapaAtivos[mat]) {
      var c = mapaAtivos[mat];
      sheetAsos.getRange(sheetRow, 1, 1, 7).setValues([[
        c.matricula, c.nome, c.cargo, c.departamento, c.unidade, c.admissao, 'Ativo'
      ]]);
    } else {
      sheetAsos.getRange(sheetRow, 7).setValue('Inativo');
    }
  }

  // Adiciona novos colaboradores com colunas de exame vazias (col L é fórmula, fica vazia aqui)
  var novas = [];
  for (var mat in mapaAtivos) {
    if (!mapaAsos[mat]) {
      var c = mapaAtivos[mat];
      novas.push([c.matricula, c.nome, c.cargo, c.departamento, c.unidade, c.admissao, 'Ativo', '', '', '', 'Sim', '']);
    }
  }

  if (novas.length > 0) {
    var ultimaLinha = sheetAsos.getLastRow() + 1;
    sheetAsos.getRange(ultimaLinha, 1, novas.length, asoHeader.length).setValues(novas);
  }

  Logger.log('Sync concluído. Existentes: ' + Object.keys(mapaAsos).length + ' | Novos: ' + novas.length);

  // Garante a fórmula que calcula a Próxima Realização (col L) no próprio sheet
  garantirFormulaProxima();
}

// ─────────────────────────────────────────────────────────────────────────────
// Coluna L "Próxima Realização" calculada por FÓRMULA no próprio sheet.
// = Último exame realizado (col J) + Periodicidade em dias (col I).
// A fórmula recalcula sozinha sempre que J ou I mudam — não depende de rodar
// o script de novo. Aceita J como data real ou texto dd/mm/aaaa.
// ─────────────────────────────────────────────────────────────────────────────
function garantirFormulaProxima() {
  var ASOS_ID = '1vRYt7Nz-RdeKdQOgflMNfQFK4-bweO7vVAda2WWgVzs';
  var ss = SpreadsheetApp.openById(ASOS_ID);
  var sheet = ss.getSheetByName('Controle_de_asos');
  if (!sheet) return;

  // Remove fórmula/spill anterior em L2 e limpa quaisquer valores estáticos
  // antigos na coluna L para liberar o spill da nova fórmula.
  sheet.getRange('L2').clearContent();
  SpreadsheetApp.flush();
  var lastRow = sheet.getLastRow();
  if (lastRow >= 2) {
    sheet.getRange(2, 12, lastRow - 1, 1).clearContent();
  }

  var formula = '=ARRAYFORMULA(IF((LEN(I2:I)=0)+(LEN(J2:J)=0)+(LEN(A2:A)=0)>0,"",'
              + 'TEXT(IF(ISNUMBER(J2:J),J2:J,IFERROR(DATEVALUE(J2:J),0))+I2:I,"dd/mm/yyyy")))';
  sheet.getRange('L2').setFormula(formula);

  Logger.log('Fórmula de Próxima Realização garantida em L2 (' + lastRow + ' linhas).');
}

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var ASOS_ID = '1vRYt7Nz-RdeKdQOgflMNfQFK4-bweO7vVAda2WWgVzs';
    var ss = SpreadsheetApp.openById(ASOS_ID);
    var sheet = ss.getSheetByName('Controle_de_asos');
    if (!sheet) return respond({ok: false, error: 'Aba não encontrada'});
    var rows = sheet.getDataRange().getValues();
    var matIdx = rows[0].indexOf('Matrícula');
    for (var i = 1; i < rows.length; i++) {
      if (String(rows[i][matIdx]).trim() === String(data.matricula).trim()) {
        sheet.getRange(i+1, 8).setValue(data.tipoExame    || '');  // H Tipo de Exame
        sheet.getRange(i+1, 9).setValue(data.periodicidade || '');  // I Periodicidade
        sheet.getRange(i+1, 10).setValue(data.ultimoExame  || '');  // J Último exame
        sheet.getRange(i+1, 11).setValue(data.realizaExame || '');  // K Realiza exame

        // Col L (Próxima Realização) é calculada pela fórmula no sheet.
        // Garante a fórmula e devolve o valor já recalculado da linha.
        garantirFormulaProxima();
        SpreadsheetApp.flush();
        var prox = sheet.getRange(i+1, 12).getValue();
        return respond({ok: true, proximaRealizacao: prox});
      }
    }
    return respond({ok: false, error: 'Matricula nao encontrada: ' + data.matricula});
  } catch(err) {
    return respond({ok: false, error: err.message});
  }
}

function doGet(e) {
  return ContentService.createTextOutput('ASO API OK').setMimeType(ContentService.MimeType.TEXT);
}

function respond(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function criarTrigger() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === 'syncColaboradoresAtivos') {
      ScriptApp.deleteTrigger(t);
    }
  });

  ScriptApp.newTrigger('syncColaboradoresAtivos')
    .timeBased()
    .everyDays(1)
    .atHour(6)
    .create();

  Logger.log('Trigger criado com sucesso.');
}
