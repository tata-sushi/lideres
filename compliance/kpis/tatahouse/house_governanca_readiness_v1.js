(function(root,factory){
  'use strict';
  var api=factory();
  if(typeof module==='object'&&module.exports) module.exports=api;
  root.TataHouseGovernancaReadinessV1=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';

  var CONTRATO='tata-house-governanca-readiness';
  var VERSAO=1;
  var STATUS_VALIDOS=new Set(['PASS','BLOCKED','DEFERRED','UNKNOWN','SIMULATION','NOT_AUTHORIZED','REVIEW_REQUIRED']);

  function texto(v){return typeof v==='string'?v.trim():'';}

  function validarManifesto(manifesto){
    var erros=[];
    if(!manifesto||typeof manifesto!=='object'||Array.isArray(manifesto)) return {valido:false,erros:['manifesto ausente ou inválido']};
    if(manifesto.contrato!==CONTRATO) erros.push('contrato inválido');
    if(manifesto.versao!==VERSAO) erros.push('versão inválida');
    if(!manifesto.targets||typeof manifesto.targets!=='object'||Array.isArray(manifesto.targets)) erros.push('targets ausentes');
    if(!Array.isArray(manifesto.gates)) erros.push('gates ausentes');

    var ids=new Set();
    if(Array.isArray(manifesto.gates)){
      manifesto.gates.forEach(function(gate,i){
        if(!gate||typeof gate!=='object'||Array.isArray(gate)){erros.push('gate '+i+' inválido');return;}
        var id=texto(gate.id);
        if(!id){erros.push('gate '+i+' sem id');return;}
        if(ids.has(id)) erros.push('gate duplicado: '+id);
        ids.add(id);
        if(!STATUS_VALIDOS.has(gate.status)) erros.push('status inválido em '+id+': '+String(gate.status));
      });
    }

    if(manifesto.targets&&typeof manifesto.targets==='object'&&!Array.isArray(manifesto.targets)){
      Object.keys(manifesto.targets).forEach(function(idTarget){
        var target=manifesto.targets[idTarget];
        if(!target||typeof target!=='object'||Array.isArray(target)){erros.push('target inválido: '+idTarget);return;}
        if(!Array.isArray(target.requiredGates)||target.requiredGates.length===0){erros.push('target sem requiredGates: '+idTarget);return;}
        target.requiredGates.forEach(function(idGate){
          if(!texto(idGate)) erros.push('gate vazio em target '+idTarget);
          else if(!ids.has(idGate)) erros.push('gate ausente '+idGate+' requerido por '+idTarget);
        });
      });
    }

    return {valido:erros.length===0,erros:erros};
  }

  function avaliarTarget(manifesto,targetId){
    var validacao=validarManifesto(manifesto);
    if(!validacao.valido){
      return {target:targetId,ready:false,failClosed:true,blockers:validacao.erros.map(function(erro){return{id:'manifest_invalid',status:'UNKNOWN',resumo:erro};})};
    }

    var target=manifesto.targets[targetId];
    if(!target){
      return {target:targetId,ready:false,failClosed:true,blockers:[{id:'target_missing',status:'UNKNOWN',resumo:'Target não definido no manifesto.'}]};
    }

    var mapa={};
    manifesto.gates.forEach(function(gate){mapa[gate.id]=gate;});
    var blockers=[];
    target.requiredGates.forEach(function(id){
      var gate=mapa[id];
      if(!gate||gate.status!=='PASS'){
        blockers.push(gate?{
          id:gate.id,
          status:gate.status,
          classificacao:gate.classificacao||'',
          resumo:gate.resumo||''
        }:{id:id,status:'UNKNOWN',classificacao:'UNKNOWN',resumo:'Gate obrigatório ausente.'});
      }
    });

    return {
      target:targetId,
      titulo:target.titulo||targetId,
      ready:blockers.length===0,
      failClosed:false,
      blockers:blockers,
      requiredGates:target.requiredGates.slice()
    };
  }

  function avaliarTodos(manifesto){
    var validacao=validarManifesto(manifesto);
    if(!validacao.valido){
      return {valido:false,erros:validacao.erros,resultados:{}};
    }
    var resultados={};
    Object.keys(manifesto.targets).forEach(function(id){resultados[id]=avaliarTarget(manifesto,id);});
    return {valido:true,erros:[],resultados:resultados};
  }

  return {
    CONTRATO:CONTRATO,
    VERSAO:VERSAO,
    STATUS_VALIDOS:Array.from(STATUS_VALIDOS),
    validarManifesto:validarManifesto,
    avaliarTarget:avaliarTarget,
    avaliarTodos:avaliarTodos
  };
});
