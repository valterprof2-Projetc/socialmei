'use strict';
// Servidor estatico local sem dependencias. Nao altera arquivos, nao publica nada.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { exec } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const rootPrefix = root + path.sep;
const mode = process.argv.includes('--app') ? 'app' : 'site';
const startPath = mode === 'app' ? '/frontend/socialmei-app.html#/inicio' : '/frontend/entrada.html';
const mime = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.webp': 'image/webp', '.gif': 'image/gif', '.ico': 'image/x-icon',
  '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8', '.xml': 'application/xml; charset=utf-8',
  '.webmanifest': 'application/manifest+json', '.map': 'application/json; charset=utf-8'
};
const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' }); res.end('Metodo nao permitido'); return;
  }
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
  catch { res.writeHead(400); res.end('Endereco invalido'); return; }
  if (pathname.includes('\0') || pathname.split(/[\\/]/).includes('..')) {
    res.writeHead(403); res.end('Acesso negado'); return;
  }
  if (pathname === '/') pathname = '/index.html';
  const file = path.resolve(root, '.' + pathname.replace(/\\/g, '/'));
  if (file !== root && !file.startsWith(rootPrefix)) {
    res.writeHead(403); res.end('Acesso negado'); return;
  }
  fs.stat(file, (statErr, stat) => {
    if (statErr || !stat.isFile()) { res.writeHead(404); res.end('Arquivo nao encontrado'); return; }
    res.writeHead(200, {
      'Content-Type': mime[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'Content-Length': stat.size,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff'
    });
    if (req.method === 'HEAD') { res.end(); return; }
    const stream = fs.createReadStream(file);
    stream.on('error', () => { if (!res.headersSent) res.writeHead(500); res.end(); });
    stream.pipe(res);
  });
});
function start(port) {
  server.once('error', err => {
    if (err.code === 'EADDRINUSE' && port !== 0) { console.log('Porta 4173 ocupada; escolhendo outra porta local.'); start(0); }
    else { console.error('Erro ao iniciar servidor:', err.message); process.exitCode = 1; }
  });
  server.listen(port, '127.0.0.1', () => {
    const p = server.address().port;
    const addr = 'http://127.0.0.1:' + p;
    const url = addr + startPath;
    console.log('\nSocialMEI-IA — pre-visualizacao local');
    console.log('Landing:     ' + addr + '/frontend/entrada.html');
    console.log('App completo:' + addr + '/frontend/socialmei-app.html#/inicio');
    console.log('\nAbrindo: ' + url);
    console.log('Para encerrar o servidor, pressione Ctrl+C nesta janela.\n');
    if (process.platform === 'win32') {
      exec('start "" "' + url + '"', { windowsHide: true }, err => {
        if (err) console.log('Se o navegador nao abrir, copie o endereco acima.');
      });
    }
  });
}
start(4173);
