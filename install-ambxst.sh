#!/data/data/com.termux/files/usr/bin/bash
# install-ambxst.sh - instalador do Infynit AI (Termux + Debian ARM64 + Termux:X11)
# Rode no TERMUX:   bash install-ambxst.sh [--browser] [--twindesk] [--skip-storage] [--restore-config] [--help]
# Idempotente: pode ser executado de novo para atualizar; não apaga a instalação existente.
set -u

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SRC_DIR/lib/common.sh"

BROWSER=0; BRAVE=0; SKIP_STORAGE=0; RESTORE=0; TWINDESK=0
for a in "$@"; do
  case "$a" in
    --browser) BROWSER=1 ;;
    --brave) BRAVE=1 ;;
    --skip-storage) SKIP_STORAGE=1 ;;
    --restore-config) RESTORE=1 ;;
    --twindesk) TWINDESK=1 ;;
    -h|--help)
      cat <<U
Uso: bash install-ambxst.sh [opções]
  --browser          instala também o Firefox ESR dentro do Debian (+~250 MB, mais RAM)
  --brave            instala também o Brave (+~500 MB, mais RAM)
  --skip-storage     não pede acesso ao armazenamento do Android
  --restore-config   recoloca as configurações padrão (backup .bak-DATA do que existir)
  --twindesk         copia o APK TwinDesk e abre o instalador Android ao final
U
      exit 0 ;;
    *) err "Opção desconhecida: $a"; exit 2 ;;
  esac
done

LOG="$AMBXST_LOGS/install.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== install-ambxst v3 $(date '+%F %T') ==="

STEP=0; TOTAL=9
step() { STEP=$((STEP+1)); printf '\n%s== [%d/%d] %s ==%s\n' "$C_B" "$STEP" "$TOTAL" "$*" "$C_0"; }
die()  { err "$*"; err "Log completo: $LOG"; exit 1; }

# ------------------------------------------------------------------ 1. Termux
step "Verificando se estamos no Termux"
if [ -z "${TERMUX_VERSION:-}" ] && [ ! -d /data/data/com.termux/files/usr ]; then
  die "Este instalador só roda no Termux (Android). Não execute dentro do Debian nem em PC."
fi
command -v pkg >/dev/null 2>&1 || die "Comando 'pkg' não encontrado; use o Termux oficial (F-Droid/GitHub)."
[ "$(id -u)" != 0 ] || die "Não rode como root."
ok "Termux detectado (PREFIX=$PREFIX)"

# ------------------------------------------------------------------ 2. Arquitetura
step "Verificando arquitetura"
ARCH=$(uname -m)
case "$ARCH" in
  aarch64|arm64) ok "Arquitetura $ARCH (ARM64)" ;;
  *) if [ "${AMBXST_ALLOW_ANY_ARCH:-0}" = 1 ]; then warn "Arquitetura $ARCH não é ARM64; continuando por AMBXST_ALLOW_ANY_ARCH=1 (não testado)."
     else die "Arquitetura $ARCH não suportada (precisa de ARM64/aarch64). Para forçar: AMBXST_ALLOW_ANY_ARCH=1"; fi ;;
esac
FREE_MB=$(df -Pm "$PREFIX" 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "${FREE_MB:-}" ] && [ "$FREE_MB" -lt 3000 ]; then
  warn "Só ${FREE_MB} MB livres. O Debian + desktop precisa de ~2-3 GB. Libere espaço se a instalação falhar."
fi

# ------------------------------------------------------------------ 3. Pacotes do Termux
step "Instalando pacotes do Termux (proot-distro, termux-x11, pulseaudio...)"
info "Atualizando índices (se pedir para escolher mirror, rode antes: termux-change-repo)"
pkg update -y || warn "pkg update falhou (rede/mirror?). Tentando seguir."
pkg install -y x11-repo || die "Não consegui habilitar o x11-repo. Verifique a internet / termux-change-repo."
pkg update -y >/dev/null 2>&1
pkg install -y proot-distro termux-x11-nightly pulseaudio procps coreutils gawk grep sed curl util-linux \
  || die "Falha ao instalar pacotes do Termux. Rode 'pkg update' e tente de novo."

