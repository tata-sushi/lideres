/**
 * TATÁ — Organograma · Apps Script Web App
 * Versão ajustada para a estrutura real da planilha "Colaboradores"
 *
 * Setup:
 * 1. Cole este código no Apps Script da planilha
 * 2. Ajuste PASTA_FOTOS_ID abaixo
 * 3. Implantar > Nova implantação > Tipo: App da Web
 *    - Executar como: Eu
 *    - Quem tem acesso: Qualquer pessoa
 * 4. Copiar URL e usar no HTML
 */

// ============================================
// CONFIGURAÇÃO
// ============================================
const CONFIG = {
  ABA: 'Colaboradores',

  // ID da planilha de colaboradores (trecho da URL entre /d/ e /edit)
  PLANILHA_ID: '1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw',

  // ID da pasta do Drive com as fotos (extrair do URL da pasta)
  // URL exemplo: https://drive.google.com/drive/folders/1ABC123XYZ
  // O ID é o "1ABC123XYZ"
  PASTA_FOTOS_ID: '1s_GnNwAK83LEgGHDAQwBcNU-5CTD2Z7m',

  // Nomes EXATOS das colunas na planilha (case-sensitive, conforme cabeçalho real)
  COLUNAS: {
    nome:          'Nome',
    matricula:     'Matrícula',
    cargo:         'Cargo',
    status:        'Status',           // Ativo / Inativo
    unidade:       'Unidade',          // Itaim / Pinheiros / PUC
    departamento:  'Departamento',     // Sushibar, Salão, Cozinha, RH, etc
    idPessoa:      'ID Pessoa',        // ID interno usado para vincular hierarquia
    supervisor:    'ID Superior',      // ID Pessoa do supervisor
    nomeSuperior:  'Nome do Superior', // Apenas para validação visual
    admissao:      'Data de Admissão',
    demissao:      'Data de Demissão'
  },

  // Colunas opcionais — sem erro se ausentes na planilha
  COLUNAS_OPCIONAIS: {
    dataNascimento: 'Data de Nascimento'
  },

  CACHE_FOTOS_MIN: 30,

  // ID Pessoa do CEO (raiz). Deixe vazio para detecção automática.
  CEO_ID: ''
};

