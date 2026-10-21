#!/bin/bash
# docker-build.sh - gera a ISO dentro de um contêiner Debian trixie (funciona em Ubuntu, Fedora, Arch, WSL2 com Docker...).
# Uso: bash iso/docker-build.sh [opções do build.sh, ex.: --profile lite --security]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v docker >/dev/null 2>&1 || { echo "[x] precisa do Docker instalado." >&2; exit 1; }
mkdir -p "$ROOT/iso/out"
exec docker run --rm --privileged \
  -v "$ROOT:/work" -w /work \
  -e DEBIAN_FRONTEND=noninteractive \
  debian:trixie \
  bash -c 'apt-get update && apt-get install -y --no-install-recommends ca-certificates && bash iso/build.sh --out /work/iso/out --work /tmp/infynit-work "$@"' _ "$@"
