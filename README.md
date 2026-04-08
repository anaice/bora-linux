# bora-linux

Setup pos-instalacao para **Ubuntu / Mint / Pop!_OS** e **Arch / CachyOS / Garuda**.

Sem Snap. Tudo via pacman/APT + Flatpak.

## Uso

```bash
git clone https://github.com/anaice/bora-linux.git
cd bora-linux

# Ubuntu / Mint / Pop!_OS
sudo ./install.sh

# Arch / CachyOS / Garuda
sudo ./install-arch.sh
```

```bash
-v            # verbose
--lang=en     # forcar idioma (pt-br | en)
-h            # ajuda
```

Pressione **v** durante a execucao para alternar verbose.

## Etapas

Tudo eh selecionavel via menu interativo ([gum](https://github.com/charmbracelet/gum)).

### Ubuntu / Mint / Pop!_OS

| Etapa | O que faz |
|---|---|
| Cleanup | Remove fontes APT duplicadas, chaves GPG orfas, Snap |
| Repositorios | 1Password, Brave, Chrome, Docker, Mise, Eza, AnyDesk, Ulauncher |
| Atualizar | `apt update && upgrade && dist-upgrade` |
| Pacotes APT | bat, fzf, eza, btop, Docker, Neovim, ripgrep, etc |
| Flatpak | VS Code, Insomnia, Postman, Draw.io, Discord, DBeaver, ZapZap, etc |
| Fonts | JetBrainsMono Nerd Font |
| Scripts | JetBrains Toolbox, Claude Code, Zed, Tabby, Cursor, Pencil, etc |
| Mise | Java, Ruby, Flutter, Python, Go, Rust, Clojure, Elixir |
| LazyVim | Starter config do Neovim |
| Starship | Prompt com 5 presets |
| ZSH | Plugins, aliases, keybinds |
| Temas | GTK + icones + cursores |
| Google Drive | rclone bisync + systemd timer |
| Ajustes | Docker group, ZSH padrao, presets Cinnamon |

### Arch / CachyOS / Garuda

| Etapa | O que faz |
|---|---|
| Cleanup | Remove pacotes orfaos, Flatpaks nao usados |
| Atualizar | reflector (mirrors) + `pacman -Syu` |
| Pacotes | pacman + AUR (yay): bat, fzf, eza, btop, Docker, Neovim, Brave, Chrome, Tabby, Cursor, etc |
| Flatpak | VS Code, Insomnia, Postman, Draw.io, Discord, DBeaver, ZapZap, etc |
| Fonts | JetBrainsMono Nerd Font |
| Apps | JetBrains Toolbox, Claude Code, Zed |
| Mise | Java, Ruby, Flutter, Python, Go, Rust, Clojure, Elixir |
| LazyVim | Starter config do Neovim |
| Starship | Prompt com 5 presets |
| ZSH | Plugins, aliases, keybinds |
| Temas | GTK + icones + cursores |
| Google Drive | rclone bisync + systemd timer |
| Teclado | US Intl com cedilha (XCompose) |
| Ajustes | Docker group, ZSH padrao, KRunner centralizado, autostart apps |

## Starship

5 presets de prompt:

| Preset | Estilo |
|---|---|
| bora | Dark, minimal, duas linhas, devops |
| pastel-powerline | Powerline pastel |
| tokyo-night | Azul/roxo escuro |
| gruvbox-rainbow | Tons quentes retro |
| catppuccin-powerline | Powerline Catppuccin |

Detecta icone do OS automaticamente. Requer Nerd Font (instalada pelo script).

## ZSH

`.zshrc` completo com:
- Zoxide (cd inteligente)
- Plugins: autosuggestions, syntax-highlighting, history-substring-search
- Aliases Flatpak (code, discord, dbeaver, zapzap, etc)
- Atalhos git, docker, nvim
- Keybinds: Ctrl+setas (palavras), Alt+setas (inicio/fim)
- `install`/`remove`/`upgrade` funcionam em apt, pacman e dnf

## Google Drive

Sync bidirecional com rclone:
- Automatico a cada 15 min via systemd timer
- Multiplas contas
- Pastas selecionaveis

```bash
~/.local/bin/gdrive-sync.sh                # sync manual
systemctl --user status gdrive-sync.timer  # status
```

## Estrutura

```
bora-linux/
├── install.sh          # Ubuntu / Mint / Pop!_OS
├── install-arch.sh     # Arch / CachyOS / Garuda
├── configs/
│   ├── starship/       # 5 presets de prompt
│   ├── cinnamon/       # Presets Cinnamon (atalhos, cantos, gestos)
│   ├── gnome/          # Presets GNOME
│   └── keyboard/       # US Intl com cedilha
├── lang/
│   ├── pt-br.sh
│   └── en.sh
└── README.md
```

## Requisitos

- Ubuntu 22.04+ / Mint 21+ / Pop!_OS 22.04+ ou Arch Linux / CachyOS / Garuda
- `sudo`
- Internet

## Licenca

MIT
