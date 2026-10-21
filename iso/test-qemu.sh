#!/bin/bash
# test-qemu.sh - testa a ISO numa máquina virtual (QEMU). Uso: bash iso/test-qemu.sh [arquivo.iso] [--uefi]
set -euo pipefail
ISO="${1:-}"; [ -n "$ISO" ] && [ "${ISO#--}" = "$ISO" ] && shift || ISO=""
[ -n "$ISO" ] || ISO="$(ls -1t "$(dirname "$0")"/out/*.iso 2>/dev/null | head -n1 || true)"
[ -f "$ISO" ] || { echo "[x] ISO não encontrada. Passe o caminho: bash iso/test-qemu.sh arquivo.iso" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "[x] instale o QEMU (qemu-system-x86)." >&2; exit 1; }
ARGS=(-m 4096 -smp 2 -cdrom "$ISO" -boot d -device virtio-vga -display gtk -nic user,model=virtio-net-pci -device intel-hda -device hda-duplex)
[ -e /dev/kvm ] && ARGS+=(-enable-kvm -cpu host)
if [ "${1:-}" = "--uefi" ]; then
  FW="$(ls /usr/share/OVMF/OVMF_CODE*.fd /usr/share/ovmf/OVMF.fd 2>/dev/null | head -n1 || true)"
  [ -n "$FW" ] || { echo "[x] firmware UEFI (pacote ovmf) não encontrado." >&2; exit 1; }
  ARGS+=(-bios "$FW")
fi
echo "[i] iniciando: qemu-system-x86_64 ${ARGS[*]}"
exec qemu-system-x86_64 "${ARGS[@]}"
