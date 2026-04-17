// src/api.js
const BASE = '/api/proxy';

async function get(params) {
  const qs = new URLSearchParams(params).toString();
  const res = await fetch(`${BASE}?${qs}`);
  const data = await res.json();
  if (!data.ok && data.error) throw new Error(data.error);
  return data;
}

async function post(body) {
  const res = await fetch(BASE, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!data.ok && data.error) throw new Error(data.error);
  return data;
}

// Colaboradores — somente leitura da planilha de RH
export const carregarColaboradores = () =>
  get({ action: 'getColaboradores' });

// Escala — leitura e escrita
export const carregarEscala = (semana) =>
  get({ action: 'getEscala', semana });

export const salvarEscala = (semana, payload) =>
  post({ action: 'saveEscala', semana, ...payload });

// Férias — leitura e escrita (todos os períodos, não filtrado por semana)
export const carregarFerias = () =>
  get({ action: 'getFerias' });

export const salvarFerias = (ferias) =>
  post({ action: 'saveFerias', ferias });
