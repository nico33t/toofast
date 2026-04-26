#!/bin/bash
# nt-deploy: coltellino svizzero per Cloudflare Pages
# https://github.com/nico33t/nt-deploy

VERSION="1.1.0"
REPO_RAW="https://raw.githubusercontent.com/nico33t/nt-deploy/main"

CONFIG_DIR="$HOME/.nt-tools"
CONFIG_FILE="$CONFIG_DIR/config"
SCRIPT_PATH="$CONFIG_DIR/nt-deploy.sh"
LAST_CHECK_FILE="$CONFIG_DIR/.last_update_check"

# Carica config persistente. La env var NT_PROJECT, se gia' impostata,
# vince (utile per override one-shot tipo: NT_PROJECT=test nt-push ...).
if [ -z "$NT_PROJECT" ] && [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

PROJECT="${NT_PROJECT:-anteprima}"
ACTION=$1
shift

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Controlla che wrangler sia installato
check_wrangler() {
  if ! command -v wrangler &> /dev/null; then
    echo -e "${RED}❌ wrangler non trovato${NC}"
    echo "Installa con: npm install -g wrangler"
    exit 1
  fi
}

# Sanitizza nome branch
sanitize_branch() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# Estrae VERSION da uno script nt-deploy.sh
extract_version() {
  grep -m1 '^VERSION=' "$1" 2>/dev/null | cut -d'"' -f2
}

# Check non-bloccante per nuove versioni (max 1 volta al giorno).
# Scrive un avviso a fine comando se trova una versione nuova.
check_for_updates() {
  # Salta check se rete non disponibile o curl manca
  command -v curl &>/dev/null || return 0

  # Salta se controllato nelle ultime 24h
  if [ -f "$LAST_CHECK_FILE" ]; then
    local age
    age=$(( $(date +%s) - $(stat -f %m "$LAST_CHECK_FILE" 2>/dev/null || stat -c %Y "$LAST_CHECK_FILE" 2>/dev/null || echo 0) ))
    [ "$age" -lt 86400 ] && return 0
  fi

  mkdir -p "$CONFIG_DIR"
  touch "$LAST_CHECK_FILE"

  local remote_version
  remote_version=$(curl -fsSL --max-time 2 "$REPO_RAW/scripts/nt-deploy.sh" 2>/dev/null \
    | grep -m1 '^VERSION=' | cut -d'"' -f2)

  if [ -n "$remote_version" ] && [ "$remote_version" != "$VERSION" ]; then
    echo ""
    echo -e "${YELLOW}💡 Nuova versione disponibile: ${GREEN}$remote_version${YELLOW} (la tua: $VERSION)${NC}"
    echo -e "   Aggiorna con: ${BLUE}nt-update${NC}"
  fi
}

# Aggiorna lo script in-place dalla repo GitHub
self_update() {
  command -v curl &>/dev/null || { echo -e "${RED}❌ curl non trovato${NC}"; exit 1; }

  echo -e "${BLUE}📥 Scarico ultima versione da $REPO_RAW...${NC}"
  local tmpfile
  tmpfile=$(mktemp)
  if ! curl -fsSL --max-time 10 "$REPO_RAW/scripts/nt-deploy.sh" -o "$tmpfile"; then
    echo -e "${RED}❌ Download fallito${NC}"
    rm -f "$tmpfile"
    exit 1
  fi

  local remote_version
  remote_version=$(extract_version "$tmpfile")
  if [ -z "$remote_version" ]; then
    echo -e "${RED}❌ Impossibile leggere la versione remota (file corrotto?)${NC}"
    rm -f "$tmpfile"
    exit 1
  fi

  if [ "$remote_version" = "$VERSION" ]; then
    echo -e "${GREEN}✓ Sei gia' aggiornato (v$VERSION)${NC}"
    rm -f "$tmpfile"
    return 0
  fi

  # Sostituisci lo script installato
  if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}❌ Script installato non trovato in $SCRIPT_PATH${NC}"
    echo "   (forse stai eseguendo da una cartella locale, non da ~/.nt-tools)"
    rm -f "$tmpfile"
    exit 1
  fi

  mv "$tmpfile" "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo -e "${GREEN}✅ Aggiornato: v$VERSION → v$remote_version${NC}"
}

