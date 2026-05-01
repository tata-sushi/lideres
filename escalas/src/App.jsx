import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { Download, Plus, X, UserPlus, ChevronLeft, ChevronRight, Printer, Save } from 'lucide-react';
import { carregarEscala, salvarEscala, carregarColaboradores, carregarFerias, salvarFerias, salvarExtras } from './api.js';

// ============================================================
// DESIGN TOKENS
// ============================================================
const T = {
  bg:       '#F4F4F4',
  surface:  '#FFFFFF',
  carbon:   '#35383F',
  citric:   '#CFFF00',
  text:     '#111111',
  mid:      '#555555',
  muted:    '#999999',
  border:   '#E2E2E2',
  green:    '#1A5C2A',
  greenBg:  '#EAF4ED',
  amber:    '#7A4A00',
  amberBg:  '#FFF4DC',
  red:      '#7A1A1A',
  redBg:    '#FDEAEA',
  orange:   '#E8A020',
  orangeBg: '#FFF8EC',
  radius:   '8px',
  shadow:   '0 1px 4px rgba(0,0,0,0.07)',
};

const LOGO_SRC = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAgAAAQABAAD/wAARCAL0AvQDACIAAREBAhEB/9sAQwAIBgYHBgUIBwcHCQkICgwUDQwLCwwZEhMPFB0aHx4dGhwcICQuJyAiLCMcHCg3KSwwMTQ0NB8nOT04MjwuMzQy/9sAQwEJCQkMCwwYDQ0YMiEcITIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMAAAERAhEAPwD36iiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKAFooooASiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigBaKKKAEooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKAFooooASiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigBKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAWiiigD/2Q==";

// ============================================================
// CONSTANTES
// ============================================================
const DIAS_SEMANA = ['seg','ter','qua','qui','sex','sab','dom'];
const DIAS_META = [
  { id:'seg', nome:'Segunda', curto:'SEG', mini:'S' },
  { id:'ter', nome:'Terça',   curto:'TER', mini:'T' },
  { id:'qua', nome:'Quarta',  curto:'QUA', mini:'Q' },
  { id:'qui', nome:'Quinta',  curto:'QUI', mini:'Q' },
  { id:'sex', nome:'Sexta',   curto:'SEX', mini:'S' },
  { id:'sab', nome:'Sábado',  curto:'SAB', mini:'S' },
  { id:'dom', nome:'Domingo', curto:'DOM', mini:'D' },
];

const FUNCOES = ['Maître','Chefe de Fila','Garçom','Cumim','Aprendiz','Sommelier','Host','Barman','Auxiliar','Outro'];

const CORES_POOL = [
  '#35383F','#2A6B35','#2A4A7A','#8B2A1A','#6B2E5F',
  '#2C5F6B','#8B4A1A','#4A6B2A','#6B2A3C','#4A3A6B',
];

const COLABS0 = [
  {id:'c1', nome:'Maître',          funcao:'Maître',        unidade:'Itaim', depto:'Salão', cor:CORES_POOL[0]},
  {id:'c2', nome:'Chefe de Fila A', funcao:'Chefe de Fila', unidade:'Itaim', depto:'Salão', cor:CORES_POOL[1]},
  {id:'c3', nome:'Chefe de Fila B', funcao:'Chefe de Fila', unidade:'Itaim', depto:'Salão', cor:CORES_POOL[2]},
  {id:'c4', nome:'Garçom 1',        funcao:'Garçom',        unidade:'Itaim', depto:'Salão', cor:CORES_POOL[3]},
  {id:'c5', nome:'Garçom 2',        funcao:'Garçom',        unidade:'Itaim', depto:'Salão', cor:CORES_POOL[4]},
  {id:'c6', nome:'Garçom 3',        funcao:'Garçom',        unidade:'Itaim', depto:'Salão', cor:CORES_POOL[5]},
  {id:'c7', nome:'Garçom 4',        funcao:'Garçom',        unidade:'Itaim', depto:'Salão', cor:CORES_POOL[6]},
  {id:'c8', nome:'Cumim 1',         funcao:'Cumim',         unidade:'Itaim', depto:'Salão', cor:CORES_POOL[7]},
  {id:'c9', nome:'Cumim 2',         funcao:'Cumim',         unidade:'Itaim', depto:'Salão', cor:CORES_POOL[8]},
  {id:'c10',nome:'Aprendiz',        funcao:'Aprendiz',      unidade:'Itaim', depto:'Salão', cor:CORES_POOL[9]},
];

const CFG0_DIA = {
  prepAlmocoIni:'10:00', prepAlmocoFim:'12:00',
  funcAlmocoIni:'12:00', funcAlmocoFim:'15:00',
  prepJantarIni:'17:00', prepJantarFim:'19:00',
  funcJantarIni:'19:00', funcJantarFim:'00:00',
};
const CFG0 = Object.fromEntries(DIAS_SEMANA.map(d=>[d,{...CFG0_DIA}]));

const META_HORAS = 40;

const PRESETS_BASE = [
  { label:'Dobra',         turnos:[['10:00','15:00'],['18:00','00:00']] },
  { label:'Almoço',        turnos:[['10:00','15:00']] },
  { label:'Jantar',        turnos:[['18:00','00:00']] },
  { label:'Jantar Sex/Sáb',turnos:[['18:00','01:00']] },
  { label:'Dobra Sábado',  turnos:[['12:00','16:00'],['18:00','01:00']] },
  { label:'Domingo',       turnos:[['12:00','16:00'],['18:00','00:00']] },
];

// ============================================================
// HELPERS DE SLOT (Grade Visual)
// ============================================================
const HORA_INICIO = 7;
const HORA_FIM    = 26;
const SLOT_MIN    = 30;
const TOTAL_SLOTS = ((HORA_FIM - HORA_INICIO) * 60) / SLOT_MIN;

const slotLabel = (slot) => {
  const m = HORA_INICIO * 60 + slot * SLOT_MIN;
  return `${String(Math.floor(m/60)%24).padStart(2,'0')}:${String(m%60).padStart(2,'0')}`;
};

const horaSlot = (hhmm) => {
  if (!hhmm || !hhmm.includes(':')) return null;
  const [h,m] = hhmm.split(':').map(Number);
  if (isNaN(h)||isNaN(m)) return null;
  const ha = h < HORA_INICIO ? h+24 : h;
  const s = Math.floor(((ha-HORA_INICIO)*60+m)/SLOT_MIN);
  return (s<0||s>TOTAL_SLOTS)?null:s;
};

const turnoSlots = (t) => {
  const s = new Set();
  if (!t||t.folga) return s;
  const add = (ini,fim) => {
    const a=horaSlot(ini),b=horaSlot(fim);
    if (a==null||b==null||b<=a) return;
    for (let i=a;i<b;i++) s.add(i);
  };
  if (t.t1Ini&&t.t1Fim) add(t.t1Ini,t.t1Fim);
  if (t.t2Ini&&t.t2Fim) add(t.t2Ini,t.t2Fim);
  if (t.t3Ini&&t.t3Fim) add(t.t3Ini,t.t3Fim);
  return s;
};

const horasTurno = (t) => (turnoSlots(t).size*SLOT_MIN)/60;

const emFaixa = (slot,ini,fim) => {
  const a=horaSlot(ini),b=horaSlot(fim);
  return a!=null&&b!=null&&slot>=a&&slot<b;
};

// ============================================================
// HELPERS DE DATA
// ============================================================
const getSegunda = (date) => {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day===0 ? -6 : 1-day;
  d.setDate(d.getDate()+diff);
  d.setHours(0,0,0,0);
  return d;
};
const addDays = (date,n) => { const d=new Date(date); d.setDate(d.getDate()+n); return d; };
const fmtDate = (date) => date.toLocaleDateString('pt-BR',{day:'2-digit',month:'2-digit'});
const semanaLabel = (segunda) => `${fmtDate(segunda)} – ${fmtDate(addDays(segunda,6))}`;
const semanaKey = (segunda) => segunda.toISOString().slice(0,10);

// ============================================================
// HELPERS DE TURNO
// ============================================================
const toHHMM = (v) => {
  if (v == null || v === '') return '';
  const s = String(v);
  if (/^\d{1,2}:\d{2}$/.test(s)) return s;
  const m = s.match(/T(\d{2}):(\d{2})/);
  if (m) return `${m[1]}:${m[2]}`;
  return s;
};

const calcHoras = (t) => {
  if (!t || t.folga) return 0;
  let total = 0;
  const calc = (ini, fim) => {
    if (!ini || !fim) return 0;
    const [h1,m1] = ini.split(':').map(Number);
    const [h2,m2] = fim.split(':').map(Number);
    let ha = h2 < h1 ? h2+24 : h2;
    return (ha + m2/60) - (h1 + m1/60);
  };
  if (t.t1Ini && t.t1Fim) total += calc(t.t1Ini, t.t1Fim);
  if (t.t2Ini && t.t2Fim) total += calc(t.t2Ini, t.t2Fim);
  if (t.t3Ini && t.t3Fim) total += calc(t.t3Ini, t.t3Fim);
  return total;
};

