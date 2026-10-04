const fs=require('fs'), vm=require('vm');
let bad=0;
for (const f of process.argv.slice(2)) {
  const s=fs.readFileSync(f,'utf8');
  const re=/<script\b([^>]*)>([\s\S]*?)<\/script>/g; let m, i=0;
  while((m=re.exec(s))){ i++;
    if(/\bsrc=/.test(m[1])||/type="(?!text\/javascript|module)[^"]*"/.test(m[1])) continue;
    try{ new vm.Script(m[2],{filename:f+'#'+i}); }catch(e){ bad++; console.log('ERRO',f,'script',i,e.message); }
  }
}
console.log(bad? bad+' erro(s)':'JS ok');
