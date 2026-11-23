'use strict';
// Validacao sem abrir navegador, sem capturas de tela e sem rede.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const frontend = path.join(root, 'frontend');
let issues = 0;
const files = [];
function walk(dir) {
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name);
    if (f.isDirectory()) walk(p);
    else if (f.isFile()) files.push(p);
  }
}
for (const p of [path.join(frontend, 'entrada.html'), path.join(frontend, 'socialmei-app.html'), path.join(root, 'index.html')]) {
  if (!fs.existsSync(p)) { console.error('FALTANDO:', path.relative(root, p)); issues++; }
}
walk(frontend);
for (const file of files.filter(f => f.endsWith('.js'))) {
  const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
  if (result.status !== 0) { issues++; console.error('ERRO JS:', path.relative(root, file)); console.error(result.stderr.trim()); }
}
// Verifica referencias relativas nos HTMLs. Nao exige links externos nem conteudo dinamico.
for (const file of files.filter(f => f.endsWith('.html'))) {
  const content = fs.readFileSync(file, 'utf8');
  for (const match of content.matchAll(/<(?:script|link|img)\b[^>]*?\b(?:src|href)=["']([^"']+)["']/gim)) {
    const ref = match[1];
    if (/^(?:#|https?:|data:|blob:|mailto:|tel:|\/\/)/i.test(ref) || ref.startsWith('/')) continue;
    const relative = decodeURIComponent(ref.split(/[?#]/)[0]);
    if (!relative || relative.includes('${')) continue;
    const target = path.resolve(path.dirname(file), relative);
    if (!fs.existsSync(target)) { console.warn('REFERENCIA NAO ENCONTRADA:', path.relative(root, file), '->', ref); issues++; }
  }
}
console.log('Arquivos do frontend:', files.length);
console.log('Scripts JS conferidos:', files.filter(f => f.endsWith('.js')).length);
console.log('Resultado:', issues === 0 ? 'OK (estrutura e sintaxe; nao substitui teste no navegador)' : issues + ' ocorrencia(s)');
process.exitCode = issues ? 1 : 0;
