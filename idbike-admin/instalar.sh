#!/usr/bin/env bash
# Prepara o Chromebook para administrar e modificar o idbike (www.idbike.com.br)
#
# Uso (SEM sudo; o script pede a senha quando precisa):
#   bash idbike-admin/instalar.sh
#
# Instala: git, GitHub CLI, Node.js 22 (o mesmo dos testes no GitHub), editor Geany,
# e opcionalmente Netlify CLI e Claude Code. Baixa o código em ~/idbike e cria
# o ícone "idbike painel", que abre idbike.com.br/admin.

set -uo pipefail

CODIGO="$HOME/idbike"
DADOS="$HOME/.local/share/idbike-admin"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"

verde() { printf '\e[32m%s\e[0m\n' "$*"; }
amarelo() { printf '\e[33m%s\e[0m\n' "$*"; }
titulo() { printf '\n\e[1;36m== %s ==\e[0m\n' "$*"; }
tem() { command -v "$1" >/dev/null 2>&1; }

perguntar() {
    local padrao="${2:-s}" opcoes="[S/n]"
    [[ $padrao == n ]] && opcoes="[s/N]"
    read -rp "$1 $opcoes " resp
    resp="${resp:-$padrao}"
    [[ ${resp,,} == s* ]]
}

if [[ $EUID -eq 0 ]]; then
    echo "Rode sem sudo: bash $0"
    exit 1
fi
if ! tem apt-get; then
    echo "Este script é para Ubuntu/Lubuntu (apt)."
    exit 1
fi

# ---------------------------------------------------------------------------
titulo "1. Ferramentas básicas (git, GitHub CLI, Geany)"
sudo apt-get update -qq
sudo apt-get install -y git gh geany python3 curl gpg
verde "Ferramentas básicas instaladas."

# ---------------------------------------------------------------------------
titulo "2. Node.js 22"
echo "Os testes do idbike usam Node 22 (o Ubuntu 24.04 vem com o 18, antigo demais)."
versao=$(node -v 2>/dev/null | sed 's/^v//; s/\..*//')
if [[ ${versao:-0} -ge 22 ]]; then
    verde "Node $(node -v) já instalado."
else
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y nodejs
    verde "Node $(node -v) instalado."
fi

# ---------------------------------------------------------------------------
titulo "3. Entrar no GitHub"
if gh auth status >/dev/null 2>&1; then
    verde "Já conectado ao GitHub."
else
    echo "Ele mostra um código; o Firefox abre e você cola o código lá."
    echo "Em 'Authenticate Git with your GitHub credentials?' responda Y."
    # --insecure-storage: guarda o acesso em ~/.config/gh (só seu usuário lê).
    # Sem isso, no LXQt o gh pode ficar parado esperando um chaveiro de senhas
    # que não existe, e o login nunca termina de ser salvo.
    gh auth login --hostname github.com --git-protocol https --web --insecure-storage
    if ! gh auth status >/dev/null 2>&1; then
        amarelo "O login no GitHub não foi salvo. Rode 'gh auth status' e mande a mensagem."
        exit 1
    fi
fi
gh auth setup-git >/dev/null 2>&1
if [[ -z $(git config --global user.name) ]]; then
    read -rp "Seu nome para os commits (ex.: Paulo Mantini): " nome
    git config --global user.name "$nome"
fi
if [[ -z $(git config --global user.email) ]]; then
    read -rp "Seu e-mail do GitHub: " email
    git config --global user.email "$email"
fi

# ---------------------------------------------------------------------------
titulo "4. Código do idbike em ~/idbike"
if [[ -d $CODIGO/.git ]]; then
    git -C "$CODIGO" pull --ff-only && verde "Código atualizado."
else
    gh repo clone mantiniDev/idbike "$CODIGO" && verde "Código baixado em $CODIGO."
fi

# ---------------------------------------------------------------------------
titulo "5. Netlify CLI (opcional)"
echo "Serve para publicar e ver os logs das funções pelo terminal (~300 MB)."
echo "Dá para fazer tudo isso pelo site app.netlify.com também."
if perguntar "Instalar a Netlify CLI?" n; then
    sudo npm install -g netlify-cli
    echo "Agora entre na sua conta e ligue a pasta ao site:"
    (cd "$CODIGO" && netlify login && netlify link)
fi

# ---------------------------------------------------------------------------
titulo "6. Claude Code no terminal (opcional)"
echo "Pedir mudanças no idbike direto do terminal. Pelo navegador (claude.ai/code) já funciona."
if perguntar "Instalar o Claude Code?" n; then
    curl -fsSL https://claude.ai/install.sh | bash
fi

# ---------------------------------------------------------------------------
titulo "7. Ícone 'idbike painel' no menu e na área de trabalho"
mkdir -p "$DADOS" "$APPS"
mesa=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")

# Ícones de versões anteriores deste script (o admin do site substituiu o painel local)
for a in idbike-admin idbike-app idbike-local idbike-testes; do
    rm -f "$APPS/$a.desktop" "$mesa/$a.desktop"
done
rm -f "$DADOS/painel.html" "$BIN/idbike-local" "$BIN/idbike-testes"

icone=applications-internet
if [[ -f $CODIGO/marca/idbike-simbolo-1024px.png ]]; then
    cp "$CODIGO/marca/idbike-simbolo-1024px.png" "$DADOS/idbike.png"
    icone="$DADOS/idbike.png"
fi

cat > "$APPS/idbike-painel.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=idbike painel
Comment=Números e administração do idbike (login + autenticador)
Exec=firefox --new-window https://www.idbike.com.br/admin/
Icon=$icone
Terminal=false
Categories=Development;
EOF
chmod +x "$APPS/idbike-painel.desktop"
[[ -d $mesa ]] && cp "$APPS/idbike-painel.desktop" "$mesa/"
update-desktop-database "$APPS" 2>/dev/null
verde "Ícone 'idbike painel' criado no menu (Programação) e na área de trabalho."

# ---------------------------------------------------------------------------
titulo "Pronto"
echo "- Ícone 'idbike painel': idbike.com.br/admin (números, clientes, cortesias e os acessos)"
echo "- Na primeira vez, a área de trabalho pode perguntar se confia no ícone: responda que sim."