# ------------------------------------------------------------------ 4. Comandos necessários
step "Verificando comandos necessários"
MISS=0
for c in proot-distro termux-x11 pulseaudio pgrep awk timeout am curl; do
  if command -v "$c" >/dev/null 2>&1; then ok "$c"; else err "falta: $c"; MISS=1; fi
done
[ "$MISS" = 0 ] || die "Comandos ausentes (veja acima). 'termux-x11' vem do pacote termux-x11-nightly (x11-repo)."

x11_app_installed; case $? in
  0) ok "App Termux:X11 instalado" ;;
  1) warn "App Termux:X11 NÃO instalado. Instale o APK (GitHub termux/termux-x11, release 'nightly', versão arm64-v8a) ANTES de usar o desktop." ;;
  *) warn "Não consegui verificar se o app Termux:X11 está instalado; confirme manualmente." ;;
esac

# ------------------------------------------------------------------ 5. Armazenamento
step "Armazenamento compartilhado do Android"
if [ "$SKIP_STORAGE" = 1 ]; then
  info "Pulado (--skip-storage)."
elif [ -d "$HOME/storage/shared" ] && ls "$HOME/storage/shared" >/dev/null 2>&1; then
  ok "Acesso ao armazenamento já autorizado."
else
  info "Abrindo o pedido de permissão do Android. Toque em PERMITIR."
  termux-setup-storage
  for _ in $(seq 1 30); do
    [ -d "$HOME/storage/shared" ] && ls "$HOME/storage/shared" >/dev/null 2>&1 && break
    sleep 1
  done
  if ls "$HOME/storage/shared" >/dev/null 2>&1; then ok "Armazenamento autorizado."
  else warn "Sem permissão de armazenamento: o desktop funciona, mas a pasta 'Android' ficará vazia. Rode 'termux-setup-storage' depois."; fi
fi

# ------------------------------------------------------------------ 6. Comandos ambxst-*
step "Instalando os comandos ambxst-* e arquivos do projeto"
mkdir -p "$AMBXST_HOME/bin" "$AMBXST_HOME/lib" "$AMBXST_HOME/debian" "$AMBXST_HOME/docs" "$AMBXST_HOME/vendor"
if [ "$SRC_DIR" != "$AMBXST_HOME" ]; then
  cp -a "$SRC_DIR/lib/." "$AMBXST_HOME/lib/"
  cp -a "$SRC_DIR/bin/." "$AMBXST_HOME/bin/"
  cp -a "$SRC_DIR/debian/." "$AMBXST_HOME/debian/"
  cp -a "$SRC_DIR/docs/." "$AMBXST_HOME/docs/"
  [ -d "$SRC_DIR/vendor" ] && cp -a "$SRC_DIR/vendor/." "$AMBXST_HOME/vendor/"
  [ -f "$SRC_DIR/README.md" ] && cp -a "$SRC_DIR/README.md" "$AMBXST_HOME/README.md"
  cp -a "$SRC_DIR/install-ambxst.sh" "$AMBXST_HOME/install-ambxst.sh"