const turnoVazio = () => ({t1Ini:'',t1Fim:'',t2Ini:'',t2Fim:'',t3Ini:'',t3Fim:'',folga:false});

const escalaVaziaColabs = (colabs) => {
  const e = {};
  DIAS_SEMANA.forEach(d => {
    e[d] = {};
    colabs.forEach(c => { e[d][c.id] = turnoVazio(); });
  });
  return e;
};

const escalaComColab = (esc, nc) => {
  const e = {...esc};
  DIAS_SEMANA.forEach(d => { e[d] = {...e[d], [nc.id]: turnoVazio()}; });
  return e;
};

const escalaSemColab = (esc, cid) => {
  const e = {};
  DIAS_SEMANA.forEach(d => { e[d] = {...esc[d]}; delete e[d][cid]; });
  return e;
};

// ============================================================
// COMPONENTE: Célula de turno editável
// ============================================================
function CelulaTurno({ turno, onChange, deFerias, onVacationClick }) {
  const [dropOpen, setDropOpen] = useState(false);
  const [showT2, setShowT2] = useState(!!(turno?.t2Ini || turno?.t2Fim));
  const [showT3, setShowT3] = useState(!!(turno?.t3Ini || turno?.t3Fim));

  const t = turno || turnoVazio();
  const estado = deFerias ? 'ferias' : t.folga ? 'folga' : 'turno';

  // Sincroniza visibilidade de T2/T3 quando preset é aplicado ou turno é limpo externamente
  useEffect(() => {
    if (t.t2Ini || t.t2Fim) setShowT2(true);
    else if (!t.t2Ini && !t.t2Fim && !t.t3Ini && !t.t3Fim) setShowT2(false);
    if (t.t3Ini || t.t3Fim) setShowT3(true);
    else if (!t.t3Ini && !t.t3Fim) setShowT3(false);
  }, [t.t2Ini, t.t2Fim, t.t3Ini, t.t3Fim]);

  const temT2 = showT2;
  const temT3 = showT3 && showT2;
  const noMax = temT3;

  const setEstado = (e) => {
    if (e === 'folga') onChange({...turnoVazio(), folga: true});
    else if (e === 'turno') onChange(turnoVazio());
  };

  const setField = (campo, val) => onChange({...t, [campo]: val, folga: false});

  const addTurno = () => {
    if (!showT2) setShowT2(true);
    else if (!showT3) setShowT3(true);
  };

  const rmTurno = () => {
    if (showT3) { setShowT3(false); onChange({...t, t3Ini:'', t3Fim:''}); }
    else if (showT2) { setShowT2(false); onChange({...t, t2Ini:'', t2Fim:'', t3Ini:'', t3Fim:''}); }
  };

  const aplicarPreset = (preset) => {
    const novo = turnoVazio();
    preset.turnos.forEach(([ini,fim], i) => {
      if (i===0) { novo.t1Ini=ini; novo.t1Fim=fim; }
      if (i===1) { novo.t2Ini=ini; novo.t2Fim=fim; }
      if (i===2) { novo.t3Ini=ini; novo.t3Fim=fim; }
    });
    onChange(novo);
    setDropOpen(false);
  };

  const limpar = () => { onChange(turnoVazio()); setDropOpen(false); };

  if (estado === 'ferias') {
    return (
      <div className="esc-cell">
        <div className="esc-top-row">
          <button className="esc-tog" onClick={()=>setEstado('turno')}>T</button>
          <button className="esc-tog" onClick={()=>{setEstado('turno');setDropOpen(true);}}>▾</button>
          <button className="esc-tog" onClick={()=>setEstado('folga')}>F</button>
          <button className="esc-tog" onClick={onVacationClick} title="Gerenciar férias">V</button>
          <button className="esc-tog" onClick={()=>setEstado('turno')}>+</button>
        </div>
        <div className="esc-badge-v">Férias</div>
      </div>
    );
  }

  if (estado === 'folga') {
    return (
      <div className="esc-cell">
        <div className="esc-top-row">
          <button className="esc-tog" onClick={()=>setEstado('turno')}>T</button>
          <button className="esc-tog" onClick={()=>{setEstado('turno');setDropOpen(true);}}>▾</button>
          <button className="esc-tog" onClick={()=>setEstado('folga')}>F</button>
          <button className="esc-tog" onClick={onVacationClick} title="Gerenciar férias">V</button>
          <button className="esc-tog" onClick={()=>setEstado('turno')}>+</button>
        </div>
        <div className="esc-badge-f">Folga</div>
      </div>
    );
  }

  return (
    <div className="esc-cell" style={{position:'relative'}}>
      <div className="esc-top-row">
        <button className="esc-tog" onClick={()=>setEstado('turno')}>T</button>
        <button className="esc-tog" onClick={()=>setDropOpen(p=>!p)} title="Presets de horário">
          {dropOpen ? '▴' : '▾'}
        </button>
        <button className="esc-tog" onClick={()=>setEstado('folga')}>F</button>
        <button className="esc-tog" onClick={onVacationClick} title="Gerenciar férias">V</button>
        <button className="esc-tog"
          onClick={noMax ? rmTurno : addTurno}
          title={noMax ? 'Remover último turno' : 'Adicionar turno'}>
          {noMax ? '−' : '+'}
        </button>
      </div>

      <div className="esc-inputs-row">
        <input type="time" value={t.t1Ini||''} onChange={e=>setField('t1Ini',e.target.value)}/>
        <span className="esc-sep">–</span>
        <input type="time" value={t.t1Fim||''} onChange={e=>setField('t1Fim',e.target.value)}/>
      </div>

      {temT2 && (
        <div className="esc-inputs-row">
          <input type="time" value={t.t2Ini||''} onChange={e=>setField('t2Ini',e.target.value)}/>
          <span className="esc-sep">–</span>
          <input type="time" value={t.t2Fim||''} onChange={e=>setField('t2Fim',e.target.value)}/>
        </div>
      )}

      {temT3 && (
        <div className="esc-inputs-row">
          <input type="time" value={t.t3Ini||''} onChange={e=>setField('t3Ini',e.target.value)}/>
          <span className="esc-sep">–</span>
          <input type="time" value={t.t3Fim||''} onChange={e=>setField('t3Fim',e.target.value)}/>
        </div>
      )}

      {dropOpen && (
        <div className="esc-dropdown">
          {PRESETS_BASE.map((p,i) => (
            <div key={i} className="esc-dd-item" onClick={()=>aplicarPreset(p)}>
              <span className="esc-dd-label">{p.label}</span>
              <span className="esc-dd-hours">{p.turnos.map(([a,b])=>`${a.replace(':00','')}–${b.replace(':00','')}`).join(' + ')}</span>
            </div>
          ))}
          <div className="esc-dd-sep"/>
          <div className="esc-dd-item" onClick={limpar}>
            <span className="esc-dd-label">Limpar</span>
            <span className="esc-dd-hours">remover tudo</span>
          </div>
        </div>
      )}
    </div>
  );
}

// ============================================================
// COMPONENTE: Célula colapsada (resumo)
// ============================================================
function CelulaColapsada({ turno, deFerias }) {
  if (deFerias) return <div className="esc-collapsed"><span className="esc-c-ferias">Férias</span></div>;
  if (!turno) return <div className="esc-collapsed"><span className="esc-c-muted">—</span></div>;
  if (turno.folga) return <div className="esc-collapsed"><span className="esc-c-folga">Folga</span></div>;
  const h = calcHoras(turno);
  if (h === 0) return <div className="esc-collapsed"><span className="esc-c-muted">—</span></div>;
  return <div className="esc-collapsed"><span className="esc-c-horas">{h.toFixed(0)}h</span></div>;
}

