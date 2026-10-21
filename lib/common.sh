#!/data/data/com.termux/files/usr/bin/bash
# shellcheck shell=bash
# Infynit AI - funções compartilhadas.
# TUDO aqui roda no TERMUX (nunca dentro do Debian).

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
AMBXST_HOME="${AMBXST_HOME:-$HOME/.ambxst}"
AMBXST_DISTRO="debian"
AMBXST_USER="ambxst"
AMBXST_DISPLAY=":0"
AMBXST_LOGS="$AMBXST_HOME/logs"
AMBXST_RUN="$AMBXST_HOME/run"
AMBXST_TMP="${TMPDIR:-$PREFIX/tmp}"
X11_SOCKET="$AMBXST_TMP/.X11-unix/X0"

# Descobre onde o proot-distro guarda o Debian (muda entre versões:
# .../containers/debian nas novas, .../installed-rootfs/debian nas antigas).
detect_rootfs() {
  local base="$PREFIX/var/lib/proot-distro" d f
  AMBXST_ROOTFS=""
  for d in "$base/containers/$AMBXST_DISTRO" "$base/installed-rootfs/$AMBXST_DISTRO" \
           "$base/containers/$AMBXST_DISTRO/rootfs"; do
    if [ -f "$d/etc/os-release" ]; then AMBXST_ROOTFS="$d"; break; fi
  done
  # Busca ampla: qualquer rootfs cujo os-release diga ID=debian
  if [ -z "$AMBXST_ROOTFS" ] && [ -d "$base" ]; then
    while IFS= read -r f; do
      if grep -qx 'ID=debian' "$f" 2>/dev/null; then AMBXST_ROOTFS="${f%/etc/os-release}"; break; fi
    done < <(find "$base" -maxdepth 6 -path '*/etc/os-release' 2>/dev/null)
  fi
  if [ -z "$AMBXST_ROOTFS" ]; then
    if [ -d "$base/containers" ]; then AMBXST_ROOTFS="$base/containers/$AMBXST_DISTRO"
    else AMBXST_ROOTFS="$base/installed-rootfs/$AMBXST_DISTRO"; fi
  fi
  CONF_FILE="$AMBXST_ROOTFS/home/$AMBXST_USER/.config/ambxst/ambxst.conf"
  SESSION_LOG="$AMBXST_ROOTFS/home/$AMBXST_USER/.cache/ambxst/session.log"
}
detect_rootfs

mkdir -p "$AMBXST_LOGS" "$AMBXST_RUN" 2>/dev/null

