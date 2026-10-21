# Infynit AI — ISO para PC (amd64, BIOS + UEFI)

Transforma o desktop do Infynit AI (Openbox + tint2 + rofi + painel AMBXST + botões Claude Code,
OpenCode, Shannon, GitBot e Filmes/Animes) numa **ISO live e instalável** baseada no **Debian 13
"trixie"**, com os aplicativos de um desktop Linux completo.

> **Estado:** a montagem dos arquivos, as listas de pacotes e os scripts foram testados com
> ferramentas simuladas, mas **a ISO ainda não foi gerada nem iniciada de verdade**. O primeiro
> `lb build` real pode pedir um ajuste (nome de pacote, opção do live-build). Teste sempre numa
> máquina virtual antes de gravar num pendrive.

## Como gerar (escolha um caminho)

**1. Na nuvem do GitHub (recomendado se você só tem o celular).** O Termux/Android não consegue
montar uma ISO x86. Publique o projeto no GitHub e rode o workflow:
*Actions → Build ISO → Run workflow* (perfil `full` ou `lite`, `security` opcional).
Em 40–90 minutos a ISO aparece em **Artifacts** (`infynit-ai-iso`), com o `.sha256`.

**2. No seu PC com Docker** (Ubuntu, Fedora, Arch, WSL2…):

```bash
bash iso/docker-build.sh                      # perfil full
bash iso/docker-build.sh --profile lite       # só o essencial
bash iso/docker-build.sh --security           # + nmap, wireshark, sqlmap, hydra...
```

**3. Num Debian 12/13 (máquina real ou VM), como root:**

```bash
sudo bash iso/build.sh --profile full
```

A ISO sai em `iso/out/infynit-ai-<versão>-<perfil>-amd64.iso`. São necessários ~25 GB livres
(a ISO full pesa alguns GB) e internet.

## Perfis

| Perfil | O que tem |
|---|---|
| `full` (padrão) | Desktop Infynit AI + Firefox ESR, Thunderbird, LibreOffice, GIMP, Inkscape, Audacity, VLC, mpv, Evince, Transmission, FileZilla, Remmina, KeePassXC, GParted, Timeshift, Synaptic, impressoras, Bluetooth, Docker, Node.js, Python, Git e ferramentas de build |
| `lite` | Desktop Infynit AI + Firefox, Evince, mpv, GParted, Node.js, Python, Git |
| `--security` (extra) | nmap, Wireshark, tcpdump, sqlmap, Hydra, John, Hashcat, aircrack-ng, Nikto, Gobuster, Tor, proxychains… (pacotes do repositório Debian) |

As listas ficam em `iso/config/package-lists/` — é só editar e gerar de novo. Firmware de Wi-Fi/vídeo/som
(`non-free-firmware`) já vem incluído.

## Testar

```bash
bash iso/test-qemu.sh                 # BIOS
bash iso/test-qemu.sh --uefi          # UEFI (precisa do pacote ovmf)
```

Também funciona no VirtualBox/VMware/GNOME Boxes (4 GB de RAM, 2 CPUs).

## Usar

- **Gravar no pendrive:** Ventoy, balenaEtcher, Rufus (modo DD) ou `sudo dd if=...iso of=/dev/sdX bs=4M status=progress`.
- **Secure Boot:** se a máquina não iniciar, desative o Secure Boot na BIOS/UEFI.
- **Modo live:** entra sozinho na sessão **Infynit AI** com o usuário `ambxst` (senha `live`, `sudo` sem senha).
  O ícone **Instalar Infynit AI** na área de trabalho abre o instalador gráfico (Calamares).
- **Sistema instalado:** pede login pelo LightDM; escolha a sessão *Infynit AI*.
- Os botões **Claude Code / OpenCode / Shannon / GitBot / Filmes** funcionam como no Termux (1º toque instala).
  No PC o **Shannon roda de verdade**, porque o Docker existe (instalado no perfil `full`; depois de instalar
  o sistema rode `sudo usermod -aG docker $USER` e faça logout/login).
- O **login** (criar conta/entrar) e os botões de **Segurança** (OSINT/Red Team/Blue Team/Purple Team)
  funcionam do mesmo jeito que no Termux, sem passos extras — veja as seções
  [Login](../README.md#login) e [Segurança](../README.md#segurança-osint-red-team-blue-team-e-purple-team)
  no README principal. No PC, os botões de Segurança instalam via `sudo apt` (sem o vigia do Termux).

## O que muda em relação ao desktop do Termux

| Termux | ISO para PC |
|---|---|
| Sessão iniciada por `ambxst-start` (proot + Termux:X11) | LightDM → `infynit-session` → Openbox |
| Energia = encerrar sessão | Bloquear, encerrar, suspender, reiniciar, desligar |
| Configurações básicas | + Rede, Bluetooth, Som, Telas, Energia, Impressoras, Discos |
| Brave / TwinDesk / pastas Android e Termux | removidos |
| Pacotes de sistema via vigia do Termux | `sudo apt` (sem senha no live) |
| Usuário fixo `ambxst` | qualquer usuário (`ambxst-firstrun` ajusta os caminhos) |

## Limitações conhecidas

- Só **amd64**. Para ARM (Raspberry Pi etc.) seria outra imagem.
- O **instalador Calamares** é a parte menos testada: valide uma instalação completa em VM (BIOS e UEFI) antes de distribuir.
- O Docker pode não subir **dentro do modo live** (sistema de arquivos em camadas); no sistema instalado funciona.
- `infynit.jpg` (papel de parede e fundo do login do LightDM), `skull.jpg` e `login-avatar.jpg`
  (avatar da tela "Criar conta"/"Entrar") não foram criadas por este projeto: troque antes de
  distribuir a ISO publicamente, se não tiver direito de redistribuí-las.
- Sem criptografia de disco/LVM pré-configurada além do que o Calamares oferece.
