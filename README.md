# bora-linux

Script interativo de setup para **Ubuntu / Linux Mint / Pop!_OS**.
Instala e configura tudo de uma vez numa maquina recem formatada.

> Sem Snap. Tudo via APT + Flatpak.

## Uso

```bash
git clone https://github.com/anaice/bora-linux.git
cd bora-linux
sudo ./install.sh
```

Flags:

```bash
sudo ./install.sh -v          # modo verbose
sudo ./install.sh --lang=en   # forcar idioma (pt-br | en)
sudo ./install.sh -h          # ajuda
```

Durante a execucao, pressione **v** a qualquer momento para alternar entre modo compacto e verbose.

## O que faz

O script usa [gum](https://github.com/charmbracelet/gum) para menus interativos onde voce escolhe o que instalar. Cada etapa tem um sub-menu para selecionar pacotes individuais.

| Etapa | Default | O que faz |
|---|---|---|
| Cleanup | OFF | Remove fontes APT duplicadas, chaves GPG orfas, Snap completo |
| Repositorios APT | ON | Configura repos: 1Password, Brave, Chrome, Docker, Mise, Eza, AnyDesk |
| Atualizar sistema | OFF | `apt update` + `apt upgrade` + `apt dist-upgrade` |
| Pacotes APT | ON | bat, fzf, eza, btop, Docker, Neovim, ripgrep, vlc, meld, etc |
| Pacotes Flatpak | ON | VS Code, Insomnia, Postman, Draw.io, Discord, Flameshot, DBeaver, etc |
| Nerd Fonts | ON | JetBrainsMono Nerd Font |
| Scripts externos | ON | JetBrains Toolbox, Lazygit, Lazydocker, Calibre, Claude Code, Zed, Starship, Evolus Pencil |
| Linguagens (Mise) | ON | Java, Ruby, Flutter, Python, Go, Rust, Clojure, Elixir |
| LazyVim | ON | Clona LazyVim starter config |
| Starship | ON | Prompt com escolha de preset (bora, tokyo-night, gruvbox, etc) |
| ZSH | ON | Zoxide, plugins, `.zshrc` completo com aliases |
| Temas | OFF | Temas GTK, icones e cursores (Orchis, Colloid, Fluent, Papirus, Bibata, etc) |
| Google Drive | OFF | rclone bisync com sync automatico via systemd timer |
| Ajustes finais | ON | Docker group, ZSH padrao, PATH |

## Estrutura do projeto

```
bora-linux/
├── install.sh                          # Script principal
├── configs/
│   └── starship/
│       ├── bora.toml                   # Preset bora (dark hacker, devops)
│       ├── pastel-powerline.toml       # Powerline pastel
│       ├── tokyo-night.toml            # Tokyo Night escuro
│       ├── gruvbox-rainbow.toml        # Tons quentes retro
│       └── catppuccin-powerline.toml   # Catppuccin pastel
├── lang/
│   ├── pt-br.sh                        # Portugues (Brasil)
│   └── en.sh                           # English
└── README.md
```

## Starship Presets

Na etapa Starship voce escolhe entre 5 temas:

| Preset | Estilo |
|---|---|
| **bora** | Dark hacker — duas linhas, minimal, devops-focused |
| **pastel-powerline** | Powerline com cores pastel |
| **tokyo-night** | Paleta escura azul/roxo |
| **gruvbox-rainbow** | Tons quentes estilo retro |
| **catppuccin-powerline** | Powerline pastel Catppuccin |

Todos detectam automaticamente o icone do OS (Ubuntu, Mint, Pop, Arch, etc).

Requer [Nerd Font](https://www.nerdfonts.com/) — o script instala JetBrainsMono automaticamente. Lembre de configurar a fonte no terminal.

### Preset bora

Prompt dark e minimalista focado em DevOps:
- Icone do OS + diretorio
- Git branch + status + metricas (+/-)
- Docker, Kubernetes, Terraform, AWS, GCloud
- Linguagens (Java, Ruby, Python, Node, Go, Rust, etc)
- Duracao do comando + hora
- Paleta Dracula-inspired com tons de verde, roxo e cyan

## ZSH

O script gera um `.zshrc` completo com:
- **Aliases**: `ls` (eza), `cat` (bat), `ff` (fzf), atalhos git, docker, rails, nvim
- **Aliases Flatpak**: todos os apps Flatpak acessiveis por nome (flameshot, discord, code, dbeaver, etc)
- **Zoxide**: `cd` inteligente que aprende seus diretorios
- **Plugins**: autosuggestions, syntax-highlighting, history-substring-search
- **Keybinds**: Ctrl+setas (navegar palavras), Alt+setas (inicio/fim da linha)
- **Deteccao de distro**: aliases `install`/`remove`/`upgrade` funcionam em apt, pacman e dnf

### Aliases

| Alias | Comando |
|---|---|
| `ls` | `eza -lh --group-directories-first --icons=auto` |
| `lt` | `eza --tree --level=2 --long --icons --git` |
| `n` | `nvim .` ou `nvim <arquivo>` |
| `cat` | `bat` (syntax highlight) |
| `ff` | `fzf` com preview via bat |
| `g` | `git` |
| `gs` | `git status` |
| `gcm` | `git commit -m` |
| `lg` | `lazygit` |
| `ld` | `lazydocker` |
| `flameshot` | Flameshot via Flatpak |
| `code` | VS Code via Flatpak |
| `discord` | Discord via Flatpak |
| `dbeaver` | DBeaver via Flatpak |
| `install` | `sudo apt install` (ou pacman/dnf) |
| `upgrade` | `sudo apt update && sudo apt upgrade` |

## Temas (GTK + Icones + Cursores)

Todos compativeis com GNOME e Cinnamon:

| Tipo | Tema |
|---|---|
| GTK | Orchis, Colloid, Fluent, Graphite, Lavanda |
| Icones | Papirus, Tela, Colloid Icons |
| Cursores | Bibata Modern |

## Google Drive

Sync bidirecional com rclone:
- Sync automatico a cada 15 minutos via systemd timer
- Suporte a multiplas contas
- Sync seletivo por pastas

```bash
~/.local/bin/gdrive-sync.sh                    # sync manual
tail -f ~/.local/share/gdrive-sync.log         # acompanhar
systemctl --user status gdrive-sync.timer      # status do timer
```

## Internacionalizacao

O script detecta o idioma do sistema automaticamente. Para forcar:

```bash
sudo ./install.sh --lang=en      # English
sudo ./install.sh --lang=pt-br   # Portugues
```

## Requisitos

- Ubuntu 22.04+ / Linux Mint 21+ / Pop!_OS 22.04+
- Executar como `sudo`
- Conexao com internet

## Licenca

MIT
