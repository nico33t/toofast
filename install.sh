#!/bin/bash
# nt-deploy installer (macOS / Linux)
# Uso: ./install.sh   oppure   curl -fsSL <url>/install.sh | bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="$HOME/.nt-tools"
SCRIPT_PATH="$INSTALL_DIR/nt-deploy.sh"

echo -e "${BLUE}🔪 nt-deploy installer${NC}"
echo ""

# 1. Controlla Node.js (necessario per wrangler)
if ! command -v node &> /dev/null; then
  echo -e "${RED}❌ Node.js non trovato${NC}"
  echo ""
  echo "Installa Node.js prima di continuare:"
  echo "  • macOS:  brew install node"
  echo "  • Linux:  https://nodejs.org/"
  exit 1
fi
echo -e "${GREEN}✓${NC} Node.js trovato ($(node --version))"

# 2. Installa wrangler se manca
if ! command -v wrangler &> /dev/null; then
  echo -e "${YELLOW}⚙️  Installo wrangler (Cloudflare CLI)...${NC}"
  npm install -g wrangler
fi
echo -e "${GREEN}✓${NC} wrangler installato ($(wrangler --version 2>&1 | head -1))"

# 3. Crea cartella e copia script
mkdir -p "$INSTALL_DIR"

if [ -f "./scripts/nt-deploy.sh" ]; then
  cp ./scripts/nt-deploy.sh "$SCRIPT_PATH"
else
  # fallback: download da GitHub se eseguito via curl
  REPO_URL="${NT_REPO_URL:-https://raw.githubusercontent.com/nico33t/nt-deploy/main}"
  echo -e "${BLUE}📥 Scarico script da $REPO_URL${NC}"
  curl -fsSL "$REPO_URL/scripts/nt-deploy.sh" -o "$SCRIPT_PATH"
fi

chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}✓${NC} Script installato in $SCRIPT_PATH"

# 3b. Copia la GUI (best-effort)
if [ -f "./scripts/nt-gui.py" ]; then
  cp ./scripts/nt-gui.py "$INSTALL_DIR/nt-gui.py"
else
  REPO_URL="${NT_REPO_URL:-https://raw.githubusercontent.com/nico33t/nt-deploy/main}"
  curl -fsSL "$REPO_URL/scripts/nt-gui.py" -o "$INSTALL_DIR/nt-gui.py" 2>/dev/null || true
fi
[ -f "$INSTALL_DIR/nt-gui.py" ] && echo -e "${GREEN}✓${NC} GUI installata in $INSTALL_DIR/nt-gui.py"

# 4. Determina shell rc file
SHELL_RC=""
if [ -n "$ZSH_VERSION" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ "$(basename "$SHELL")" = "bash" ]; then
  if [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  else
    SHELL_RC="$HOME/.bash_profile"
  fi
else
  SHELL_RC="$HOME/.profile"
fi

# 5. Aggiungi alias se non già presenti
NT="~/.nt-tools/nt-deploy.sh"
ALIAS_BLOCK="# >>> nt-deploy >>>
alias nt='$NT'
# deploy
alias nt-push='$NT push'
alias nt-ship='$NT ship'
alias nt-bp='$NT bp'
# time machine
alias nt-rollback='$NT rollback'
alias nt-snapshots='$NT snapshots'
# gestione
alias nt-list='$NT list'
alias nt-clients='$NT clients'
alias nt-projects='$NT projects'
alias nt-rm='$NT rm'
alias nt-rmproject='$NT rmproject'
alias nt-logs='$NT logs'
alias nt-open='$NT open'
alias nt-copy='$NT copy'
# qualità & traffico
alias nt-audit='$NT audit'
alias nt-analytics='$NT analytics'
alias nt-stats='$NT analytics stats'
# toolkit
alias nt-serve='$NT serve'
alias nt-create='$NT create'
alias nt-design='$NT design'
alias nt-new='$NT new'
alias nt-card='$NT card'
alias nt-build='$NT build'
alias nt-size='$NT size'
alias nt-zip='$NT zip'
alias nt-images='$NT images'
alias nt-check='$NT check'
alias nt-qr='$NT qr'
alias nt-clean='$NT clean'
alias nt-doctor='$NT doctor'
alias nt-notes='$NT notes'
alias nt-gui='$NT gui'
# setup
alias nt-init='$NT init'
alias nt-config='$NT config'
alias nt-update='$NT update'
alias nt-version='$NT version'
alias nt-help='$NT help'
# <<< nt-deploy <<<"

if grep -q ">>> nt-deploy >>>" "$SHELL_RC" 2>/dev/null; then
  echo -e "${YELLOW}⚠️  Alias già presenti in $SHELL_RC, non aggiunti di nuovo${NC}"
else
  echo "" >> "$SHELL_RC"
  echo "$ALIAS_BLOCK" >> "$SHELL_RC"
  echo -e "${GREEN}✓${NC} Alias aggiunti a $SHELL_RC"
fi

echo ""
echo -e "${GREEN}🎉 Installazione completata!${NC}"
echo ""
echo "Prossimi passi:"
echo -e "  1. ${BLUE}source $SHELL_RC${NC}    (o riapri il terminale)"
echo -e "  2. ${BLUE}nt-init${NC}                       (login Cloudflare + crea progetto)"
echo -e "  3. ${BLUE}nt-help${NC}                       (lista comandi)"
echo ""