// ============================================
// ENDPOINT
// ============================================
function doGet(e) {
  try {
    const dados = montarOrganograma();
    return ContentService
      .createTextOutput(JSON.stringify(dados))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ erro: err.message, stack: err.stack }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// ============================================
// LÓGICA PRINCIPAL
// ============================================
function montarOrganograma() {
  const colaboradores = lerPlanilha();
  const fotos = listarFotosDrive();
  const arvore = construirHierarquia(colaboradores, fotos);
  const stats = calcularStats(colaboradores);
  const orfaos = detectarOrfaos(colaboradores);

  return {
    geradoEm: new Date().toISOString(),
    total: colaboradores.length,
    stats: stats,
    arvore: arvore,
    avisos: orfaos.length > 0 ? { orfaos: orfaos } : null
  };
}

// ============================================
// LEITURA DA PLANILHA
// ============================================
function lerPlanilha() {
  const ss = SpreadsheetApp.openById(CONFIG.PLANILHA_ID);
  const aba = ss.getSheetByName(CONFIG.ABA);
  if (!aba) throw new Error('Aba "' + CONFIG.ABA + '" não encontrada');

  const values = aba.getDataRange().getValues();
  if (values.length < 2) throw new Error('Planilha vazia');

  const headers = values[0].map(h => String(h).trim());
  const idx = {};
  Object.keys(CONFIG.COLUNAS).forEach(key => {
    const col = CONFIG.COLUNAS[key];
    const i = headers.indexOf(col);
    if (i === -1) {
      throw new Error('Coluna "' + col + '" não encontrada. Cabeçalhos da planilha: ' + headers.join(' | '));
    }
    idx[key] = i;
  });

  const idxOpt = {};
  Object.keys(CONFIG.COLUNAS_OPCIONAIS || {}).forEach(key => {
    idxOpt[key] = headers.indexOf(CONFIG.COLUNAS_OPCIONAIS[key]);
  });

  const resultado = [];
  for (let i = 1; i < values.length; i++) {
    const row = values[i];

    // Filtra somente ATIVOS
    const status = String(row[idx.status]).trim().toLowerCase();
    if (status !== 'ativo') continue;

    // ID Pessoa obrigatório (chave da hierarquia)
    const idPessoa = String(row[idx.idPessoa]).trim();
    if (!idPessoa) continue;

    const matricula = String(row[idx.matricula]).trim();
    const nome = String(row[idx.nome]).trim();
    const cargo = String(row[idx.cargo]).trim();
    const unidade = String(row[idx.unidade]).trim();
    const departamento = String(row[idx.departamento]).trim();
    const supervisor = String(row[idx.supervisor]).trim();

    resultado.push({
      id: idPessoa,
      idPessoa: idPessoa,
      matricula: matricula,
      nome: nome,
      cargo: cargo,
      supervisorId: supervisor || null,
      unidade: unidade,
      departamento: departamento,
      nivel: detectarNivel(cargo),
      unitClass: classeUnidade(unidade),
      admissao: isoDate(row[idx.admissao]),
      dataNascimento: idxOpt.dataNascimento >= 0 ? isoDate(row[idxOpt.dataNascimento]) : null
    });
  }

  return resultado;
}

// ============================================
// DETECÇÃO DE NÍVEL POR PREFIXO DO CARGO
// ============================================
function detectarNivel(cargo) {
  const c = normalizar(cargo);

  // Diretoria
  if (/^(diretor|ceo|socio|presidente|coo|cfo|chro|cco)/.test(c)) return 'diretoria';

  // Gerência (inclui "Chef Executivo" como cargo de gerência)
  if (/^(gerente|coord|chef executivo)/.test(c)) return 'gerencia';

  // Supervisor (Sup, Sup., Sup PI, Supervisor, Lider, Encarregado, Chef/Chefe, Maitre)
  if (/^(sup|lider|líder|encarregado|chef|maitre|maître)/.test(c)) return 'supervisor';

  return 'operacional';
}

function isoDate(val) {
  if (!val) return null;
  if (val instanceof Date && !isNaN(val.getTime())) {
    var y = val.getFullYear();
    var m = String(val.getMonth() + 1).padStart(2, '0');
    var d = String(val.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + d;
  }
  return null;
}

function normalizar(str) {
  return String(str).toLowerCase().trim()
    .normalize('NFD').replace(/[̀-ͯ]/g, '');
}

function classeUnidade(unidade) {
  const u = normalizar(unidade);
  if (u.indexOf('puc') !== -1 || u.indexOf('poke') !== -1) return 'puc';
  if (u.indexOf('itaim') !== -1) return 'itaim';
  if (u.indexOf('pinheiros') !== -1) return 'pinheiros';
  if (u.indexOf('tata house') !== -1 || u.indexOf('house') !== -1) return 'tatahouse';
  return null;
}

// ============================================
// HIERARQUIA
// ============================================
function construirHierarquia(colaboradores, fotos) {
  const mapa = {};
  colaboradores.forEach(c => {
    mapa[c.id] = Object.assign({}, c, {
      foto: fotos[c.matricula] || null,
      iniciais: gerarIniciais(c.nome),
      children: []
    });
  });

  let raiz = null;
  const semIdSuperior = [];  // ID Superior vazio → candidato a raiz
  const orfaos = [];          // ID Superior preenchido mas pessoa não encontrada no mapa

  colaboradores.forEach(c => {
    const node = mapa[c.id];
    // Self-reference: trata como órfão (evita loop infinito)
    if (c.supervisorId === c.id) {
      orfaos.push(node);
    } else if (c.supervisorId && mapa[c.supervisorId]) {
      mapa[c.supervisorId].children.push(node);
    } else if (c.supervisorId) {
      orfaos.push(node);
    } else {
      semIdSuperior.push(node);
    }
  });

  // Definir raiz — apenas quem tem ID Superior vazio
  if (CONFIG.CEO_ID && mapa[CONFIG.CEO_ID]) {
    raiz = mapa[CONFIG.CEO_ID];
    semIdSuperior.forEach(n => { if (n.id !== raiz.id) raiz.children.push(n); });
  } else if (semIdSuperior.length === 1) {
    raiz = semIdSuperior[0];
  } else if (semIdSuperior.length > 1) {
    // Vários com ID Superior vazio — desempate por nível
    semIdSuperior.sort((a, b) => {
      const ordem = { diretoria: 0, gerencia: 1, supervisor: 2, operacional: 3 };
      return (ordem[a.nivel] ?? 9) - (ordem[b.nivel] ?? 9);
    });
    raiz = semIdSuperior[0];
    for (let i = 1; i < semIdSuperior.length; i++) {
      raiz.children.push(semIdSuperior[i]);
    }
  } else {
    throw new Error('Nenhum colaborador com ID Superior vazio — defina pelo menos um para ser a raiz');
  }

  // Órfãos viram filhos da raiz (com aviso, mas sem competir pela raiz)
  orfaos.forEach(n => { if (n.id !== raiz.id) raiz.children.push(n); });

  // Ordenar filhos
  const ordemNivel = { diretoria: 0, gerencia: 1, supervisor: 2, operacional: 3 };
  function ordenar(node) {
    if (!node.children) return;
    node.children.sort((a, b) => {
      const da = ordemNivel[a.nivel] || 9;
      const db = ordemNivel[b.nivel] || 9;
      if (da !== db) return da - db;
      return a.nome.localeCompare(b.nome, 'pt-BR');
    });
    node.children.forEach(ordenar);
  }
  ordenar(raiz);

  return raiz;
}

function gerarIniciais(nome) {
  const partes = String(nome).trim().split(/\s+/);
  if (partes.length === 0) return '?';
  if (partes.length === 1) return partes[0].charAt(0).toUpperCase();
  return (partes[0].charAt(0) + partes[partes.length - 1].charAt(0)).toUpperCase();
}

// ============================================
// FOTOS DO DRIVE
// ============================================
function listarFotosDrive() {
  const cache = CacheService.getScriptCache();
  const cached = cache.get('fotos_map');
  if (cached) {
    try { return JSON.parse(cached); } catch (e) { /* segue */ }
  }

  if (!CONFIG.PASTA_FOTOS_ID || CONFIG.PASTA_FOTOS_ID.indexOf('COLE_AQUI') !== -1) {
    Logger.log('AVISO: PASTA_FOTOS_ID não configurado. Fotos não serão carregadas.');
    return {};
  }

  const pasta = DriveApp.getFolderById(CONFIG.PASTA_FOTOS_ID);
  const arquivos = pasta.getFiles();
  const map = {};

  while (arquivos.hasNext()) {
    const arq = arquivos.next();
    const nomeArq = arq.getName();
    const m = nomeArq.match(/^(\d+)\./);
    if (m) {
      const matricula = m[1];
      const id = arq.getId();
      map[matricula] = 'https://lh3.googleusercontent.com/d/' + id + '=s120';
    }
  }

  cache.put('fotos_map', JSON.stringify(map), CONFIG.CACHE_FOTOS_MIN * 60);
  return map;
}

// ============================================
// VALIDAÇÕES
// ============================================
function detectarOrfaos(colaboradores) {
  const ids = {};
  colaboradores.forEach(c => { ids[c.id] = true; });

  const orfaos = [];
  colaboradores.forEach(c => {
    if (c.supervisorId && !ids[c.supervisorId]) {
      orfaos.push({
        matricula: c.matricula,
        idPessoa: c.idPessoa,
        nome: c.nome,
        supervisorIdInexistente: c.supervisorId
      });
    }
  });
  return orfaos;
}

function calcularStats(colaboradores) {
  const stats = { total: colaboradores.length, itaim: 0, pinheiros: 0, puc: 0, tatahouse: 0, backoffice: 0 };
  colaboradores.forEach(c => {
    if (c.unitClass === 'itaim') stats.itaim++;
    else if (c.unitClass === 'pinheiros') stats.pinheiros++;
    else if (c.unitClass === 'puc') stats.puc++;
    else if (c.unitClass === 'tatahouse') stats.tatahouse++;
    else stats.backoffice++;
  });
  return stats;
}

// ============================================
// UTILITÁRIOS — rodar manualmente no editor
// ============================================
function limparCacheFotos() {
  CacheService.getScriptCache().remove('fotos_map');
  Logger.log('Cache de fotos limpo.');
}

function testar() {
  const dados = montarOrganograma();
  Logger.log('========================================');
  Logger.log('Total ativos: ' + dados.total);
  Logger.log('Stats: ' + JSON.stringify(dados.stats));
  Logger.log('Raiz: ' + dados.arvore.nome + ' (ID Pessoa ' + dados.arvore.idPessoa + ', cargo "' + dados.arvore.cargo + '", nível ' + dados.arvore.nivel + ')');
  Logger.log('Filhos diretos da raiz: ' + dados.arvore.children.length);
  if (dados.avisos && dados.avisos.orfaos.length > 0) {
    Logger.log('⚠ ATENÇÃO: ' + dados.avisos.orfaos.length + ' colaboradores com supervisor inexistente:');
    dados.avisos.orfaos.slice(0, 10).forEach(o => {
      Logger.log('  - ID Pessoa ' + o.idPessoa + ' (' + o.nome + ') → supervisor ' + o.supervisorIdInexistente + ' não encontrado');
    });
  }
  Logger.log('========================================');
}

function diagnosticarCargos() {
  const colaboradores = lerPlanilha();
  const porNivel = { diretoria: [], gerencia: [], supervisor: [], operacional: [] };

  colaboradores.forEach(c => {
    porNivel[c.nivel].push(c.cargo);
  });

  Logger.log('========== DIAGNÓSTICO POR NÍVEL ==========');
  ['diretoria', 'gerencia', 'supervisor', 'operacional'].forEach(nivel => {
    const cargosUnicos = Array.from(new Set(porNivel[nivel]));
    Logger.log(nivel.toUpperCase() + ' (' + porNivel[nivel].length + ' pessoas, ' + cargosUnicos.length + ' cargos diferentes):');
    cargosUnicos.sort().forEach(cg => Logger.log('  • ' + cg));
  });
  Logger.log('===========================================');
}
