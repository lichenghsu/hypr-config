if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -gx BROWSER zen-browser


# opencode and local bin
fish_add_path $HOME/.opencode/bin
fish_add_path $HOME/.local/bin

set -g fish_greeting ""

function fish_prompt
    set_color brgreen
    echo -n (prompt_pwd) # Mostra la cartella corrente abbreviata
    set_color normal
    echo -n " > "
end



# Pacman base
abbr -a i 'sudo pacman -S'       # Installa
abbr -a syu 'sudo pacman -Syu'     # Aggiorna sistema
abbr -a r 'sudo pacman -Rns'      # Rimuove con dipendenze inutilizzate
abbr -a pacc 'pacman -Ss'           # Cerca nei repo
abbr -a pace 'pacman -Qe'         # Elenca pacchetti installati esplicitamente

# Se usi un AUR helper (es. yay o paru)
abbr -a y 'yay'                     # Scorciatoia universale per AUR
abbr -a yi 'yay -S'
abbr -a ysyu 'yay -Syu'

# Git
abbr -a gs 'git status'
abbr -a ga 'git add'
abbr -a gc 'git commit -m'
abbr -a gp 'git push'


# Added by Antigravity CLI installer
set -gx PATH "/home/miles/.local/bin" $PATH

# Krew 
set -gx PATH $PATH $HOME/.krew/bin

# Kind update
# 更新 kind binary 到最新的函式
function kind_update
    set -l target_version $argv[1]
    if test -z "$target_version"
        set url "https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64"
        echo "⬇️ 正在下載最新版 kind..."
    else
        set url "https://kind.sigs.k8s.io/dl/$target_version/kind-linux-amd64"
        echo "⬇️ 正在下載指定版本 kind ($target_version)..."
    end

    curl -Lo /tmp/kind $url
    and chmod +x /tmp/kind
    and sudo mv /tmp/kind /usr/local/bin/kind
    and echo "✅ kind 更新成功！"
    and kind version
end

# Alias
alias kupdate="kind_update"
alias kind-update="kind_update"

fish_add_path ~/Apps/termagotchi

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
set --export --prepend PATH "/home/miles/.rd/bin"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