if [ -t 1 ]; then
  C_R=$'\033[31m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_B=$'\033[36m'; C_D=$'\033[2m'; C_0=$'\033[0m'
else
  C_R=""; C_G=""; C_Y=""; C_B=""; C_D=""; C_0=""
fi
info() { printf '%s[i]%s %s\n' "$C_B" "$C_0" "$*"; }
ok()   { printf '%s[ok]%s %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
err()  { printf '%s[x]%s %s\n' "$C_R" "$C_0" "$*" >&2; }

# get_conf CHAVE PADRAO  -> lê ambxst.conf (guardado dentro do Debian)
get_conf() {
  local v=""
  if [ -f "$CONF_FILE" ]; then
    v=$(grep -E "^$1=" "$CONF_FILE" | tail -n1 | cut -d= -f2- | sed -e 's/\r$//' -e 's/^"//' -e 's/"$//')
  fi
  printf '%s' "${v:-$2}"
}

# set_conf CHAVE VALOR
set_conf() {
  [ -f "$CONF_FILE" ] || { err "Configuração não encontrada: $CONF_FILE (rode ambxst-fix)"; return 1; }
  if grep -qE "^$1=" "$CONF_FILE"; then
    sed -i "s|^$1=.*|$1=$2|" "$CONF_FILE"
  else
    printf '%s=%s\n' "$1" "$2" >> "$CONF_FILE"
  fi
}

pid_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }
read_pid()  { [ -f "$1" ] && tr -dc '0-9' < "$1" 2>/dev/null; }

# Encerra um processo e todos os filhos (somente a árvore indicada).
kill_tree() {
  local pid="$1" sig="${2:-TERM}" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do kill_tree "$child" "$sig"; done
  kill "-$sig" "$pid" 2>/dev/null
  return 0
}

x11_pids()    { pgrep -f "CmdEntryPoint" 2>/dev/null; }
x11_running() { [ -n "$(x11_pids)" ]; }

# PID do supervisor da sessão (se vivo)
session_pid() {
  local p; p=$(read_pid "$AMBXST_RUN/supervisor.pid")
  pid_alive "$p" && printf '%s' "$p"
}

# 0 = instalado, 1 = não instalado, 2 = não foi possível verificar
x11_app_installed() {
  local out
  out=$(pm list packages 2>/dev/null) || return 2
  [ -n "$out" ] || return 2
  printf '%s\n' "$out" | grep -q '^package:com.termux.x11$'
}

open_x11_app() {
  am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
}

stop_x11() {
  local p; p=$(read_pid "$AMBXST_RUN/x11.pid")
  if pid_alive "$p"; then
    kill_tree "$p" TERM; sleep 1
    pid_alive "$p" && kill_tree "$p" KILL
  fi
  rm -f "$AMBXST_RUN/x11.pid"
  if ! x11_running; then rm -f "$X11_SOCKET" "$AMBXST_TMP/.X0-lock"; fi
  return 0
}

stop_pulse() {
  if [ -f "$AMBXST_RUN/pulse.started" ]; then
    pulseaudio --kill >/dev/null 2>&1
    rm -f "$AMBXST_RUN/pulse.started"
  fi
  return 0
}

require_installed() {
  [ -d "$AMBXST_ROOTFS" ] || { err "Debian não instalado. Rode: bash install-ambxst.sh"; exit 1; }
  [ -f "$CONF_FILE" ] || { err "Desktop não configurado. Rode: ambxst-fix  (ou install-ambxst.sh)"; exit 1; }
}

# ---------------------------------------------------------------- pedidos de pacotes (root) vindos do desktop
# O desktop roda como usuário comum e não tem root. Para instalar pacotes do sistema (ex.: mpv)
# ele grava um pedido em ~/.cache/ambxst/rootjobs/*.job; este vigia (rodando no Termux enquanto a
# sessão existe) executa o apt como root dentro do Debian. SÓ aceita pacotes desta lista.
ROOTJOBS_ALLOW=" mpv fzf curl openssl html-xml-utils patch jq yt-dlp ca-certificates "

rootjobs_dir() { printf '%s' "$AMBXST_ROOTFS/home/$AMBXST_USER/.cache/ambxst/rootjobs"; }

rootjobs_handle() { # arquivo.job
  local job="$1" base pk good=1 p
  base="${job%.job}"
  pk=$(head -c 400 "$job" 2>/dev/null | tr -s ' \t\r\n' ' ')
  set -f
  for p in $pk; do
    case "$ROOTJOBS_ALLOW" in *" $p "*) ;; *) good=0 ;; esac
  done
  set +f
  mv -f "$job" "$base.run" 2>/dev/null || return 0
  : > "$base.log"
  if [ "$good" = 0 ] || [ -z "${pk// /}" ]; then
    echo "[ambxst] pedido recusado: só são aceitos estes pacotes:$ROOTJOBS_ALLOW" >> "$base.log"
    echo 1 > "$base.rc"; rm -f "$base.run"; return 0
  fi
  echo "[ambxst] instalando como root no Debian:$pk" >> "$base.log"
  set -f
  # shellcheck disable=SC2086
  proot-distro login "$AMBXST_DISTRO" -- bash -c \
    'export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y --no-install-recommends "$@"' _ $pk \
    >> "$base.log" 2>&1
  local rc=$?
  set +f
  echo "$rc" > "$base.rc"
  rm -f "$base.run"
}

rootjobs_watch() {
  local d f; d=$(rootjobs_dir); mkdir -p "$d" 2>/dev/null || return 0
  rm -f "$d"/*.run 2>/dev/null
  while true; do
    for f in "$d"/*.job; do
      [ -f "$f" ] && rootjobs_handle "$f"
    done
    sleep 1
  done
}