fi
for f in "$SRC_DIR"/bin/*; do install -m 755 "$f" "$PREFIX/bin/$(basename "$f")"; done
ok "Comandos instalados em $PREFIX/bin: $(cd "$SRC_DIR/bin" && ls | tr '\n' ' ')"

# ------------------------------------------------------------------ 7. Debian
step "Instalando Debian ARM64 via proot-distro"
if [ -f "$AMBXST_ROOTFS/etc/os-release" ]; then
  ok "Debian já instalado (mantido): $AMBXST_ROOTFS"
elif proot-distro login "$AMBXST_DISTRO" -- true >/dev/null 2>&1; then
  ok "Debian já instalado (o proot-distro consegue entrar nele); reutilizando."
  detect_rootfs
else
  info "Baixando Debian (~150 MB)..."
  OUT=$(proot-distro install "$AMBXST_DISTRO" 2>&1); RC=$?
  printf '%s\n' "$OUT"
  if [ "$RC" != 0 ] && ! printf '%s' "$OUT" | grep -qi "already exists"; then
    die "proot-distro install falhou. Verifique internet/espaço e rode de novo."
  fi
  detect_rootfs
fi
if [ ! -f "$AMBXST_ROOTFS/etc/os-release" ]; then
  warn "Caminho do Debian não localizado automaticamente. Informações para diagnóstico:"
  proot-distro list 2>&1 | head -n 20
  ls -la "$PREFIX/var/lib/proot-distro" 2>&1 | head -n 20
  die "Não encontrei os arquivos do Debian. Envie a saída acima."
fi
VER=$(grep -E '^VERSION_ID=' "$AMBXST_ROOTFS/etc/os-release" 2>/dev/null | cut -d= -f2 | tr -d '"')
if [ "${VER:-}" = 13 ]; then ok "Debian 13 (trixie) confirmado."
else warn "A imagem 'debian' do seu proot-distro é a versão '${VER:-desconhecida}', não 13. Deve funcionar, mas é diferente do pedido. Atualize com: pkg upgrade proot-distro (e, se quiser, reinstale)."; fi

# ------------------------------------------------------------------ 8. Desktop dentro do Debian
step "Instalando e configurando o desktop dentro do Debian"
DEST="$AMBXST_ROOTFS/opt/ambxst"
mkdir -p "$DEST"
[ -n "$AMBXST_ROOTFS" ] && rm -rf "$DEST/skel"      # apenas o payload próprio do Infynit AI
cp -a "$SRC_DIR/debian/skel" "$DEST/skel"
install -m 755 "$SRC_DIR/debian/setup-debian.sh" "$DEST/setup-debian.sh"
FLAGS=""
[ "$BROWSER" = 1 ] && FLAGS="$FLAGS --browser"
[ "$RESTORE" = 1 ] && FLAGS="$FLAGS --force"
info "(Comandos a seguir rodam DENTRO do Debian, via proot-distro)"
# shellcheck disable=SC2086
proot-distro login "$AMBXST_DISTRO" -- bash /opt/ambxst/setup-debian.sh $FLAGS \
  || die "A configuração dentro do Debian falhou. Rode de novo (é seguro) e veja o erro acima."

if [ "$BRAVE" = 1 ]; then
  info "Instalando o Brave (--brave)..."
  ambxst-browser-install brave || warn "Brave não instalou; rode depois: ambxst-browser-install brave"
fi

# ------------------------------------------------------------------ 9. Verificação final
step "Verificação final"
FAIL=0
for f in .local/bin/ambxst-session .local/bin/ambxst-autostart .local/bin/ambxst-panel .local/bin/ambxst-twindesk .local/bin/ambxst-apps .local/bin/ambxst-login .config/ambxst/ambxst.conf \
         .config/openbox/rc.xml .config/tint2/top.tint2rc .config/tint2/dock.tint2rc .config/rofi/config.rasi \
         Pictures/Wallpapers/infynit.jpg Pictures/Wallpapers/skull.jpg; do
  if [ -e "$AMBXST_ROOTFS/home/$AMBXST_USER/$f" ]; then ok "~/$f"; else err "faltando: ~/$f"; FAIL=1; fi
done
[ "$FAIL" = 0 ] || die "Arquivos faltando. Rode: ambxst-fix"
if proot-distro login "$AMBXST_DISTRO" --user "$AMBXST_USER" -- bash -c 'command -v openbox tint2 rofi pcmanfm xfce4-terminal >/dev/null' ; then
  ok "Aplicativos do desktop disponíveis para o usuário $AMBXST_USER"
else
  die "Aplicativos não encontrados para o usuário $AMBXST_USER. Rode: ambxst-fix"
fi

cat <<DONE

${C_G}Instalação concluída.${C_0}

  1. (uma vez) Instale o app Termux:X11 (APK nightly) se ainda não tiver.
  2. No Termux:      ambxst-start
  3. O app Termux:X11 abre sozinho; se não abrir, abra-o manualmente.
  4. Para sair:      ambxst-stop      |  diagnóstico: ambxst-status / ambxst-fix / ambxst-logs
  Ferramentas: toque em Claude Code / OpenCode / Shannon / GitBot / Filmes e Animes (painel AMBXST ou menu Aplicativos);
               o 1º toque instala, os seguintes abrem.
  TwinDesk Android: ambxst-twindesk status  |  instalar/abrir APK: ambxst-twindesk install
  Leia ~/.ambxst/README.md (gestos de toque, resolução, modo econômico, tela preta).
DONE

if [ "$TWINDESK" = 1 ]; then
  info "Abrindo o instalador do TwinDesk Android..."
  ambxst-twindesk install || warn "Não consegui abrir automaticamente o instalador. Use: ambxst-twindesk install"
fi