case $ACTION in
  push)
    check_wrangler
    FOLDER=${1:-./dist}
    BRANCH_RAW=${2:-main}
    BRANCH=$(sanitize_branch "$BRANCH_RAW")

    if [ ! -d "$FOLDER" ]; then
      echo -e "${RED}❌ Cartella '$FOLDER' non trovata${NC}"
      exit 1
    fi

    echo -e "${BLUE}🚀 Deploy '$FOLDER' → branch '$BRANCH'...${NC}"
    wrangler pages deploy "$FOLDER" \
      --project-name="$PROJECT" \
      --branch="$BRANCH" \
      --commit-dirty=true

    if [ "$BRANCH" = "main" ]; then
      echo -e "${GREEN}✅ Online: https://$PROJECT.pages.dev${NC}"
    else
      echo -e "${GREEN}✅ Online: https://$BRANCH.$PROJECT.pages.dev${NC}"
    fi
    check_for_updates
    ;;

  list)
    check_wrangler
    echo -e "${BLUE}📋 Deploy recenti:${NC}"
    wrangler pages deployment list --project-name="$PROJECT"
    ;;

  open)
    BRANCH_RAW=${1:-main}
    BRANCH=$(sanitize_branch "$BRANCH_RAW")
    if [ "$BRANCH" = "main" ]; then
      URL="https://$PROJECT.pages.dev"
    else
      URL="https://$BRANCH.$PROJECT.pages.dev"
    fi
    echo -e "${BLUE}🌐 Apro $URL${NC}"
    if command -v open &> /dev/null; then
      open "$URL"
    elif command -v xdg-open &> /dev/null; then
      xdg-open "$URL"
    elif command -v start &> /dev/null; then
      start "$URL"
    else
      echo "$URL"
    fi
    ;;

  copy)
    BRANCH_RAW=${1:-main}
    BRANCH=$(sanitize_branch "$BRANCH_RAW")
    if [ "$BRANCH" = "main" ]; then
      URL="https://$PROJECT.pages.dev"
    else
      URL="https://$BRANCH.$PROJECT.pages.dev"
    fi
    if command -v pbcopy &> /dev/null; then
      echo "$URL" | pbcopy
    elif command -v xclip &> /dev/null; then
      echo "$URL" | xclip -selection clipboard
    elif command -v clip &> /dev/null; then
      echo "$URL" | clip
    else
      echo -e "${YELLOW}⚠️  Clipboard non disponibile${NC}"
    fi
    echo -e "${GREEN}📋 $URL${NC}"
    ;;

  clients)
    check_wrangler
    echo -e "${BLUE}👥 Branch/clienti attivi:${NC}"
    wrangler pages deployment list --project-name="$PROJECT" 2>/dev/null \
      | grep -Eo "https://[a-z0-9-]+\.$PROJECT\.pages\.dev|[a-z0-9-]+\.$PROJECT\.pages\.dev" \
      | sed -E "s#https://##" \
      | sed -E "s#\.$PROJECT\.pages\.dev##" \
      | grep -v "^$PROJECT$" \
      | sort -u
  ;;

  init)
    check_wrangler

    # Se gia' configurato, chiedi se cambiarlo
    if [ -n "${NT_PROJECT:-}" ]; then
      echo -e "${BLUE}📦 Progetto attuale: ${GREEN}$PROJECT${NC}"
      if [ -f "$CONFIG_FILE" ]; then
        echo "   (salvato in $CONFIG_FILE)"
      else
        echo "   (da variabile d'ambiente NT_PROJECT)"
      fi
      read -p "Vuoi cambiarlo? [s/N] " CHANGE
      if [[ ! "$CHANGE" =~ ^[sSyY]$ ]]; then
        SKIP_PROMPT=1
      fi
    fi

    if [ -z "${SKIP_PROMPT:-}" ]; then
      echo ""
      echo "Scegli il nome del tuo progetto Cloudflare Pages."
      echo -e "  • URL base:    ${YELLOW}<nome>.pages.dev${NC}"
      echo -e "  • URL cliente: ${YELLOW}cliente.<nome>.pages.dev${NC}"
      echo ""
      read -p "Nome progetto [anteprima]: " USER_PROJECT
      USER_PROJECT=${USER_PROJECT:-anteprima}
      USER_PROJECT=$(sanitize_branch "$USER_PROJECT")

      mkdir -p "$CONFIG_DIR"
      echo "NT_PROJECT=$USER_PROJECT" > "$CONFIG_FILE"
      PROJECT="$USER_PROJECT"
      echo -e "${GREEN}✓${NC} Salvato in $CONFIG_FILE"
      echo ""
    fi

    echo -e "${BLUE}🔧 Login a Cloudflare...${NC}"
    wrangler login
    echo -e "${BLUE}🔧 Creo progetto '$PROJECT' (se non esiste)...${NC}"
    wrangler pages project create "$PROJECT" --production-branch=main 2>/dev/null \
      || echo -e "${YELLOW}ℹ️  Progetto '$PROJECT' gia' esistente, lo riuso${NC}"
    echo ""
    echo -e "${GREEN}✅ Pronto!${NC}"
    echo -e "   ${BLUE}nt-push ./dist${NC}              → https://$PROJECT.pages.dev"
    echo -e "   ${BLUE}nt-push ./dist mario-rossi${NC}  → https://mario-rossi.$PROJECT.pages.dev"
    check_for_updates
    ;;

  config)
    echo -e "${BLUE}⚙️  Configurazione attuale:${NC}"
    echo "  Progetto:   $PROJECT"
    echo "  URL base:   https://$PROJECT.pages.dev"
    if [ -f "$CONFIG_FILE" ]; then
      echo "  File:       $CONFIG_FILE"
    else
      echo "  File:       (nessuno — sto usando il default)"
    fi
    echo ""
    echo "  Per cambiarlo: rilancia 'nt-init' e rispondi 's' alla domanda."
    ;;

  version)
    echo "nt-deploy v$VERSION"
    ;;

  update)
    self_update
    ;;

  help|--help|-h|"")
    cat <<EOF
