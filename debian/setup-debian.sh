#!/bin/bash
# setup-debian.sh - roda DENTRO do Debian (proot-distro), como root.
# Chamado por install-ambxst.sh:   proot-distro login debian -- bash /opt/ambxst/setup-debian.sh [opções]
#   --config-only   não instala pacotes; só (re)coloca arquivos de configuração faltantes
#   --force         sobrescreve configurações existentes (faz backup .bak-DATA antes)
#   --browser       instala também o Firefox ESR (mais pesado)
set -u

SRC=/opt/ambxst/skel
U=ambxst
H=/home/$U
STAMP=$(date +%Y%m%d-%H%M%S)
CONFIG_ONLY=0; FORCE=0; BROWSER=0
for a in "$@"; do
  case "$a" in
    --config-only) CONFIG_ONLY=1 ;;
    --force) FORCE=1 ;;
    --browser) BROWSER=1 ;;
    *) echo "[x] opção desconhecida: $a"; exit 2 ;;
  esac
done

say()  { printf '[debian] %s\n' "$*"; }
fail() { printf '[debian][ERRO] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "execute como root dentro do Debian (proot-distro login debian -- ...)"
[ -d "$SRC" ] || fail "payload ausente em $SRC (rode install-ambxst.sh no Termux)"

# ------------------------------------------------------------------ pacotes
PKGS="openbox tint2 rofi dunst pcmanfm xfce4-terminal mousepad lxappearance zenity feh picom \
python3 python3-gi gir1.2-gtk-3.0 dbus dbus-x11 x11-utils x11-xserver-utils xdotool \
libnotify-bin pulseaudio-utils procps psmisc xdg-utils shared-mime-info desktop-file-utils \
librsvg2-common adwaita-icon-theme papirus-icon-theme gvfs libglib2.0-bin \
fonts-jetbrains-mono fonts-noto-core fonts-noto-color-emoji \
ca-certificates curl nano htop unzip zip"

if [ "$CONFIG_ONLY" = 0 ]; then
  export DEBIAN_FRONTEND=noninteractive
  say "apt-get update..."
  apt-get update || fail "apt-get update falhou (sem rede?)"
  say "Instalando pacotes do desktop (isso demora; sem pacotes 'recomendados' para economizar espaço/RAM)..."
  # shellcheck disable=SC2086
  apt-get install -y --no-install-recommends $PKGS || fail "apt-get install falhou. Rode de novo; se persistir veja o erro acima."
  apt-get install -y --no-install-recommends webp-pixbuf-loader >/dev/null 2>&1 \
    && say "suporte a imagens WebP instalado" || say "AVISO: webp-pixbuf-loader indisponível (WebP como papel de parede não abrirá)"
  if [ "$BROWSER" = 1 ]; then
    say "Instalando Firefox ESR (opcional)..."
    apt-get install -y --no-install-recommends firefox-esr || say "AVISO: firefox-esr não instalou; seguindo sem navegador."
  fi
  fc-cache -f >/dev/null 2>&1
fi

# ------------------------------------------------------------------ usuário
if ! id -u "$U" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$U" || fail "não consegui criar o usuário $U"
  say "usuário $U criado"
fi
mkdir -p "$H/.config" "$H/.local/bin" "$H/.local/share/applications" "$H/.themes" "$H/.cache/ambxst" \
         "$H/Desktop" "$H/Pictures/Wallpapers" "$H/Android" "$H/Termux"

# ------------------------------------------------------------------ implantação de arquivos
deploy_file() { # origem destino tipo(code|user)
  local src="$1" dst="$2" kind="$3"
  mkdir -p "$(dirname "$dst")"
  if [ ! -e "$dst" ]; then cp "$src" "$dst"; say "novo: ${dst#$H/}"; return 0; fi
  cmp -s "$src" "$dst" && return 0
  if [ "$kind" = code ]; then cp "$src" "$dst"; say "atualizado: ${dst#$H/}"; return 0; fi
  if [ "$FORCE" = 1 ]; then
    cp -a "$dst" "$dst.bak-$STAMP"; cp "$src" "$dst"; say "restaurado (backup .bak-$STAMP): ${dst#$H/}"
  else
    say "mantido (personalizado): ${dst#$H/}"
  fi
}

for f in "$SRC"/bin/*; do deploy_file "$f" "$H/.local/bin/$(basename "$f")" code; chmod +x "$H/.local/bin/$(basename "$f")"; done

( cd "$SRC/cfg" && find . -type f ) | while read -r rel; do
  deploy_file "$SRC/cfg/$rel" "$H/.config/${rel#./}" user
done
( cd "$SRC/themes" && find . -type f ) | while read -r rel; do
  deploy_file "$SRC/themes/$rel" "$H/.themes/${rel#./}" user
done
for f in "$SRC"/applications/*.desktop; do deploy_file "$f" "$H/.local/share/applications/$(basename "$f")" user; done
# Ícones dos botões Claude Code / OpenCode / Shannon / GitBot / Filmes (referenciados por caminho absoluto nos .desktop)
mkdir -p "$H/.local/share/ambxst/icons"
for f in "$SRC"/icons/*.svg "$SRC"/icons/*.jpg "$SRC"/icons/*.jpeg "$SRC"/icons/*.png; do
  [ -e "$f" ] && deploy_file "$f" "$H/.local/share/ambxst/icons/$(basename "$f")" code
done
for f in "$SRC"/desktop/*.desktop; do deploy_file "$f" "$H/Desktop/$(basename "$f")" user; chmod +x "$H/Desktop/$(basename "$f")"; done
for f in "$SRC"/wallpapers/*; do deploy_file "$f" "$H/Pictures/Wallpapers/$(basename "$f")" user; done
chmod +x "$H"/.local/share/applications/ambxst-*.desktop 2>/dev/null

# Ícones de botões do tema Openbox (reaproveita os do Clearlooks se existirem)
if [ -d /usr/share/themes/Clearlooks/openbox-3 ]; then
  cp -n /usr/share/themes/Clearlooks/openbox-3/*.xbm "$H/.themes/Infynit AI/openbox-3/" 2>/dev/null
fi

# Atalhos de pastas no desktop (links; só cria se não existir nada com o nome)
[ -e "$H/Desktop/Android" ] || ln -s "$H/Android" "$H/Desktop/Android"
[ -e "$H/Desktop/Termux" ] || ln -s "$H/Termux" "$H/Desktop/Termux"

# Navegador padrão para xdg-open, se existir
command -v firefox-esr >/dev/null 2>&1 && xdg-settings set default-web-browser firefox-esr.desktop >/dev/null 2>&1

# Permissões (somente diretórios do desktop; NÃO percorre Android/ nem Termux/)
for d in .config .local .themes .cache Desktop Pictures; do chown -R "$U:$U" "$H/$d" 2>/dev/null; done
chown "$U:$U" "$H" "$H/Android" "$H/Termux" 2>/dev/null
update-desktop-database "$H/.local/share/applications" >/dev/null 2>&1

# ------------------------------------------------------------------ verificação
MISSING=""
for b in openbox tint2 rofi dunst pcmanfm xfce4-terminal mousepad lxappearance zenity feh python3 dbus-run-session xdpyinfo xset xprop notify-send; do
  command -v "$b" >/dev/null 2>&1 || MISSING="$MISSING $b"
done
if [ -n "$MISSING" ]; then
  say "FALTAM comandos:$MISSING"
  [ "$CONFIG_ONLY" = 1 ] && say "(modo --config-only não instala pacotes; rode install-ambxst.sh)"
  exit 1
fi
if su - "$U" -c "python3 -c \"import gi; gi.require_version('Gtk','3.0'); from gi.repository import Gtk\"" >/dev/null 2>&1; then
  say "python3-gi/GTK3 ok (painel Infynit AI disponível)"
else
  say "AVISO: python3-gi/GTK3 não importou; o painel Infynit AI não abrirá (o resto funciona)."
fi
say "OK. Configuração do desktop pronta em $H"