// ============================================================
// COMPONENTE: Modal de Férias
// ============================================================
function ModalFerias({ colab, ferias, onClose, onAdd, onRemove }) {
  const [ini, setIni] = useState('');
  const [fim, setFim] = useState('');
  const [obs, setObs] = useState('');

  if (!colab) return null;

  const periodos = ferias.filter(f => f.colabId === colab.id);

  const handleAdd = () => {
    if (!ini || !fim) return;
    onAdd(colab.id, { dataIni: ini, dataFim: fim, obs });
    setIni(''); setFim(''); setObs('');
  };

  return (
    <div className="esc-modal-overlay" onClick={onClose}>
      <div className="esc-modal" onClick={e=>e.stopPropagation()}>
        <div className="esc-modal-header">
          <div>
            <div className="esc-modal-title">🏖 Férias</div>
            <div className="esc-modal-sub">{colab.nome} · {colab.funcao}</div>
          </div>
          <button className="esc-modal-close" onClick={onClose}><X size={14}/></button>
        </div>

        <div className="esc-modal-body">
          <div className="esc-modal-section-label">Períodos cadastrados</div>
          {periodos.length === 0 ? (
            <div className="esc-modal-empty">Nenhum período de férias cadastrado</div>
          ) : (
            <div className="esc-modal-list">
              {periodos.map(f => (
                <div key={f.id} className="esc-modal-period">
                  <div>
                    <div className="esc-modal-period-dates">
                      {f.dataIni.split('-').reverse().join('/')} → {f.dataFim.split('-').reverse().join('/')}
                    </div>
                    {f.obs && <div className="esc-modal-period-obs">{f.obs}</div>}
                  </div>
                  <button className="esc-modal-period-del" onClick={()=>onRemove(f.id)}><X size={11}/></button>
                </div>
              ))}
            </div>
          )}

          <div className="esc-modal-section-label" style={{marginTop:14}}>Novo período</div>
          <div className="esc-modal-form">
            <div className="esc-modal-row-2">
              <div>
                <label className="esc-field-label">Início</label>
                <input className="esc-input" type="date" value={ini} onChange={e=>setIni(e.target.value)}/>
              </div>
              <div>
                <label className="esc-field-label">Fim</label>
                <input className="esc-input" type="date" value={fim} onChange={e=>setFim(e.target.value)}/>
              </div>
            </div>
            <input className="esc-input" type="text" placeholder="Observação (opcional)"
              value={obs} onChange={e=>setObs(e.target.value)} style={{marginTop:8}}/>
            <button className="btn-dev" onClick={handleAdd}
              disabled={!ini||!fim}
              style={{width:'100%',justifyContent:'center',marginTop:10,background:'#1A3A5C',color:'#fff',opacity:(!ini||!fim)?.5:1,cursor:(!ini||!fim)?'not-allowed':'pointer'}}>
              <Plus size={11}/>Adicionar período
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ============================================================
// COMPONENTE PRINCIPAL
// ============================================================
export default function EscalaPainel() {
  const [colabs, setColabs] = useState(COLABS0);
  const [semanaAtual, setSemanaAtual] = useState(() => getSegunda(new Date()));
  const [dados, setDados] = useState(() => {
    const key = semanaKey(getSegunda(new Date()));
    return { [key]: { config: CFG0, escala: escalaVaziaColabs(COLABS0) } };
  });
  const [syncStatus, setSyncStatus] = useState('idle');
  const [pendente, setPendente] = useState(false);
  const [expandidos, setExpandidos] = useState({});
  const [ferias, setFerias] = useState([]);
  const [feriasModalColab, setFeriasModalColab] = useState(null);
  const [mostrarAdd, setMostrarAdd] = useState(false);
  const [novoNome, setNovoNome] = useState('');
  const [novoFunc, setNovoFunc] = useState('Garçom');
  const [novoUnidade, setNovoUnidade] = useState('Itaim');
  const [novoDepto, setNovoDepto] = useState('Salão');
  const [filtroUnidade, setFiltroUnidade] = useState(()=>localStorage.getItem('esc_fUnidade')||'Todos');
  const [filtroDepto, setFiltroDepto] = useState(()=>localStorage.getItem('esc_fDepto')||'Todos');
  const [gradeAberta, setGradeAberta] = useState(false);
  const [tabelaAberta, setTabelaAberta] = useState(true);
  const [resumoAberto, setResumoAberto] = useState(true);
  const [diaGradeIdx, setDiaGradeIdx] = useState(0);
  const [ehMobile, setEhMobile] = useState(false);

  const key = semanaKey(semanaAtual);

  useEffect(()=>{ localStorage.setItem('esc_fUnidade', filtroUnidade); },[filtroUnidade]);
  useEffect(()=>{ localStorage.setItem('esc_fDepto', filtroDepto); },[filtroDepto]);

  useEffect(()=>{
    const fn = ()=>setEhMobile(window.innerWidth<900);
    fn(); window.addEventListener('resize', fn);
    return ()=>window.removeEventListener('resize', fn);
  },[]);

  // Carregar colaboradores + férias
  useEffect(()=>{
    carregarColaboradores()
      .then(({ colabs: loaded }) => {
        if (loaded && loaded.length > 0) setColabs(loaded);
        return carregarFerias();
      })
      .then(data => { if (data && data.ferias) setFerias(data.ferias); })
      .catch(() => {});
  },[]);

  // Carregar escala da semana
  useEffect(()=>{
    setPendente(false);
    setSyncStatus('loading');
    carregarEscala(key)
      .then(({ escala: escLoaded, config: cfgLoaded }) => {
        const base = {};
        DIAS_SEMANA.forEach(dia => {
          const diaData = escLoaded?.[dia] || {};
          base[dia] = {};
          Object.entries(diaData).forEach(([cid, t]) => {
            base[dia][cid] = {
              t1Ini: toHHMM(t?.t1Ini), t1Fim: toHHMM(t?.t1Fim),
              t2Ini: toHHMM(t?.t2Ini), t2Fim: toHHMM(t?.t2Fim),
              t3Ini: toHHMM(t?.t3Ini), t3Fim: toHHMM(t?.t3Fim),
              folga: !!t?.folga,
            };
          });
        });
        setDados(p => ({ ...p, [key]: { config: cfgLoaded || CFG0, escala: base } }));
        setSyncStatus('idle');
      })
      .catch(() => {
        setSyncStatus('load-error');
        setTimeout(() => setSyncStatus('idle'), 4000);
      });
  },[key]);

  const semDados = dados[key] || {config:CFG0, escala:escalaVaziaColabs(colabs)};
  const config = semDados.config;
  const escala = semDados.escala;

  const setEscala = (novaEscala) => {
    setDados(p=>({...p,[key]:{...p[key],escala:novaEscala}}));
    setPendente(true);
  };

  const setTurnoCell = (dia, cid, novoTurno) => {
    setEscala({...escala, [dia]: {...escala[dia], [cid]: novoTurno}});
  };

  // Férias
  const estaDeFerias = useCallback((colabId, data) => {
    const d = data.getTime();
    return ferias.some(f => {
      if (f.colabId !== colabId) return false;
      const ini = new Date(f.dataIni + 'T00:00:00').getTime();
      const fim = new Date(f.dataFim + 'T23:59:59').getTime();
      return d >= ini && d <= fim;
    });
  }, [ferias]);

  const dataDoDia = useCallback((diaId) => {
    const idx = DIAS_META.findIndex(d => d.id === diaId);
    return addDays(semanaAtual, idx);
  }, [semanaAtual]);

  const adicionarFerias = (colabId, { dataIni, dataFim, obs }) => {
    const novo = { id: `f_${Date.now()}`, colabId, dataIni, dataFim, obs: obs || '' };
    const novas = [...ferias, novo];
    setFerias(novas);
    salvarFerias(novas).catch(() => {});
  };

  const removerFerias = (fId) => {
    const novas = ferias.filter(f => f.id !== fId);
    setFerias(novas);
    salvarFerias(novas).catch(() => {});
  };

  // Salvar
  const salvarManual = useCallback(async () => {
    const semD = dados[key] || {config:CFG0, escala:escalaVaziaColabs(colabs)};
    setSyncStatus('saving');
    try {
      await salvarEscala(key, { escala: semD.escala, config: semD.config });
      setSyncStatus('saved');
      setPendente(false);
      setTimeout(() => setSyncStatus('idle'), 2000);
    } catch {
      setSyncStatus('error');
      setTimeout(() => setSyncStatus('idle'), 3000);
    }
  }, [key, dados, colabs]);

  // Navegação
  const navSemana = (delta) => setSemanaAtual(p=>addDays(p,delta*7));

  // Adicionar/remover colaborador
  const adicionarColab = () => {
    if (!novoNome.trim()) return;
    const usadas = colabs.map(c=>c.cor);
    const cor = CORES_POOL.find(c=>!usadas.includes(c))||CORES_POOL[colabs.length%CORES_POOL.length];
    const nc = {id:`extra_${Date.now()}`,nome:novoNome.trim(),funcao:novoFunc,unidade:novoUnidade,depto:novoDepto,cor,extra:true};
    const novosColabs = [...colabs,nc];
    setColabs(novosColabs);
    const extras = novosColabs.filter(c=>c.extra).map(c=>({id:c.id,nome:c.nome,funcao:c.funcao,unidade:c.unidade,depto:c.depto}));
    salvarExtras(extras).catch(()=>{});
    setDados(p=>{
      const novo={...p};
      Object.keys(novo).forEach(k=>{ novo[k]={...novo[k],escala:escalaComColab(novo[k].escala,nc)}; });
      return novo;
    });
    setNovoNome(''); setMostrarAdd(false);
  };

  const removerColab = (cid) => {
    const alvo = colabs.find(c=>c.id===cid);
    if (!confirm(`Remover ${alvo?.nome || 'colaborador'} de toda a escala?`)) return;
    const novosColabs = colabs.filter(c=>c.id!==cid);
    setColabs(novosColabs);
    setDados(p=>{
      const novo={};
      Object.keys(p).forEach(k=>{ novo[k]={...p[k],escala:escalaSemColab(p[k].escala,cid)}; });
      return novo;
    });
    if (alvo?.extra) {
      const extras = novosColabs.filter(c=>c.extra).map(c=>({id:c.id,nome:c.nome,funcao:c.funcao,unidade:c.unidade,depto:c.depto}));
      salvarExtras(extras).catch(()=>{});
    }
  };

  // Filtros
  const unidadesOpts = useMemo(()=>{
    const vals = [...new Set(colabs.map(c=>c.unidade).filter(Boolean))].sort();
    return ['Todos', ...vals];
  }, [colabs]);

  const deptosOpts = useMemo(()=>{
    const fonte = filtroUnidade==='Todos' ? colabs : colabs.filter(c=>c.unidade===filtroUnidade);
    const vals = [...new Set(fonte.map(c=>c.depto).filter(Boolean))].sort();
    return ['Todos', ...vals];
  }, [colabs, filtroUnidade]);

  const colabsFiltrados = useMemo(()=>colabs.filter(c=>{
    if (filtroUnidade!=='Todos'&&c.unidade!==filtroUnidade) return false;
    if (filtroDepto!=='Todos'&&c.depto!==filtroDepto) return false;
    return true;
  }),[colabs,filtroUnidade,filtroDepto]);

  // Stats
  const stats = useMemo(()=>{
    const s = {};
    colabs.forEach(c => {
      let h=0, td=0, fd=0;
      DIAS_META.forEach(d => {
        const t = escala[d.id]?.[c.id];
        if (!t) return;
        if (t.folga) fd++;
        else { const ht = calcHoras(t); if(ht>0){h+=ht;td++;} }
      });
      s[c.id] = {horas:h, dias:td, folgas:fd};
    });
    return s;
  },[escala,colabs]);

  const totalSemana = Object.values(stats).reduce((a,b)=>a+b.horas,0);

  const totalDia = (diaId) => {
    return colabsFiltrados.reduce((a,c) => a + calcHoras(escala[diaId]?.[c.id]||{}), 0);
  };

  const countsDia = (diaId, idx) => {
    let trab=0, folga=0, ferias=0;
    colabsFiltrados.forEach(c => {
      const dataD = addDays(semanaAtual, idx);
      if (estaDeFerias(c.id, dataD)) { ferias++; return; }
      const t = escala[diaId]?.[c.id];
      if (t?.folga) folga++;
      else if (calcHoras(t||{}) > 0) trab++;
    });
    return { trab, folga, ferias };
  };

  // Grade visual
  const diaGrade = DIAS_META[diaGradeIdx];
  const cfgGrade = config[diaGrade.id] || CFG0_DIA;
  const colW = ehMobile ? 72 : 108;
  const rowH = 12;

  // Toggle expandir/recolher
  const toggleExpand = (cid) => setExpandidos(p=>({...p,[cid]:!p[cid]}));
  const isExpanded = (cid) => expandidos[cid] !== false;

  // Export CSV
  const exportCSV = () => {
    const L=[['Semana','Dia','Colaborador','Função','Unidade','Depto','T1 Entrada','T1 Saída','T2 Entrada','T2 Saída','T3 Entrada','T3 Saída','Horas','Folga'].join(';')];
    const sw = semanaLabel(semanaAtual);
    DIAS_META.forEach(d=>colabs.forEach(c=>{
      const t = escala[d.id]?.[c.id]||{};
      L.push([sw,d.nome,c.nome,c.funcao,c.unidade,c.depto,t.t1Ini||'',t.t1Fim||'',t.t2Ini||'',t.t2Fim||'',t.t3Ini||'',t.t3Fim||'',calcHoras(t).toFixed(1),t.folga?'FOLGA':''].join(';'));
    }));
    const a=document.createElement('a');
    a.href=URL.createObjectURL(new Blob([L.join('\n')],{type:'text/csv;charset=utf-8'}));
    a.download=`escala_5x2_${key}.csv`;
    a.click();
  };

  // Print
  const gerarPDF = () => {
    const semLabel=semanaLabel(semanaAtual);
    const dataHoje=new Date().toLocaleString('pt-BR');
    const thDias=DIAS_META.map((d,i)=>{
      const dataD=addDays(semanaAtual,i);
      return `<th>${d.curto}<br><span class="epdf-th-data">${fmtDate(dataD)}</span></th>`;
    }).join('');
    const rows=colabsFiltrados.map((c,idx)=>{
      const tdDias=DIAS_META.map((d,i)=>{
        const t=escala[d.id]?.[c.id]||{};
        const dataD=addDays(semanaAtual,i);
        const df=estaDeFerias(c.id,dataD);
        if(df) return `<td class="epdf-ferias">FÉRIAS</td>`;
        if(t.folga) return `<td class="epdf-folga">FOLGA</td>`;
        if(!t.t1Ini) return `<td class="epdf-livre">—</td>`;
        let txt=`${t.t1Ini}–${t.t1Fim}`;
        if(t.t2Ini&&t.t2Fim) txt+=`<br><span class="epdf-t2">${t.t2Ini}–${t.t2Fim}</span>`;
        if(t.t3Ini&&t.t3Fim) txt+=`<br><span class="epdf-t2">${t.t3Ini}–${t.t3Fim}</span>`;
        return `<td class="epdf-turno">${txt}</td>`;
      }).join('');
      const s=stats[c.id]||{horas:0};
      const par=idx%2===0?'':' class="epdf-row-alt"';
      return `<tr${par}><td class="epdf-nome">${c.nome}</td><td class="epdf-fn">${c.funcao}</td>${tdDias}<td class="epdf-total">${s.horas.toFixed(1)}h</td></tr>`;
    }).join('');
    let printDiv=document.getElementById('escala-pdf-print');
    if(!printDiv){ printDiv=document.createElement('div'); printDiv.id='escala-pdf-print'; document.body.appendChild(printDiv); }
    printDiv.innerHTML=`
      <div class="epdf-header">
        <img id="epdf-logo" class="epdf-logo" alt="TATÁ Sushi">
        <div class="epdf-header-center">
          <div class="epdf-title">Escala Semanal</div>
          <div class="epdf-sub">${semLabel}</div>
        </div>
        <div class="epdf-header-right">Emitido em: ${dataHoje}</div>
      </div>
      <table class="epdf-table">
        <thead><tr><th class="epdf-th-nome">Colaborador</th><th class="epdf-th-fn">Função</th>${thDias}<th>Total</th></tr></thead>
        <tbody>${rows}</tbody>
        <tfoot><tr><td colspan="2" class="epdf-tf-label">TOTAL GERAL</td><td colspan="7"></td><td class="epdf-tf-val">${totalSemana.toFixed(1)}h</td></tr></tfoot>
      </table>
      <div class="epdf-rodape">${colabsFiltrados.length} colaboradores · Meta: ${META_HORAS}h / semana</div>`;
    const logoEl=document.getElementById('epdf-logo');
    logoEl.onload=()=>window.print();
    logoEl.onerror=()=>window.print();
    logoEl.src=LOGO_SRC;
  };

  const hoje = new Date().toLocaleString('pt-BR');

  const FiltroSelect=({label,val,set,opts})=>(
    <div style={{display:'flex',flexDirection:'column',gap:4}}>
      <label className="esc-field-label">{label}</label>
      <select value={val} onChange={e=>set(e.target.value)} className="esc-select-filtro">
        {opts.map(o=><option key={o}>{o}</option>)}
      </select>
    </div>
  );

  const colabFeriasModal = feriasModalColab ? colabs.find(c=>c.id===feriasModalColab) : null;

  return (
    <div className="esc-root">
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Mono:wght@400;500;600&display=swap');
        *{box-sizing:border-box;margin:0;padding:0;}

        .esc-root{font-family:'DM Sans',sans-serif;background:${T.bg};min-height:100vh;color:${T.text};font-size:14px;padding-bottom:60px;}

        .btn-dev{font-family:'DM Mono',monospace;font-size:10px;font-weight:500;letter-spacing:.5px;text-transform:uppercase;padding:8px 14px;background:${T.carbon};color:${T.citric};border:none;border-radius:${T.radius};cursor:pointer;display:inline-flex;align-items:center;gap:6px;}
        .btn-dev:hover{opacity:.87;}
        .btn-outline{font-family:'DM Mono',monospace;font-size:10px;font-weight:500;letter-spacing:.5px;text-transform:uppercase;padding:8px 14px;background:${T.surface};color:${T.mid};border:1px solid ${T.border};border-radius:${T.radius};cursor:pointer;display:inline-flex;align-items:center;gap:6px;}
        .btn-outline:hover{background:${T.bg};}
        .btn-icon{background:${T.surface};border:1px solid ${T.border};border-radius:${T.radius};width:34px;height:34px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:${T.mid};}
        .btn-icon:hover{background:${T.bg};}

        .esc-field-label{font-family:'DM Mono',monospace;font-size:10px;font-weight:500;letter-spacing:.8px;text-transform:uppercase;color:${T.mid};}
        .esc-select-filtro{appearance:none;background:${T.bg} url("data:image/svg+xml,%3Csvg width='12' height='8' viewBox='0 0 12 8' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L6 7L11 1' stroke='%23555' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") no-repeat right 12px center;border:1px solid ${T.border};border-radius:${T.radius};padding:10px 36px 10px 14px;font-family:'DM Sans',sans-serif;font-size:14px;color:${T.text};cursor:pointer;width:100%;outline:none;}
        .esc-input{font-family:'DM Mono',monospace;font-size:13px;padding:8px 10px;border:1px solid ${T.border};background:${T.bg};color:${T.carbon};width:100%;border-radius:${T.radius};outline:none;}
        .esc-input:focus{border-color:${T.carbon};}
        .esc-select-sm{font-family:'DM Sans',sans-serif;font-size:13px;padding:8px 10px;border:1px solid ${T.border};background:${T.bg};color:${T.carbon};width:100%;border-radius:${T.radius};outline:none;appearance:none;}

        .card{background:${T.surface};border:1px solid ${T.border};border-radius:${T.radius};box-shadow:${T.shadow};overflow:hidden;}
        .cat-pill{display:inline-flex;align-items:center;padding:3px 10px;background:#F0F0F0;border-radius:100px;font-family:'DM Mono',monospace;font-size:10px;font-weight:500;letter-spacing:.5px;text-transform:uppercase;color:${T.mid};}

        /* Tabela principal */
        .esc-table{width:100%;border-collapse:collapse;font-size:12px;}
        .esc-table th{font-family:'DM Mono',monospace;font-size:10px;font-weight:600;letter-spacing:.5px;color:${T.carbon};text-transform:uppercase;padding:8px 4px;border-bottom:1px solid ${T.border};text-align:center;vertical-align:bottom;white-space:nowrap;}
        .esc-table th:first-child{text-align:left;width:206px;min-width:206px;max-width:206px;}
        .esc-table th:not(:first-child):not(:last-child){width:auto;}
        .esc-table th:last-child{width:54px;min-width:54px;}
        .esc-table td{padding:5px 3px;border-bottom:1px solid ${T.border};vertical-align:top;text-align:center;}
        .esc-table td:first-child{text-align:left;vertical-align:top;padding-top:7px;width:206px;min-width:206px;max-width:206px;}
        .esc-table tbody tr:hover>td{background:rgba(0,0,0,.015);}
        .esc-th-date{font-size:9px;font-weight:400;color:${T.carbon};display:block;margin-top:1px;opacity:.7;}

        .esc-nome-wrap{display:flex;align-items:center;gap:4px;}
        .esc-chevron{width:18px;height:18px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:${T.muted};font-size:11px;flex-shrink:0;border:none;background:none;font-family:'DM Mono',monospace;}
        .esc-chevron:hover{color:${T.mid};}
        .esc-nome-info{display:flex;flex-direction:column;gap:1px;flex:1;min-width:0;}
        .esc-nome-c{font-size:12px;font-weight:700;color:${T.carbon};white-space:nowrap;overflow:hidden;text-overflow:ellipsis;letter-spacing:-.2px;}
        .esc-cargo-c{font-family:'DM Mono',monospace;font-size:9px;color:${T.muted};letter-spacing:.5px;text-transform:uppercase;}
        .esc-del-btn{width:18px;height:18px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:${T.muted};font-size:12px;flex-shrink:0;border:1px solid transparent;background:none;border-radius:${T.radius};font-family:'DM Mono',monospace;}
        .esc-del-btn:hover{color:${T.red};border-color:${T.border};}

        /* Célula de turno */
        .esc-cell{display:inline-flex;flex-direction:column;gap:3px;align-items:stretch;min-width:128px;position:relative;}
        .esc-table td:not(:first-child){vertical-align:middle;}
        .esc-top-row{display:flex;gap:1px;align-items:center;}
        .esc-tog{flex:1;font-size:9px;font-family:'DM Mono',monospace;padding:3px 0;border-radius:4px;border:1px solid ${T.border};background:${T.surface};color:${T.mid};cursor:pointer;text-align:center;}
        .esc-tog:hover{background:${T.bg};}
        .esc-tog-hidden{flex:1;visibility:hidden;border:1px solid transparent;background:transparent;cursor:default;}

        .esc-inputs-row{display:flex;gap:2px;align-items:center;width:100%;}
        .esc-inputs-row input[type=time]{flex:1;min-width:0;font-size:10px;font-family:'DM Mono',monospace;padding:3px 2px;border:1px solid ${T.border};border-radius:4px;background:${T.surface};color:${T.carbon};outline:none;}
        .esc-inputs-row input[type=time]:focus{border-color:${T.carbon};}
        .esc-sep{font-size:9px;color:${T.muted};flex-shrink:0;}

        .esc-badge-f{display:flex;align-items:center;justify-content:center;padding:6px 8px;border-radius:6px;background:${T.amberBg};color:${T.amber};font-family:'DM Mono',monospace;font-size:10px;font-weight:600;}
        .esc-badge-v{display:flex;align-items:center;justify-content:center;padding:6px 8px;border-radius:6px;background:#EBF3FA;color:#1A3A5C;font-family:'DM Mono',monospace;font-size:10px;font-weight:600;}

        /* Dropdown presets */
        .esc-dropdown{position:absolute;top:26px;left:0;z-index:50;background:${T.surface};border:1px solid ${T.border};border-radius:${T.radius};padding:4px;min-width:180px;box-shadow:0 4px 16px rgba(0,0,0,0.1);}
        .esc-dd-item{display:flex;align-items:center;justify-content:space-between;padding:6px 8px;border-radius:4px;cursor:pointer;font-size:11px;color:${T.text};gap:8px;}
        .esc-dd-item:hover{background:${T.bg};}
        .esc-dd-label{font-weight:600;}
        .esc-dd-hours{font-family:'DM Mono',monospace;font-size:9px;color:${T.muted};white-space:nowrap;}
        .esc-dd-sep{height:1px;background:${T.border};margin:3px 4px;}

        /* Colapsado */
        .esc-collapsed{font-family:'DM Mono',monospace;font-size:10px;padding:4px 0;}
        .esc-c-folga{color:${T.amber};font-weight:600;}
        .esc-c-ferias{color:#1A3A5C;font-weight:600;}
        .esc-c-horas{color:${T.carbon};font-weight:500;}
        .esc-c-muted{color:${T.muted};}

        .esc-total{font-family:'DM Mono',monospace;font-size:11px;font-weight:600;padding-top:7px!important;}
        .esc-total-ok{color:${T.green};}
        .esc-total-warn{color:${T.red};}
        .esc-total-muted{color:${T.muted};}

        .esc-footer td{border-bottom:none;font-family:'DM Mono',monospace;font-size:10px;font-weight:600;color:${T.mid};padding-top:8px!important;vertical-align:top;}

        /* Resumo Semanal */
        .resumo-card{display:flex;align-items:flex-start;gap:8px;padding:10px 12px;border:1px solid ${T.border};border-radius:6px;background:${T.bg};}
        .status-ok{background:${T.greenBg};color:${T.green};padding:3px 8px;border-radius:100px;font-family:'DM Mono',monospace;font-size:9px;font-weight:500;white-space:nowrap;}
        .status-crit{background:${T.redBg};color:${T.red};padding:3px 8px;border-radius:100px;font-family:'DM Mono',monospace;font-size:9px;font-weight:500;white-space:nowrap;}

        /* Modal */
        .esc-modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:200;display:flex;align-items:center;justify-content:center;padding:20px;}
        .esc-modal{background:${T.surface};border-radius:${T.radius};box-shadow:0 8px 32px rgba(0,0,0,.2);width:100%;max-width:480px;max-height:90vh;overflow:hidden;display:flex;flex-direction:column;}
        .esc-modal-header{padding:16px 20px;border-bottom:1px solid ${T.border};display:flex;align-items:center;justify-content:space-between;}
        .esc-modal-title{font-size:14px;font-weight:700;color:${T.carbon};letter-spacing:-.2px;}
        .esc-modal-sub{font-family:'DM Mono',monospace;font-size:10px;color:${T.muted};letter-spacing:.5px;text-transform:uppercase;margin-top:2px;}
        .esc-modal-close{width:28px;height:28px;border:1px solid ${T.border};background:transparent;border-radius:100px;cursor:pointer;color:${T.mid};display:flex;align-items:center;justify-content:center;}
        .esc-modal-close:hover{background:${T.bg};}
        .esc-modal-body{padding:16px 20px;overflow-y:auto;}
        .esc-modal-section-label{font-family:'DM Mono',monospace;font-size:10px;font-weight:600;letter-spacing:.8px;text-transform:uppercase;color:${T.mid};margin-bottom:8px;}
        .esc-modal-empty{font-family:'DM Mono',monospace;font-size:11px;color:${T.muted};padding:8px 0;}
        .esc-modal-list{display:flex;flex-direction:column;gap:6px;}
        .esc-modal-period{display:flex;align-items:center;justify-content:space-between;padding:8px 10px;background:#EBF3FA;border:1px solid #C8DFF0;border-radius:6px;}
        .esc-modal-period-dates{font-family:'DM Mono',monospace;font-size:11px;font-weight:600;color:#1A3A5C;}
        .esc-modal-period-obs{font-family:'DM Mono',monospace;font-size:9px;color:${T.muted};margin-top:2px;}
        .esc-modal-period-del{width:24px;height:24px;border:1px solid ${T.border};background:transparent;border-radius:100px;cursor:pointer;color:${T.mid};display:flex;align-items:center;justify-content:center;flex-shrink:0;}
        .esc-modal-period-del:hover{color:${T.red};border-color:${T.red};}
        .esc-modal-row-2{display:grid;grid-template-columns:1fr 1fr;gap:8px;}

        /* Grade visual */
        .grade-tabs{display:flex;gap:2px;padding:6px 16px;border-bottom:1px solid ${T.border};overflow-x:auto;}
        .grade-tab{font-family:'DM Mono',monospace;font-size:10px;font-weight:500;letter-spacing:1px;padding:8px 12px;background:transparent;border:none;border-bottom:2px solid transparent;cursor:pointer;color:${T.muted};white-space:nowrap;text-transform:uppercase;text-align:center;display:flex;flex-direction:column;align-items:center;gap:2px;}
        .grade-tab.on{color:${T.text};border-bottom-color:${T.carbon};}
        .hora-cell{height:${rowH}px;display:flex;align-items:flex-end;justify-content:center;font-family:'DM Mono',monospace;font-size:9px;line-height:1;padding:0 4px 1px;position:sticky;left:0;z-index:5;border-right:1px solid ${T.border};background:${T.surface};overflow:hidden;}

        input[type=time]::-webkit-calendar-picker-indicator{opacity:.5;cursor:pointer;}

        /* Print */
        #escala-pdf-print{display:none;}
        @media print{
          body>*:not(#escala-pdf-print){display:none!important;}
          #escala-pdf-print{display:block!important;font-family:'DM Sans','Helvetica Neue',Arial,sans-serif;color:#000;padding:24px 28px;max-width:960px;margin:0 auto;font-size:11px;-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important;}
          .epdf-header{display:flex;align-items:flex-start;gap:14px;margin-bottom:16px;padding-bottom:12px;border-bottom:2px solid #111;}
          .epdf-logo{width:48px;height:48px;object-fit:contain;flex-shrink:0;}
          .epdf-header-center{flex:1;}
          .epdf-title{font-size:14px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;}
          .epdf-sub{font-size:10px;color:#555;margin-top:3px;}
          .epdf-header-right{font-size:9px;color:#555;text-align:right;flex-shrink:0;align-self:center;}
          .epdf-table{width:100%;border-collapse:collapse;font-size:9.5px;margin-bottom:10px;}
          .epdf-table thead tr{background:#35383F!important;-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important;}
          .epdf-table th{padding:6px 5px;color:#fff!important;font-size:9px;text-transform:uppercase;letter-spacing:.04em;font-weight:600;text-align:center;}
          .epdf-th-nome{text-align:left;width:130px;}
          .epdf-th-fn{text-align:left;width:90px;}
          .epdf-th-data{font-weight:400;font-size:8px;opacity:.85;}
          .epdf-table td{padding:5px 5px;border-bottom:1px solid #eee;text-align:center;vertical-align:middle;}
          .epdf-nome,.epdf-fn{text-align:left;}
          .epdf-row-alt{background:#f9f9f9!important;-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important;}
          .epdf-folga{color:#b26200;font-weight:600;font-size:8.5px;}
          .epdf-ferias{color:#1A3A5C;font-weight:600;font-size:8.5px;}
          .epdf-livre{color:#bbb;}
          .epdf-turno{font-family:'DM Mono',monospace;font-size:8.5px;}
          .epdf-t2{font-size:7.5px;color:#666;}
          .epdf-total{font-family:'DM Mono',monospace;font-weight:700;font-size:9px;}
          .epdf-table tfoot td{border-top:2px solid #111;font-weight:700;padding:6px 5px;}
          .epdf-tf-label{text-align:left;font-size:9px;text-transform:uppercase;letter-spacing:.04em;}
          .epdf-tf-val{font-family:'DM Mono',monospace;font-size:11px;text-align:center;}
          .epdf-rodape{font-size:9px;color:#666;text-align:right;margin-top:6px;}
        }
      `}</style>

      {/* HEADER */}
      <header style={{background:T.surface,borderBottom:`1px solid ${T.border}`,padding:'14px 20px',display:'flex',alignItems:'center',gap:14,position:'sticky',top:0,zIndex:100}}>
        <img src={LOGO_SRC} alt="TATÁ Sushi" style={{width:40,height:40,objectFit:'contain',flexShrink:0}}/>
        <div style={{flex:1}}>
          <div style={{fontSize:20,fontWeight:700,color:T.carbon,letterSpacing:'-0.3px'}}>Escalas</div>
        </div>
        <div style={{display:'flex',alignItems:'center',gap:8,flexShrink:0}}>
          {syncStatus==='loading'&&<span style={{fontFamily:'DM Mono,monospace',fontSize:9,color:T.muted}}>⟳ Carregando...</span>}
          {syncStatus==='error'&&<span style={{fontFamily:'DM Mono,monospace',fontSize:9,color:T.red}}>✗ Erro ao salvar</span>}
          {syncStatus==='load-error'&&<span style={{fontFamily:'DM Mono,monospace',fontSize:9,color:T.red}}>✗ Erro ao carregar</span>}
          {syncStatus==='saved'&&!pendente&&<span style={{fontFamily:'DM Mono,monospace',fontSize:9,color:T.green}}>✓ Salvo</span>}
        </div>
      </header>

      {/* FILTROS */}
      <div style={{background:T.surface,borderBottom:`1px solid ${T.border}`,padding:'14px 20px'}}>
        <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
          <FiltroSelect label="Unidade" val={filtroUnidade} set={setFiltroUnidade} opts={unidadesOpts}/>
          <FiltroSelect label="Departamento" val={filtroDepto} set={setFiltroDepto} opts={deptosOpts}/>
        </div>
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginTop:10}}>
          <button onClick={()=>{setFiltroUnidade('Todos');setFiltroDepto('Todos');}} style={{fontFamily:'DM Mono,monospace',fontSize:10,letterSpacing:'.5px',color:T.muted,background:'none',border:'none',cursor:'pointer',textTransform:'uppercase',textDecoration:'underline',textUnderlineOffset:2}}>Limpar filtros</button>
          <span style={{fontFamily:'DM Mono,monospace',fontSize:12,color:T.text}}><b>{colabsFiltrados.length}</b> colaboradores</span>
        </div>
      </div>

      {/* NAVEGADOR DE SEMANA */}
      <div style={{background:T.surface,borderBottom:`1px solid ${T.border}`,padding:'10px 20px',display:'flex',alignItems:'center',gap:10}}>
        <button className="btn-icon" onClick={()=>navSemana(-1)}><ChevronLeft size={14}/></button>
        <div style={{flex:1,textAlign:'center'}}>
          <div style={{fontFamily:'DM Mono,monospace',fontSize:11,fontWeight:600,color:T.carbon,letterSpacing:'.5px'}}>
            {semanaLabel(semanaAtual)}
          </div>
          <div style={{fontFamily:'DM Mono,monospace',fontSize:9,color:T.muted,letterSpacing:'.5px',textTransform:'uppercase',marginTop:2}}>
            {(()=>{
              const h=new Date();h.setHours(0,0,0,0);
              const s=new Date(semanaAtual);s.setHours(0,0,0,0);
              const dom=addDays(s,6);dom.setHours(0,0,0,0);
              if(h>=s&&h<=dom) return '● Semana atual';
              if(s>h) return `→ ${Math.round((s-h)/86400000/7)} sem. à frente`;
              return `← ${Math.round((h-dom)/86400000/7)+1} sem. atrás`;
            })()}
          </div>
        </div>
        <button className="btn-icon" onClick={()=>navSemana(1)}><ChevronRight size={14}/></button>
        <button className="btn-outline" style={{padding:'6px 11px',fontSize:9.5}} onClick={()=>setSemanaAtual(getSegunda(new Date()))}>Hoje</button>
      </div>

      {/* AÇÕES */}
      <div style={{padding:'10px 20px',display:'flex',gap:8,flexWrap:'wrap',alignItems:'center',borderBottom:`1px solid ${T.border}`,background:T.bg}}>
        <button className="btn-outline" onClick={()=>setMostrarAdd(p=>!p)}><UserPlus size={11}/>+ Extra</button>
        <button className="btn-outline" onClick={gerarPDF}><Printer size={11}/>Imprimir</button>
        <button className="btn-outline" onClick={exportCSV}><Download size={11}/>CSV</button>
        <button className="btn-outline" onClick={salvarManual}
          disabled={!pendente||syncStatus==='saving'||syncStatus==='loading'}
          style={{opacity:(!pendente&&syncStatus!=='saving')?0.5:1,cursor:(!pendente||syncStatus==='saving')?'not-allowed':'pointer'}}>
          <Save size={11}/>{syncStatus==='saving'?'Salvando...':'Salvar'}
        </button>
      </div>

      {/* FORMULÁRIO ADICIONAR COLABORADOR */}
      {mostrarAdd && (
        <div style={{padding:'14px 20px',background:'#FFF8EC',borderBottom:`1px solid ${T.border}`}}>
          <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:10}}>
            <span className="cat-pill" style={{background:T.amberBg,color:T.amber}}>+ Colaborador Extra</span>
            <button onClick={()=>{setMostrarAdd(false);setNovoNome('');}} style={{width:24,height:24,display:'flex',alignItems:'center',justifyContent:'center',border:`1px solid ${T.border}`,background:'transparent',cursor:'pointer',color:T.muted,borderRadius:100}}><X size={11}/></button>
          </div>
          <div style={{display:'grid',gridTemplateColumns:'2fr 1fr 1fr 1fr auto',gap:8,alignItems:'end'}}>
            <div><label className="esc-field-label">Nome</label><input className="esc-input" type="text" placeholder="Ex.: João Freelancer" value={novoNome} onChange={e=>setNovoNome(e.target.value)} onKeyDown={e=>{if(e.key==='Enter')adicionarColab();}} autoFocus/></div>
            <div><label className="esc-field-label">Função</label><select className="esc-select-sm" value={novoFunc} onChange={e=>setNovoFunc(e.target.value)}>{FUNCOES.map(f=><option key={f}>{f}</option>)}</select></div>
            <div><label className="esc-field-label">Unidade</label><input className="esc-input" type="text" value={novoUnidade} onChange={e=>setNovoUnidade(e.target.value)}/></div>
            <div><label className="esc-field-label">Depto</label><input className="esc-input" type="text" value={novoDepto} onChange={e=>setNovoDepto(e.target.value)}/></div>
            <button className="btn-dev" onClick={adicionarColab} disabled={!novoNome.trim()} style={{justifyContent:'center',opacity:novoNome.trim()?1:.5,cursor:novoNome.trim()?'pointer':'not-allowed'}}><Plus size={11}/>Adicionar</button>
          </div>
        </div>
      )}

      {/* TABELA PRINCIPAL */}
      <div style={{padding:'16px 20px 0'}}>
        <section className="card">
          <div onClick={()=>setTabelaAberta(p=>!p)} style={{padding:'10px 16px',borderBottom:tabelaAberta?`1px solid ${T.border}`:'none',display:'flex',alignItems:'center',justifyContent:'space-between',cursor:'pointer',userSelect:'none'}}>
            <span className="cat-pill">📋 Escala da Semana</span>
            <span style={{fontFamily:'DM Mono,monospace',fontSize:10,color:T.muted}}>{tabelaAberta?'▲':'▼'}</span>
          </div>
          {tabelaAberta && <div style={{overflowX:'auto',padding:'10px 12px 12px'}}>
        <table className="esc-table">
          <thead>
            <tr>
              <th>Colaborador</th>
              {DIAS_META.map((d,i)=>(
                <th key={d.id}>{d.curto}<span className="esc-th-date">{fmtDate(addDays(semanaAtual,i))}</span></th>
              ))}
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            {colabsFiltrados.map(c=>{
              const expanded = isExpanded(c.id);
              const s = stats[c.id]||{horas:0,folgas:0};
              const totalCls = s.horas > META_HORAS ? 'esc-total-warn' : s.horas > 0 ? 'esc-total-ok' : 'esc-total-muted';
              return (
                <tr key={c.id}>
                  <td>
                    <div className="esc-nome-wrap">
                      <button className="esc-chevron" onClick={()=>toggleExpand(c.id)} title={expanded?'Recolher':'Expandir'}>
                        {expanded ? '▾' : '▸'}
                      </button>
                      <div className="esc-nome-info">
                        <span className="esc-nome-c">{c.nome}</span>
                        <span className="esc-cargo-c">{c.funcao}</span>
                      </div>
                      <button className="esc-del-btn" onClick={()=>removerColab(c.id)} title="Remover">×</button>
                    </div>
                  </td>
                  {DIAS_META.map((d,i)=>{
                    const t = escala[d.id]?.[c.id] || turnoVazio();
                    const dataD = addDays(semanaAtual, i);
                    const df = estaDeFerias(c.id, dataD);
                    return (
                      <td key={d.id}>
                        {expanded ? (
                          <CelulaTurno
                            turno={t}
                            deFerias={df}
                            onChange={(novo)=>setTurnoCell(d.id, c.id, novo)}
                            onVacationClick={()=>setFeriasModalColab(c.id)}
                          />
                        ) : (
                          <CelulaColapsada turno={t} deFerias={df}/>
                        )}
                      </td>
                    );
                  })}
                  <td className={`esc-total ${totalCls}`}>{s.horas.toFixed(1)}h</td>
                </tr>
              );
            })}
          </tbody>
          <tfoot>
            <tr className="esc-footer">
              <td style={{fontWeight:600}}>Equipe</td>
              {DIAS_META.map((d,i)=>{
                const {trab,folga,ferias} = countsDia(d.id, i);
                return (
                  <td key={d.id} style={{fontSize:9,lineHeight:1.6}}>
                    {trab>0&&<div style={{color:T.green}}>▲{trab} trab</div>}
                    {folga>0&&<div style={{color:T.amber}}>◆{folga} folga</div>}
                    {ferias>0&&<div style={{color:'#1A3A5C'}}>🏖{ferias} fér</div>}
                    {trab===0&&folga===0&&ferias===0&&<div style={{color:T.muted}}>—</div>}
                  </td>
                );
              })}
              <td style={{fontWeight:600,color:T.carbon,fontSize:10}}>{totalSemana.toFixed(1)}h</td>
            </tr>
          </tfoot>
        </table>
          </div>}
        </section>
      </div>

      {/* GRADE VISUAL */}
      <div style={{padding:'12px 20px 0'}}>
        <section className="card">
          <div onClick={()=>setGradeAberta(p=>!p)} style={{padding:'10px 16px',borderBottom:gradeAberta?`1px solid ${T.border}`:'none',display:'flex',alignItems:'center',justifyContent:'space-between',cursor:'pointer',userSelect:'none'}}>
            <span className="cat-pill">📅 Grade Visual</span>
            <span style={{fontFamily:'DM Mono,monospace',fontSize:10,color:T.muted}}>{gradeAberta?'▲':'▼'}</span>
          </div>
          {gradeAberta && (
            <>
              <div className="grade-tabs">
                {DIAS_META.map((d,i)=>(
                  <button key={d.id} className={`grade-tab ${i===diaGradeIdx?'on':''}`} onClick={()=>setDiaGradeIdx(i)}>
                    <span>{d.curto}</span>
                    <span style={{fontSize:9,fontWeight:400,opacity:.7,letterSpacing:'.3px'}}>{fmtDate(addDays(semanaAtual,i))}</span>
                  </button>
                ))}
              </div>
              <div style={{overflow:'auto',maxHeight:'60vh',WebkitOverflowScrolling:'touch'}}>
                <div style={{display:'grid',gridTemplateColumns:`48px repeat(${colabsFiltrados.length},${colW}px)`,minWidth:48+colabsFiltrados.length*colW,width:'max-content'}}>
                  <div style={{position:'sticky',top:0,left:0,zIndex:30,background:T.carbon,color:T.citric,height:54,width:48,minWidth:48,display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'DM Mono,monospace',fontSize:9.5,fontWeight:600,letterSpacing:'1px'}}>HORA</div>
                  {colabsFiltrados.map(c=>(
                    <div key={c.id} style={{position:'sticky',top:0,zIndex:10,background:T.carbon,color:'#F0F0F0',padding:'5px 7px',borderLeft:'1px solid #2E3038',minHeight:54,display:'flex',flexDirection:'column',justifyContent:'center',alignItems:'center',textAlign:'center'}}>
                      <div style={{fontFamily:'DM Sans,sans-serif',fontSize:ehMobile?10:11.5,fontWeight:700,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',letterSpacing:'-0.2px',width:'100%',textAlign:'center'}}>{c.nome}</div>
                      <div style={{fontFamily:'DM Sans,sans-serif',fontSize:ehMobile?9:10.5,fontWeight:400,color:'#FFFFFF',marginTop:2,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',letterSpacing:'-0.1px',opacity:.85,width:'100%',textAlign:'center'}}>
                        {estaDeFerias(c.id,dataDoDia(diaGrade.id)) ? '🏖 Férias' : `${c.funcao} · ${horasTurno(escala[diaGrade.id]?.[c.id]||{}).toFixed(1)}h`}
                      </div>
                    </div>
                  ))}
                  {Array.from({length:TOTAL_SLOTS}).map((_,slot)=>{
                    const lbl=slotLabel(slot);
                    const full=slot%2===0;
                    const naPrepAlm = emFaixa(slot,cfgGrade.prepAlmocoIni,cfgGrade.prepAlmocoFim);
                    const naFuncAlm = emFaixa(slot,cfgGrade.funcAlmocoIni,cfgGrade.funcAlmocoFim);
                    const naPrepJan = emFaixa(slot,cfgGrade.prepJantarIni,cfgGrade.prepJantarFim);
                    const naFuncJan = emFaixa(slot,cfgGrade.funcJantarIni,cfgGrade.funcJantarFim);
                    const borda = full ? `1px solid ${T.border}` : `1px solid transparent`;
                    return (
                      <React.Fragment key={slot}>
                        <div className="hora-cell" style={{
                          fontWeight: full?600:400,
                          color: full ? T.carbon : 'transparent',
                          fontSize: full ? 9.5 : 0,
                          borderBottom: full ? `1px solid ${T.border}` : `1px solid transparent`,
                          width: 48, maxWidth: 48, minWidth: 48,
                        }}>{full ? lbl : ''}</div>
                        {colabsFiltrados.map(c=>{
                          const t=escala[diaGrade.id]?.[c.id]||{};
                          const ativo=turnoSlots(t).has(slot);
                          const deFerias=estaDeFerias(c.id, dataDoDia(diaGrade.id));
                          let bg='transparent';
                          let opacity=1;
                          if (deFerias) { bg='rgba(26,58,92,.18)'; opacity=.7; }
                          else if (t.folga) { bg=`repeating-linear-gradient(45deg,transparent,transparent 4px,${T.border} 4px,${T.border} 5px)`; opacity=.5; }
                          else if (ativo) bg=T.carbon;
                          else if (naFuncJan) bg='rgba(122,26,26,.18)';
                          else if (naPrepJan) bg='rgba(122,74,0,.18)';
                          else if (naFuncAlm) bg='rgba(26,92,42,.18)';
                          else if (naPrepAlm) bg='rgba(122,74,0,.18)';
                          return (
                            <div key={`${slot}-${c.id}`} style={{height:rowH,background:bg,opacity,borderRight:`1px solid ${T.border}`,borderBottom:borda,overflow:'hidden'}}/>
                          );
                        })}
                      </React.Fragment>
                    );
                  })}
                </div>
              </div>
              <div style={{padding:'10px 16px',borderTop:`1px solid ${T.border}`,display:'flex',gap:12,flexWrap:'wrap',fontFamily:'DM Mono,monospace',fontSize:10,color:T.mid,justifyContent:'center'}}>
                {[
                  {label:'Prep Almoço', bg:'rgba(122,74,0,.18)',  border:'1px solid rgba(122,74,0,.4)'},
                  {label:'Func Almoço', bg:'rgba(26,92,42,.18)',  border:'1px solid rgba(26,92,42,.4)'},
                  {label:'Prep Jantar', bg:'rgba(122,74,0,.18)',  border:'1px dashed rgba(122,74,0,.5)'},
                  {label:'Func Jantar', bg:'rgba(122,26,26,.18)', border:'1px solid rgba(122,26,26,.4)'},
                ].map(l=>(
                  <span key={l.label} style={{display:'flex',alignItems:'center',gap:5}}>
                    <span style={{width:10,height:10,background:l.bg,borderRadius:2,border:l.border,flexShrink:0}}/>
                    {l.label}
                  </span>
                ))}
              </div>
            </>
          )}
        </section>
      </div>

      {/* RESUMO SEMANAL */}
      <div style={{padding:'12px 20px 40px'}}>
        <section className="card">
          <div onClick={()=>setResumoAberto(p=>!p)} style={{padding:'10px 16px',borderBottom:resumoAberto?`1px solid ${T.border}`:'none',display:'flex',justifyContent:'space-between',alignItems:'center',cursor:'pointer',userSelect:'none'}}>
            <span className="cat-pill">📊 Resumo Semanal</span>
            <span style={{display:'flex',alignItems:'center',gap:10}}>
              <span style={{fontFamily:'DM Mono,monospace',fontSize:10,color:T.mid}}>
                Meta: <b style={{color:T.carbon}}>{META_HORAS}h</b> · 2 folgas
              </span>
              <span style={{fontFamily:'DM Mono,monospace',fontSize:10,color:T.muted}}>{resumoAberto?'▲':'▼'}</span>
            </span>
          </div>
          {resumoAberto && <div style={{display:'grid',gridTemplateColumns:'repeat(auto-fill,minmax(220px,1fr))',gap:8,padding:'12px 16px'}}>
            {colabsFiltrados.map(c=>{
              const s=stats[c.id];
              if (!s) return null;
              const pct=Math.min(Math.round((s.horas/META_HORAS)*100),999);
              const alerta=s.horas>META_HORAS?'crit':(s.folgas<2&&s.dias>0)?'warn':s.horas>0?'ok':'zero';
              const mesAtual = semanaAtual.getMonth();
              const anoAtual = semanaAtual.getFullYear();
              const domingoIdx = DIAS_META.findIndex(d=>d.id==='dom');
              const dataDomingo = addDays(semanaAtual, domingoIdx);
              const folgaDomingo = escala['dom']?.[c.id]?.folga && dataDomingo.getMonth()===mesAtual && dataDomingo.getFullYear()===anoAtual;
              return (
                <div key={c.id} className="resumo-card">
                  <div style={{flex:1,minWidth:0}}>
                    <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',gap:6,marginBottom:3}}>
                      <div style={{display:'flex',alignItems:'center',gap:5,minWidth:0,flex:1}}>
                        <span style={{fontSize:12,fontWeight:700,color:T.carbon,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{c.nome}</span>
                        {folgaDomingo&&<span title="Folga no Domingo do mês" style={{fontSize:9,background:'#E8F0FA',color:'#1A3A5C',padding:'1px 6px',borderRadius:100,fontFamily:'DM Mono,monospace',letterSpacing:'.3px',whiteSpace:'nowrap',flexShrink:0}}>🗓 Dom/Mês</span>}
                      </div>
                      <div style={{display:'flex',alignItems:'center',gap:4,flexShrink:0}}>
                        {alerta==='crit'&&<span className="status-crit">⚠</span>}
                        {alerta==='ok'&&<span className="status-ok">✓</span>}
                        <span style={{fontFamily:'DM Mono,monospace',fontSize:11,fontWeight:600,color:T.carbon}}>{s.horas.toFixed(1)}h</span>
                      </div>
                    </div>
                    <div style={{fontFamily:'DM Mono,monospace',fontSize:8,color:T.muted,letterSpacing:'.4px',textTransform:'uppercase',marginBottom:5}}>
                      {c.funcao} · {s.dias}d trab · {s.folgas}d folga
                    </div>
                    <div style={{display:'flex',gap:2,flexWrap:'nowrap',marginBottom:5}}>
                      {DIAS_META.map(d=>{
                        const td=escala[d.id]?.[c.id]||{};
                        const th=calcHoras(td);
                        const dataD2 = addDays(semanaAtual, DIAS_META.findIndex(dm=>dm.id===d.id));
                        const deFerias2 = estaDeFerias(c.id, dataD2);
                        const bg   = deFerias2 ? '#C8DFF0' : td.folga ? T.amberBg : th>0 ? T.carbon : 'transparent';
                        const bord = deFerias2 ? '1px solid #1A3A5C' : td.folga ? `1px solid ${T.amber}` : th===0 ? `1px dashed ${T.border}` : 'none';
                        const txtC = deFerias2 ? '#1A3A5C' : td.folga ? T.amber : th>0 ? '#fff' : T.muted;
                        return (
                          <span key={d.id} title={`${d.nome}${deFerias2?' · Férias':td.folga?' · Folga':th>0?' · '+th.toFixed(1)+'h':' · Livre'}`} style={{
                            display:'inline-flex',alignItems:'center',justifyContent:'center',
                            flex:1,padding:'2px 2px',borderRadius:100,
                            background:bg,border:bord,
                            fontFamily:'DM Mono,monospace',fontSize:8,fontWeight:700,
                            color:txtC,letterSpacing:'0',minWidth:0,
                          }}>{d.mini}</span>
                        );
                      })}
                    </div>
                    <div style={{display:'flex',alignItems:'center',gap:5}}>
                      <div style={{flex:1,height:3,background:T.border,borderRadius:2,overflow:'hidden'}}>
                        <div style={{width:`${Math.min(pct,100)}%`,height:'100%',background:s.horas>META_HORAS?T.red:s.horas>0?T.green:T.border,transition:'width .2s'}}/>
                      </div>
                      <span style={{fontFamily:'DM Mono,monospace',fontSize:8,color:T.muted,minWidth:26,textAlign:'right'}}>{pct}%</span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>}
          {resumoAberto && <div style={{padding:'10px 16px',borderTop:`1px solid ${T.border}`,display:'flex',justifyContent:'space-between',fontFamily:'DM Mono,monospace',fontSize:10,fontWeight:600,letterSpacing:'.5px',color:T.carbon}}>
            <span>TOTAL: {totalSemana.toFixed(1)}h</span>
            <span style={{color:T.muted,fontWeight:400}}>META: {META_HORAS}h · 2 folgas / semana</span>
          </div>}
        </section>
      </div>

      {/* MODAL FÉRIAS */}
      {colabFeriasModal && (
        <ModalFerias
          colab={colabFeriasModal}
          ferias={ferias}
          onClose={()=>setFeriasModalColab(null)}
          onAdd={adicionarFerias}
          onRemove={removerFerias}
        />
      )}

      {/* FOOTER */}
      <footer style={{background:T.carbon,padding:'10px 20px',display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:3,position:'fixed',bottom:0,left:0,right:0,zIndex:50}}>
        <span style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:T.citric,letterSpacing:'1px',textTransform:'uppercase',textAlign:'center'}}>TATÁ SUSHI &nbsp;|&nbsp; TATÁ POKE &nbsp;|&nbsp; 2016 – 2026</span>
        <span style={{fontFamily:"'DM Mono',monospace",fontSize:10,color:'rgba(255,255,255,.4)',textAlign:'center'}}>Atualizado em {hoje}</span>
      </footer>
    </div>
  );
}
