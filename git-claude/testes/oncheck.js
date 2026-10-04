// Confere a sintaxe dos handlers inline (onclick="…", onchange="…" etc.) escritos no HTML estático.
// Uso: node oncheck.js <arquivo.html> [...]
const fs = require('fs'), vm = require('vm');
let ruins = 0;
for (const f of process.argv.slice(2)) {
  const s = fs.readFileSync(f, 'utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/g, '');
  const re = /\son[a-z]+="([^"]*)"/g; let m;
  while ((m = re.exec(s))) {
    const js = m[1].replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
    try { new vm.Script('(function(event){' + js + '\n})'); } catch (e) { ruins++; console.log('ERRO', f, JSON.stringify(m[1].slice(0, 90)), e.message); }
  }
}
console.log(ruins ? ruins + ' handler(s) com erro' : 'handlers ok');
