#!/bin/bash
# stage-skel.sh - monta o conteúdo de /etc/skel (e extras) da ISO a partir do desktop do Termux.
# Uso: stage-skel.sh <raiz-do-projeto> <destino (includes.chroot)>
# Não precisa de root. O destino recebe /etc/skel/... (cada usuário novo ganha uma cópia).
set -euo pipefail
ROOT="${1:?uso: stage-skel.sh <raiz-do-projeto> <destino>}"
DEST="${2:?uso: stage-skel.sh <raiz-do-projeto> <destino>}"
S="$ROOT/debian/skel"
H="$DEST/etc/skel"
[ -d "$S" ] || { echo "[x] não achei $S" >&2; exit 1; }

mkdir -p "$H/.local/bin" "$H/.config" "$H/.themes" "$H/.local/share/applications" \
         "$H/.local/share/ambxst/icons" "$H/Desktop" "$H/Pictures/Wallpapers" \
         "$H/Documents" "$H/Downloads" "$H/Music" "$H/Videos" "$DEST/usr/share/backgrounds/infynit"

cp -a "$S"/bin/.          "$H/.local/bin/"
cp -a "$S"/cfg/.          "$H/.config/"
cp -a "$S"/themes/.       "$H/.themes/"
cp -a "$S"/applications/. "$H/.local/share/applications/"
cp -a "$S"/icons/.        "$H/.local/share/ambxst/icons/"
cp -a "$S"/desktop/.      "$H/Desktop/"
cp -a "$S"/wallpapers/.   "$H/Pictures/Wallpapers/"
cp -a "$S"/wallpapers/infynit.jpg "$DEST/usr/share/backgrounds/infynit/infynit.jpg"
cp -a "$S"/wallpapers/skull.jpg "$DEST/usr/share/backgrounds/infynit/skull.jpg"
touch "$H/Documents/.keep" "$H/Downloads/.keep" "$H/Music/.keep" "$H/Videos/.keep"

# ---- remove o que só faz sentido no Android/Termux
rm -f "$H/.local/bin/ambxst-twindesk" "$H/.local/bin/ambxst-brave" "$H/.local/bin/ambxst-session" \
      "$H/.local/share/applications/ambxst-twindesk.desktop" "$H/.local/share/applications/ambxst-brave.desktop" \
      "$H/Desktop/TwinDesk.desktop" "$H/Desktop/Brave.desktop"
sed -i '/ambxst-brave.desktop/d;/ambxst-twindesk.desktop/d' "$H/.config/tint2/dock.tint2rc"
sed -i '/<command>ambxst-brave<\/command>/d;/<command>ambxst-twindesk<\/command>/d' "$H/.config/openbox/menu.xml"
sed -i '/("Brave", \["ambxst-brave"\]),/d;/("TwinDesk", \["ambxst-twindesk"\]),/d' "$H/.local/bin/ambxst-panel"
sed -i '/\/Android /d;/\/Termux /d' "$H/.config/gtk-3.0/bookmarks"
# no PC, quem cuida de proteção de tela/DPMS é o xfce4-power-manager
sed -i '/^xset s off s noblank -dpms/d' "$H/.local/bin/ambxst-autostart"
# ajuda de atalhos: tira as linhas do Termux:X11
sed -i 's/^Teclado (teclado Bluetooth.*/Teclado:/; /^Toque (Termux:X11)/,/^(depende/d' "$H/.config/ambxst/ATALHOS.txt"

# ---- escolhas conferidas: se um corte acima não pegou, falha cedo (em vez de gerar uma ISO com botão morto)
if grep -rn 'ambxst-twindesk\|ambxst-brave' "$H/.config" "$H/.local/bin/ambxst-panel" "$H/.local/share/applications" >/dev/null 2>&1; then
  echo "[x] sobrou referência a TwinDesk/Brave no skel:" >&2
  grep -rn 'ambxst-twindesk\|ambxst-brave' "$H/.config" "$H/.local/bin/ambxst-panel" "$H/.local/share/applications" >&2
  exit 1
fi
python3 -m py_compile "$H/.local/bin/ambxst-panel" && rm -rf "$H/.local/bin/__pycache__"

echo "[ok] skel montado em $H"
