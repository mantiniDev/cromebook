#!/usr/bin/env bash
# Prepara o Chromebook para administrar e modificar o idbike (www.idbike.com.br)
#
# Uso (SEM sudo; o script pede a senha quando precisa):
#   bash idbike-admin/instalar.sh
#
# Instala: git, GitHub CLI, Node.js 22 (o mesmo dos testes no GitHub), editor Geany,
# e opcionalmente Netlify CLI e Claude Code. Baixa o código em ~/idbike e cria
# os ícones "idbike admin", "idbike app", "idbike local" e "idbike testes".

set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
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
    echo "Escolha: GitHub.com → HTTPS → Yes → Login with a web browser."
    echo "Ele mostra um código; o Firefox abre e você cola o código lá."
    gh auth login --hostname github.com --git-protocol https --web
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
titulo "7. Ícones no menu e na área de trabalho"
mkdir -p "$DADOS" "$BIN" "$APPS"
cp "$AQUI/painel.html" "$DADOS/painel.html"

icone=applications-internet
if [[ -f $CODIGO/marca/idbike-simbolo-1024px.png ]]; then
    cp "$CODIGO/marca/idbike-simbolo-1024px.png" "$DADOS/idbike.png"
    icone="$DADOS/idbike.png"
fi

cat > "$BIN/idbike-local" <<EOF
#!/usr/bin/env bash
# Roda o app do idbike no Chromebook (http://localhost:8080/app/)
cd "$CODIGO" || exit 1
git pull --ff-only
(sleep 2; xdg-open http://localhost:8080/app/) &
echo "App em http://localhost:8080/app/  (feche esta janela ou Ctrl+C para parar)"
python3 -m http.server 8080 --directory site
EOF

cat > "$BIN/idbike-testes" <<EOF
#!/usr/bin/env bash
# Confere a sintaxe e roda os testes do idbike (o mesmo que o GitHub faz)
cd "$CODIGO" || exit 1
ok=1
for f in site/app/js/*.js netlify/functions/*.mjs netlify/lib/*.mjs; do
    node --check "\$f" || ok=0
done
node --test "tests/*.test.mjs" || ok=0
echo
if [[ \$ok -eq 1 ]]; then echo "TUDO CERTO: pode enviar."; else echo "ALGO FALHOU: veja acima."; fi
read -rp "Enter para fechar..."
EOF
chmod +x "$BIN/idbike-local" "$BIN/idbike-testes"

criar_atalho() {  # arquivo nome comentario comando
    cat > "$APPS/$1.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Comment=$3
Exec=$4
Icon=$icone
Terminal=false
Categories=Development;
EOF
    chmod +x "$APPS/$1.desktop"
}
criar_atalho idbike-admin "idbike admin" "Painel com todos os acessos do idbike" \
    "firefox --new-window file://$DADOS/painel.html"
criar_atalho idbike-app "idbike app" "Abrir o app publicado" \
    "firefox --new-window https://www.idbike.com.br/app/"
criar_atalho idbike-local "idbike local" "Rodar o app no Chromebook" \
    "x-terminal-emulator -e $BIN/idbike-local"
criar_atalho idbike-testes "idbike testes" "Rodar os testes automáticos" \
    "x-terminal-emulator -e $BIN/idbike-testes"

mesa=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")
if [[ -d $mesa ]]; then
    for a in idbike-admin idbike-app idbike-local idbike-testes; do
        cp "$APPS/$a.desktop" "$mesa/"
    done
fi
update-desktop-database "$APPS" 2>/dev/null
verde "Ícones criados no menu (Programação) e na área de trabalho."

# ---------------------------------------------------------------------------
titulo "Pronto"
echo "- Ícone 'idbike admin': painel com Netlify, Supabase, Mercado Pago, Strava, consultas SQL..."
echo "- Na primeira vez, a área de trabalho pode perguntar se confia no ícone: responda que sim."
echo "- Faça login uma vez em cada serviço no Firefox; ele lembra depois."
