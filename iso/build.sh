#!/bin/bash
# build.sh - gera a ISO do Infynit AI (live-build, Debian 13 "trixie", amd64, BIOS + UEFI).
#
# Rode como root num Debian 12/13 (ou use iso/docker-build.sh, que faz isso dentro de um contêiner).
# Não funciona no Termux/Android nem em Ubuntu puro (o live-build do Ubuntu é uma versão antiga).
#
# Uso: sudo bash iso/build.sh [--profile full|lite] [--security] [--out DIR] [--work DIR] [--dist trixie] [--clean]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PROFILE="${PROFILE:-full}"
SECURITY="${SECURITY:-0}"
OUT="${OUT:-$HERE/out}"
WORK="${WORK:-$HERE/work}"
DIST="${DIST:-trixie}"
CLEAN=0

say()  { printf '\033[36m[iso]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:?}"; shift 2 ;;
    --security) SECURITY=1; shift ;;
    --out) OUT="${2:?}"; shift 2 ;;
    --work) WORK="${2:?}"; shift 2 ;;
    --dist) DIST="${2:?}"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) fail "opção desconhecida: $1" ;;
  esac
done
case "$PROFILE" in full|lite) ;; *) fail "--profile deve ser full ou lite" ;; esac
[ "$(uname -m)" = x86_64 ] || fail "esta ISO é amd64; rode num PC/servidor x86_64 (no Termux/ARM não dá)."
[ "$(id -u)" = 0 ] || fail "rode como root: sudo bash iso/build.sh ..."
command -v apt-get >/dev/null 2>&1 || fail "precisa de um Debian/Ubuntu (apt-get) como máquina de build."

VERSION="$(grep -m1 '"version"' "$ROOT/package.json" | sed 's/.*"version": *"\([^"]*\)".*/\1/')"
SUFFIX=""; if [ "$SECURITY" = 1 ]; then SUFFIX="-security"; fi
IMAGE="infynit-ai-${VERSION}-${PROFILE}${SUFFIX}-amd64"

# ---------------------------------------------------------------- dependências de build
need=""
for c in lb debootstrap mksquashfs xorriso mformat; do command -v "$c" >/dev/null 2>&1 || need=1; done
if [ -n "$need" ]; then
  say "instalando ferramentas de build (live-build, debootstrap, xorriso, squashfs-tools...)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends live-build debootstrap squashfs-tools xorriso mtools dosfstools \
    syslinux syslinux-common isolinux grub-pc-bin grub-efi-amd64-bin rsync cpio zstd ca-certificates gnupg
fi
if ! grep -qi debian /etc/os-release; then
  say "AVISO: este host não é Debian. Se o 'lb build' falhar logo no início, use iso/docker-build.sh."
fi

# ---------------------------------------------------------------- área de trabalho
if [ -d "$WORK" ] && [ "$CLEAN" = 1 ]; then
  say "limpando $WORK"; (cd "$WORK" && lb clean --purge >/dev/null 2>&1 || true); rm -rf "$WORK"
fi
mkdir -p "$WORK" "$OUT"
rm -rf "$WORK/config"
cp -a "$HERE/config" "$WORK/config"

# o skel do Termux entra primeiro; os arquivos de iso/config/includes.chroot (versões do PC) vêm por cima
INC="$WORK/config/includes.chroot"
mv "$INC" "$WORK/overlay"
mkdir -p "$INC"
bash "$HERE/stage-skel.sh" "$ROOT" "$INC"
cp -a "$WORK/overlay/." "$INC/"
rm -rf "$WORK/overlay"
find "$INC/etc/skel/.local/bin" "$INC/usr/local/bin" "$INC/usr/local/lib" -type f -exec chmod 755 {} +
find "$INC/etc/skel/Desktop" "$INC/etc/skel/.local/share/applications" -name '*.desktop' -exec chmod 755 {} +

# listas de pacotes conforme o perfil
PL="$WORK/config/package-lists"
if [ "$PROFILE" = full ]; then rm -f "$PL/apps-lite.list.chroot"; else rm -f "$PL/apps-full.list.chroot"; fi
[ "$SECURITY" = 1 ] || rm -f "$PL/security.list.chroot"
say "perfil: $PROFILE   security: $SECURITY   versão: $VERSION   distro: $DIST"

# ---------------------------------------------------------------- live-build
cd "$WORK"
lb config noauto \
  --distribution "$DIST" \
  --archive-areas "main contrib non-free non-free-firmware" \
  --apt-recommends false \
  --security true --updates true \
  --chroot-squashfs-compression-type xz \
  --image-name infynit-ai \
  --iso-application "Infynit AI" --iso-publisher "Infynit AI" --iso-volume "INFYNIT_AI" \
  --bootappend-live "boot=live components quiet live-config.username=ambxst live-config.hostname=infynit-ai live-config.user-fullname=Infynit-AI live-config.locales=pt_BR.UTF-8 live-config.keyboard-layouts=br live-config.timezone=America/Sao_Paulo username=ambxst hostname=infynit-ai locales=pt_BR.UTF-8 keyboard-layouts=br timezone=America/Sao_Paulo"

say "construindo (isso leva de 30 a 90 minutos e baixa vários GB)..."
lb build 2>&1 | tee "$WORK/build.log"

ISO="$(ls -1 "$WORK"/*.iso 2>/dev/null | head -n1 || true)"
[ -n "$ISO" ] || fail "o live-build terminou sem gerar a ISO; veja $WORK/build.log"
mv -f "$ISO" "$OUT/$IMAGE.iso"
( cd "$OUT" && sha256sum "$IMAGE.iso" > "$IMAGE.iso.sha256" )
say "pronto: $OUT/$IMAGE.iso ($(du -h "$OUT/$IMAGE.iso" | cut -f1))"
say "sha256: $(cut -d' ' -f1 "$OUT/$IMAGE.iso.sha256")"