🔪 nt-deploy — coltellino svizzero Cloudflare Pages

COMANDI:
  nt-init                        Login Cloudflare + crea progetto
  nt-push [cartella] [cliente]   Deploy cartella su branch cliente
  nt-list                        Mostra tutti i deploy
  nt-clients                     Lista clienti attivi
  nt-open [cliente]              Apri URL nel browser
  nt-copy [cliente]              Copia URL nella clipboard
  nt-config                      Mostra configurazione
  nt-update                      Aggiorna nt-deploy all'ultima versione
  nt-version                     Versione
  nt-help                        Questo aiuto

ESEMPI:
  nt-push ./dist mario-rossi     → mario-rossi.anteprima.pages.dev
  nt-push ./build "Hotel Roma"   → hotel-roma.anteprima.pages.dev
  nt-push ./dist                 → anteprima.pages.dev (production)
  nt-copy hotel-roma             copia link da inviare al cliente

CONFIGURAZIONE:
  Nome progetto: chiesto al primo 'nt-init' e salvato in ~/.nt-tools/config
  Per cambiarlo:  rilancia 'nt-init' e rispondi 's' alla domanda
  Override one-shot: NT_PROJECT=test nt-push ./dist
EOF
    ;;

  *)
    echo -e "${RED}❌ Comando sconosciuto: $ACTION${NC}"
    echo "Usa 'nt-help' per la lista comandi"
    exit 1
    ;;
esac
