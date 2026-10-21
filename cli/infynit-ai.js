#!/usr/bin/env node
'use strict';
// infynit-ai - instalador/launcher npm do Infynit AI (desktop Linux no Android via Termux).
// Sem dependências: só chama os scripts bash que acompanham o pacote.
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const PKG = require(path.join(ROOT, 'package.json'));
const INSTALLER = path.join(ROOT, 'install-ambxst.sh');

// subcomando -> comando ambxst-* instalado no Termux
const PASSTHROUGH = {
  start: 'ambxst-start', stop: 'ambxst-stop', restart: 'ambxst-restart',
  status: 'ambxst-status', fix: 'ambxst-fix', logs: 'ambxst-logs', eco: 'ambxst-eco',
  'browser-install': 'ambxst-browser-install', twindesk: 'ambxst-twindesk',
};

const HELP = `Infynit AI ${PKG.version} - desktop Linux (Debian + Openbox) no Android, via Termux

Uso: infynit-ai <comando> [opções]

Instalação
  install [opções]    Instala tudo (Termux + Debian + desktop). Repetir é seguro.
      --start           inicia o desktop ao terminar
      --browser         instala também o Firefox ESR
      --brave           instala também o Brave
      --twindesk        copia o APK do TwinDesk e abre o instalador Android
      --skip-storage    não pede acesso ao armazenamento do Android
      --restore-config  recoloca as configurações padrão (faz backup)
  update              Baixa a versão mais nova do pacote e reaplica a instalação

Uso diário (atalhos para os comandos ambxst-*)
  start | stop | restart | status | fix | logs | eco on|off
  browser-install [firefox|brave|all] | twindesk status|install

Sem instalar nada: npx infynit-ai install
`;

function isTermux() {
  return !!process.env.TERMUX_VERSION || fs.existsSync('/data/data/com.termux/files/usr');
}

function run(cmd, args) {
  const r = spawnSync(cmd, args, { stdio: 'inherit' });
  if (r.error) {
    console.error(`[x] Não consegui executar ${cmd}: ${r.error.message}`);
    return 127;
  }
  return r.status === null ? 1 : r.status;
}

function has(cmd) {
  const dirs = (process.env.PATH || '').split(path.delimiter);
  return dirs.some((d) => d && fs.existsSync(path.join(d, cmd)));
}

function requireTermux() {
  if (isTermux()) return true;
  console.error('[x] O Infynit AI só instala dentro do Termux (Android, ARM64).');
  console.error('    Instale o Termux pela F-Droid ou GitHub (não a versão da Play Store) e rode o comando lá.');
  return false;
}

function install(args) {
  if (!requireTermux()) return 1;
  const start = args.includes('--start');
  const passArgs = args.filter((a) => a !== '--start');
  const rc = run('bash', [INSTALLER, ...passArgs]);
  if (rc !== 0) return rc;
  if (start) {
    console.log('\n[i] Iniciando o desktop (--start)...');
    return has('ambxst-start') ? run('ambxst-start', []) : 1;
  }
  return 0;
}

function update() {
  if (!requireTermux()) return 1;
  console.log('[i] Baixando a versão mais nova do pacote (npm install -g infynit-ai@latest)...');
  const rc = run('npm', ['install', '-g', `${PKG.name}@latest`]);
  if (rc !== 0) return rc;
  // O pacote novo já está em disco; reaplica a instalação a partir dele (mantém suas configurações).
  const globalRoot = spawnSync('npm', ['root', '-g'], { encoding: 'utf8' }).stdout.trim();
  const installer = path.join(globalRoot, PKG.name, 'install-ambxst.sh');
  return run('bash', [fs.existsSync(installer) ? installer : INSTALLER, '--skip-storage']);
}

function main(argv) {
  const [cmd, ...rest] = argv;
  if (!cmd || cmd === '-h' || cmd === '--help' || cmd === 'help') { process.stdout.write(HELP); return 0; }
  if (cmd === '-v' || cmd === '--version' || cmd === 'version') { console.log(PKG.version); return 0; }
  if (cmd === 'install') return install(rest);
  if (cmd === 'update' || cmd === 'upgrade') return update();
  const tool = PASSTHROUGH[cmd];
  if (tool) {
    if (!has(tool)) {
      console.error(`[x] '${tool}' não encontrado. Rode primeiro: infynit-ai install`);
      return 1;
    }
    return run(tool, rest);
  }
  console.error(`[x] Comando desconhecido: ${cmd}\n`);
  process.stderr.write(HELP);
  return 2;
}

process.exit(main(process.argv.slice(2)));
