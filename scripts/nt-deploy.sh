#!/bin/bash
# nt-deploy: the web super-tool. Cloudflare Pages deploys + a full dev toolkit.
# https://github.com/nico33t/nt-deploy

VERSION="2.0.0"
REPO_RAW="https://raw.githubusercontent.com/nico33t/nt-deploy/main"

CONFIG_DIR="$HOME/.nt-tools"
CONFIG_FILE="$CONFIG_DIR/config"
SCRIPT_PATH="$CONFIG_DIR/nt-deploy.sh"
LAST_CHECK_FILE="$CONFIG_DIR/.last_update_check"
SNAP_ROOT="$CONFIG_DIR/snapshots"
SETTINGS_FILE="$CONFIG_DIR/settings"
PROJECT_FILE=".ntdeploy"
SNAP_KEEP=15

# Optional settings (API keys, tokens, flags) — written by the GUI.
# Lines use ${VAR:-value} so real environment variables still win.
[ -f "$SETTINGS_FILE" ] && source "$SETTINGS_FILE"

# ── Global flag -p/--project (any command, any position) ──────────────
_args=(); while [ $# -gt 0 ]; do case "$1" in
  -p|--project) NT_PROJECT="$2"; NT_SOURCE="flag (-p)"; shift 2;;
  --project=*) NT_PROJECT="${1#--project=}"; NT_SOURCE="flag (-p)"; shift;;
  *) _args+=("$1"); shift;;
esac; done
set -- "${_args[@]}"

# ── Project resolution ────────────────────────────────────────────────
# Order:  -p/--project  >  env NT_PROJECT  >  ./.ntdeploy  >  ~/.nt-tools/config  >  default
# SECURITY: .ntdeploy lives inside arbitrary (possibly hostile) repos, so we
# NEVER `source` it — we extract NT_PROJECT and strip it to safe characters
# only. This prevents arbitrary code execution from a cloned repository.
nt_read_project() {  # <file>
  sed -n 's/^[[:space:]]*NT_PROJECT=//p' "$1" 2>/dev/null | head -1 \
    | tr -d "\"' " | sed 's/[^A-Za-z0-9-].*//'
}
if [ -z "$NT_PROJECT" ] && [ -f "$PROJECT_FILE" ]; then
  _np=$(nt_read_project "$PROJECT_FILE"); [ -n "$_np" ] && { NT_PROJECT="$_np"; NT_SOURCE="folder ($PROJECT_FILE)"; }
fi
# config lives in ~/.nt-tools (user-owned); still parsed, not sourced.
if [ -z "$NT_PROJECT" ] && [ -f "$CONFIG_FILE" ]; then
  _np=$(nt_read_project "$CONFIG_FILE"); [ -n "$_np" ] && { NT_PROJECT="$_np"; NT_SOURCE="global ($CONFIG_FILE)"; }
fi
PROJECT="${NT_PROJECT:-anteprima}"
NT_SOURCE="${NT_SOURCE:-default}"

ACTION=$1; shift 2>/dev/null

# ── Styling (real ESC bytes via $'...' so heredocs render too) ────────
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; MAGENTA=$'\033[0;35m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'

banner() {
  echo -e "${BOLD}${CYAN}"
  echo "    ┏┓╋ ┏┫┏┓┏┓┃┏┓┓┏"
  echo -e "    ┛┗┗━┗┻┗━┣┛┗┛┗━┗┛   ⚡${NC}"
  echo -e "${BOLD} nt-deploy ${DIM}v$VERSION${NC} ${DIM}— ship your site in ${NC}${BOLD}one command${NC}${DIM}, and a lot more${NC}"
  echo -e " ${DIM}https://github.com/nico33t/nt-deploy${NC}\n"
}
err(){ echo -e "${RED}❌ $1${NC}"; }; ok(){ echo -e "${GREEN}✅ $1${NC}"; }
info(){ echo -e "${BLUE}$1${NC}"; }; warn(){ echo -e "${YELLOW}$1${NC}"; }
have(){ command -v "$1" &>/dev/null; }

# ── Utility ───────────────────────────────────────────────────────────
check_wrangler(){ have wrangler || { err "wrangler not found — npm install -g wrangler"; exit 1; }; }
need_jq(){ have jq && return 0; err "jq not found — brew install jq (or apt install jq)"; return 1; }
sanitize_branch(){ echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g;s/--*/-/g;s/^-//;s/-$//'; }
extract_version(){ grep -m1 '^VERSION=' "$1" 2>/dev/null | cut -d'"' -f2; }
url_for(){ if [ "$1" = "main" ]; then echo "https://$PROJECT.pages.dev"; else echo "https://$1.$PROJECT.pages.dev"; fi; }
deployments_json(){ wrangler pages deployment list --project-name="$PROJECT" --json 2>/dev/null; }
human_size(){ if have numfmt; then numfmt --to=iec "$1" 2>/dev/null || echo "$1 B"; else echo "$1 B"; fi; }
sedi(){ if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }   # portable in-place

# ── Snapshots (kill feature: local rollback) ──────────────────────────
snap_dir(){ echo "$SNAP_ROOT/$PROJECT/$1"; }
archive_snapshot(){  # <folder> <branch>
  local folder="$1" branch="$2" dir; dir=$(snap_dir "$branch"); mkdir -p "$dir"
  local ts; ts=$(date +%s)
  tar -czf "$dir/$ts.tar.gz" -C "$folder" . 2>/dev/null || return 1
  date "+%Y-%m-%d %H:%M:%S" > "$dir/$ts.meta"
  ls -1t "$dir"/*.tar.gz 2>/dev/null | tail -n +$((SNAP_KEEP+1)) | while read -r old; do rm -f "$old" "${old%.tar.gz}.meta"; done
}

# ── Update ────────────────────────────────────────────────────────────
fetch_remote_version(){ curl -fsSL --max-time 2 "$REPO_RAW/scripts/nt-deploy.sh" 2>/dev/null | grep -m1 '^VERSION=' | cut -d'"' -f2; }
check_for_updates(){
  have curl || return 0
  if [ -f "$LAST_CHECK_FILE" ]; then
    local age; age=$(( $(date +%s) - $(stat -f %m "$LAST_CHECK_FILE" 2>/dev/null || stat -c %Y "$LAST_CHECK_FILE" 2>/dev/null || echo 0) ))
    [ "$age" -lt 86400 ] && return 0
  fi
  mkdir -p "$CONFIG_DIR"; touch "$LAST_CHECK_FILE"
  local rv; rv=$(fetch_remote_version)
  if [ -n "$rv" ] && [ "$rv" != "$VERSION" ]; then
    if [ "${NT_AUTO_UPDATE:-0}" = "1" ]; then echo ""; info "💡 Auto-update v$VERSION → v$rv…"; self_update silent
    else echo ""; warn "💡 New version available: ${GREEN}$rv${YELLOW} (yours: $VERSION)"; echo -e "   Update: ${BLUE}nt-update${NC} ${DIM}(or set NT_AUTO_UPDATE=1)${NC}"; fi
  fi
}
self_update(){
  have curl || { err "curl not found"; exit 1; }
  [ "$1" != "silent" ] && info "📥 Downloading latest version…"
  local tmp; tmp=$(mktemp)
  curl -fsSL --max-time 10 "$REPO_RAW/scripts/nt-deploy.sh" -o "$tmp" || { err "Download failed"; rm -f "$tmp"; exit 1; }
  local rv; rv=$(extract_version "$tmp")
  [ -z "$rv" ] && { err "Could not read remote version"; rm -f "$tmp"; exit 1; }
  [ "$rv" = "$VERSION" ] && { ok "Already up to date (v$VERSION)"; rm -f "$tmp"; return 0; }
  [ -f "$SCRIPT_PATH" ] || { err "Installed script not found at $SCRIPT_PATH"; rm -f "$tmp"; exit 1; }
  mv "$tmp" "$SCRIPT_PATH"; chmod +x "$SCRIPT_PATH"; ok "Updated: v$VERSION → v$rv"
}

# ── Build helpers ─────────────────────────────────────────────────────
detect_pm(){ [ -f pnpm-lock.yaml ]&&{ echo pnpm;return;}; [ -f yarn.lock ]&&{ echo yarn;return;}; [ -f bun.lockb ]&&{ echo bun;return;}; echo npm; }
detect_outdir(){ for d in dist build out .output/public public .svelte-kit/output; do [ -d "$d" ]&&{ echo "$d";return;}; done; echo ""; }
run_build(){
  [ -f package.json ] || { err "--build needs a package.json in the current folder"; exit 1; }
  local pm; pm=$(detect_pm); info "🔨 Building with ${BOLD}$pm${NC}${BLUE}…${NC}"
  if [ "$pm" = npm ]; then npm run build || { err "Build failed"; exit 1; }; else "$pm" run build || { err "Build failed"; exit 1; }; fi
}

# ── Scaffold helpers (shared by plain + Vite) ─────────────────────────
# Use globals NAME, URL, PROJECT. $1 = target dir.
nt_docs(){
  cat > "$1/DESIGN.md" <<MD
# Design System — $NAME

> Single source of truth for UI, read by AI agents (Claude Code, Cursor, Copilot, Stitch)
> as guardrails for every generation. Sections start EMPTY on purpose — see
> "9. Agent Prompt Guide": the agent must fill them WITH the user, not invent values.

## 1. Visual Theme & Atmosphere
<!-- Overall visual tone and the brand's aesthetic intent -->
-
-

## 2. Color Palette & Roles
<!-- Semantic roles, not just hex values -->
| Role | Token | Value |
|---|---|---|
| primary |  |  |
| surface |  |  |
| accent |  |  |
| error |  |  |
- Notes:

## 3. Typography Rules
- Font families:
- Type scale:
- Weights:
- Line heights:

## 4. Component Stylings
- Buttons (variants + states):
- Cards:
- Forms / inputs:
- Navigation:

## 5. Layout Principles
- Grid:
- Breakpoints:
- Base spacing:

## 6. Depth & Elevation
- Shadows:
- Z-index layers:
- Layering rules:

## 7. Do's and Don'ts
- ✅ Do:
- ❌ Don't:

## 8. Responsive Behavior
- Desktop:
- Tablet:
- Mobile:

## 9. Agent Prompt Guide
Instructions for AI agents reading this file:
- This file is the source of truth for UI. Use ONLY values defined above.
- If a section is empty, DO NOT invent values. First ask the user the questions
  below, then write the answers back into the sections above, then build.
- Questions to ask before building:
  1. What feeling should the site evoke? (minimal, bold, playful, luxury, editorial…)
  2. Brand colors — existing palette or logo to match?
  3. Typography vibe (serif/sans, classic/modern) or specific fonts?
  4. Reference sites you like?
  5. Light, dark, or both?
  6. Primary audience and main devices?
- Never introduce colors, fonts, or spacing outside the documented scale.
- Validate every component against section 7 and accessibility (contrast ≥ 4.5:1, visible focus).
MD
  cat > "$1/AGENTS.md" <<MD
# AGENTS.md — $NAME

Guidance for AI coding agents working in this repository.

## Design source of truth
- \`DESIGN.md\` is the single source of truth for all UI. Read it before generating any component.
- Use only the colors, fonts, spacing, and component patterns defined there.
- If \`DESIGN.md\` has empty sections, ask the user the questions in its "Agent Prompt Guide"
  and fill them in first — do not invent values.

## Quality bar
- Target PageSpeed ≥ 95 (mobile): no render-blocking web fonts, defer JS, set width/height on media.
- Accessible: semantic landmarks, visible focus, contrast ≥ 4.5:1, "skip to content".
- Keep payload lean; convert images to WebP (\`nt-images\`).

## Project
- Static site deployed to Cloudflare Pages with nt-deploy: \`nt-push . <client>\`.
- Security & cache headers live in \`_headers\`. PWA config in \`site.webmanifest\`.

## Don't
- Don't add heavy frameworks or trackers without asking.
- Don't introduce values outside the \`DESIGN.md\` scale.
MD
  cat > "$1/CLAUDE.md" <<MD
# CLAUDE.md — $NAME

## Design System
Always refer to DESIGN.md when generating UI components.
- Use only colors, fonts, and spacing defined in DESIGN.md
- Match component states to the patterns described there
- Never introduce values outside the documented scale
- Validate accessibility against the Do's and Don'ts section
- If a DESIGN.md section is empty, ask the user the questions in its "Agent Prompt Guide" before generating

## Build & deploy
- Preview: \`nt-serve .\`  ·  Audit: \`nt-audit <client>\`  ·  Ship: \`nt-push . <client>\`
- Keep PageSpeed ≥ 95 and respect \`_headers\` (CSP, caching).
MD
  echo "NT_PROJECT=$PROJECT" > "$1/.ntdeploy"
}
# common static meta (robots, sitemap, manifest, favicon, 404). $1 = web dir.
nt_meta(){
  printf 'User-agent: *\nAllow: /\nSitemap: %s/sitemap.xml\n' "$URL" > "$1/robots.txt"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>%s/</loc></url>\n</urlset>\n' "$URL" > "$1/sitemap.xml"
  cat > "$1/site.webmanifest" <<MAN
{ "name": "$NAME", "short_name": "$NAME", "start_url": "/", "display": "standalone",
  "background_color": "#0b1020", "theme_color": "#0b1020",
  "icons": [{ "src": "/favicon.svg", "sizes": "any", "type": "image/svg+xml" }] }
MAN
  cat > "$1/favicon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" rx="22" fill="#0b1020"/><circle cx="50" cy="50" r="28" fill="none" stroke="#35e8ff" stroke-width="8"/><circle cx="50" cy="50" r="9" fill="#6d4aff"/></svg>
SVG
  cat > "$1/404.html" <<H4
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Not found — $NAME</title><link rel="stylesheet" href="/styles.css"></head>
<body><main><section class="hero"><h1>404</h1><p>This page doesn't exist.</p><a class="cta" href="/">Back home</a></section></main></body></html>
H4
}
# optional dev server with live reload. $1=dir $2=stack $3=serve(yes|no)
nt_devserve(){
  [ "$3" = yes ] || return 0
  if [ "$2" = vite ]; then
    have npm || { warn "npm not found — start later with: cd $1 && npm install && npm run dev"; return 0; }
    info "📦 Installing deps + starting Vite (HMR — edit and see changes live)…"
    ( cd "$1" && npm install && npm run dev )
  else
    if have npx; then info "🔁 Starting live-server (auto-reload on save)…"; ( cd "$1" && npx --yes live-server )
    elif have python3; then warn "live-server unavailable; serving without auto-reload (refresh manually)."; ( cd "$1" && python3 -m http.server 8080 )
    else err "Need npx or python3 to run a dev server."; fi
  fi
}

# ══════════════════════════════════════════════════════════════════════
case $ACTION in

  # ───── DEPLOY ─────
  push)
    check_wrangler
    FOLDER=""; CLIENT=""; DO_BUILD=0; DRY=0; YES=0; OUT=""; FOLDER_SET=""
    while [ $# -gt 0 ]; do case "$1" in
      --build) DO_BUILD=1;; --dry-run) DRY=1;; -y|--yes) YES=1;;
      --out) OUT="$2"; shift;; --out=*) OUT="${1#--out=}";;
      -*) warn "⚠️  ignored flag: $1";;
      *) if [ -z "$FOLDER_SET" ]; then FOLDER="$1"; FOLDER_SET=1; else CLIENT="$1"; fi;;
    esac; shift; done

    [ "$DO_BUILD" = 1 ] && run_build
    if [ -n "$OUT" ]; then FOLDER="$OUT"
    elif [ -z "$FOLDER" ] && [ "$DO_BUILD" = 1 ]; then
      FOLDER=$(detect_outdir); [ -z "$FOLDER" ] && { err "Output folder not found after build (use --out DIR)"; exit 1; }
      info "📦 Output: ${BOLD}$FOLDER${NC}"; fi
    FOLDER=${FOLDER:-./dist}; BRANCH=$(sanitize_branch "${CLIENT:-main}")
    [ -d "$FOLDER" ] || { err "Folder '$FOLDER' not found"; exit 1; }
    ls "$FOLDER"/index.html &>/dev/null || warn "⚠️  No index.html in '$FOLDER'"
    TARGET_URL=$(url_for "$BRANCH")

    if [ "$BRANCH" = main ] && [ "$YES" != 1 ] && [ "$DRY" != 1 ]; then
      echo ""; warn "⚠️  You are about to overwrite ${BOLD}PRODUCTION${NC}${YELLOW}: $TARGET_URL"
      read -p "   Continue? [y/N] " C; [[ "$C" =~ ^[sSyY]$ ]] || { info "Cancelled."; exit 0; }
    fi
    echo ""; info "🚀 Deploying ${BOLD}$FOLDER${NC}${BLUE} → ${BOLD}$BRANCH${NC}${BLUE} (project: $PROJECT)${NC}"
    [ "$DRY" = 1 ] && { warn "   [dry-run] would deploy to: $TARGET_URL"; exit 0; }

    if wrangler pages deploy "$FOLDER" --project-name="$PROJECT" --branch="$BRANCH" --commit-dirty=true; then
      archive_snapshot "$FOLDER" "$BRANCH" && echo -e "   ${DIM}📸 snapshot saved (rollback available)${NC}"
      echo ""; ok "Live: ${BOLD}$TARGET_URL${NC}"
      have pbcopy && { echo "$TARGET_URL" | pbcopy; echo -e "   ${DIM}(URL copied to clipboard)${NC}"; }
    else code=$?; echo ""; err "Deploy failed (wrangler exit $code) — URL NOT updated"; exit "$code"; fi
    check_for_updates
    ;;

  build-push|bp) exec "$0" push --build "$@" ;;

  # ───── KILL FEATURE: local rollback ─────
  rollback)
    check_wrangler
    CLIENT="${1:-main}"; TS="$2"; BRANCH=$(sanitize_branch "$CLIENT"); DIR=$(snap_dir "$BRANCH")
    [ -d "$DIR" ] || { err "No snapshots for '$BRANCH'. Deploy at least once first."; exit 1; }
    mapfile -t SNAPS < <(ls -1t "$DIR"/*.tar.gz 2>/dev/null)
    [ "${#SNAPS[@]}" -lt 2 ] && [ -z "$TS" ] && { err "Need at least 2 snapshots to roll back (have ${#SNAPS[@]})."; exit 1; }
    if [ -n "$TS" ]; then ARCHIVE="$DIR/$TS.tar.gz"; [ -f "$ARCHIVE" ] || { err "Snapshot $TS not found. See: nt-snapshots $BRANCH"; exit 1; }
    else ARCHIVE="${SNAPS[1]}"; fi
    LBL=$(cat "${ARCHIVE%.tar.gz}.meta" 2>/dev/null || basename "$ARCHIVE")
    warn "⏪ Rolling '${BOLD}$BRANCH${NC}${YELLOW}' back to snapshot from ${BOLD}$LBL${NC}"
    read -p "   Continue? [y/N] " C; [[ "$C" =~ ^[sSyY]$ ]] || { info "Cancelled."; exit 0; }
    TMP=$(mktemp -d); tar -xzf "$ARCHIVE" -C "$TMP" || { err "Corrupt archive"; rm -rf "$TMP"; exit 1; }
    info "🚀 Redeploying snapshot…"
    if wrangler pages deploy "$TMP" --project-name="$PROJECT" --branch="$BRANCH" --commit-dirty=true; then
      archive_snapshot "$TMP" "$BRANCH"; rm -rf "$TMP"
      echo ""; ok "Rollback complete: ${BOLD}$(url_for "$BRANCH")${NC}"
    else code=$?; rm -rf "$TMP"; err "Rollback failed (exit $code)"; exit "$code"; fi
    ;;

  snapshots|snaps)
    BRANCH=$(sanitize_branch "${1:-main}"); DIR=$(snap_dir "$BRANCH")
    info "📸 Snapshots for '$BRANCH' (project: $PROJECT):"
    [ -d "$DIR" ] || { warn "   none yet."; exit 0; }
    i=0; ls -1t "$DIR"/*.tar.gz 2>/dev/null | while read -r f; do
      ts=$(basename "$f" .tar.gz); meta=$(cat "${f%.tar.gz}.meta" 2>/dev/null || echo "?")
      sz=$(human_size "$(wc -c < "$f")"); tag=""; [ $i = 0 ] && tag="${GREEN}(current)${NC}"; [ $i = 1 ] && tag="${YELLOW}(rollback →)${NC}"
      echo -e "   ${DIM}$ts${NC}  $meta  ${DIM}$sz${NC}  $tag"; i=$((i+1))
    done
    echo -e "   ${DIM}Restore with: nt-rollback $BRANCH [timestamp]${NC}"
    ;;

  # ───── MANAGE (Cloudflare) ─────
  rm|delete)
    check_wrangler; need_jq || exit 1
    CLIENT=""; YES=0; for a in "$@"; do case "$a" in -y|--yes) YES=1;; *) CLIENT="$a";; esac; done
    [ -z "$CLIENT" ] && { err "Usage: nt-rm <client> [-y]"; exit 1; }
    BRANCH=$(sanitize_branch "$CLIENT"); [ "$BRANCH" = main ] && { err "Refusing to delete production from here."; exit 1; }
    IDS=$(deployments_json | jq -r --arg b "$BRANCH" '.[] | select((.Branch|ascii_downcase)==$b) | .Id')
    [ -z "$IDS" ] && { warn "No deployments for '$BRANCH'."; exit 0; }
    N=$(echo "$IDS" | grep -c .); warn "About to delete ${BOLD}$N${NC}${YELLOW} deployment(s) for '${BOLD}$BRANCH${NC}${YELLOW}'."
    [ "$YES" != 1 ] && { read -p "   Continue? [y/N] " C; [[ "$C" =~ ^[sSyY]$ ]] || { info "Cancelled."; exit 0; }; }
    echo "$IDS" | while read -r id; do [ -z "$id" ] && continue
      if wrangler pages deployment delete "$id" --project-name="$PROJECT" --yes &>/dev/null; then echo -e "   ${GREEN}✓${NC} $id"; else echo -e "   ${RED}✗${NC} $id (maybe the live one)"; fi
    done; ok "Cleanup done."
    ;;

  logs|tail)
    check_wrangler; BRANCH=$(sanitize_branch "${1:-main}")
    if have jq; then ID=$(deployments_json | jq -r --arg b "$BRANCH" 'map(select((.Branch|ascii_downcase)==$b))|.[0].Id // empty')
      [ -z "$ID" ] && { err "No deployment for '$BRANCH'."; exit 1; }
      info "📡 Tailing '$BRANCH' ($ID) — Ctrl-C to stop"; wrangler pages deployment tail "$ID" --project-name="$PROJECT"
    else info "📡 Tailing (latest deployment)"; wrangler pages deployment tail --project-name="$PROJECT"; fi
    ;;

  rmproject|project-rm)
    check_wrangler
    NAME="${1:-}"; YES=0; [ "$2" = "-y" ] && YES=1
    [ -z "$NAME" ] && { err "Usage: nt-rmproject <project-name>"; exit 1; }
    warn "⚠️  This deletes the ENTIRE project '${BOLD}$NAME${NC}${YELLOW}' and ALL its deployments. This cannot be undone."
    if [ "$YES" != 1 ]; then
      read -p "   Type the project name to confirm: " CONF
      [ "$CONF" = "$NAME" ] || { err "Name does not match. Aborted."; exit 1; }
    fi
    if wrangler pages project delete "$NAME" --yes; then ok "Project '$NAME' deleted."
    else code=$?; err "Delete failed (exit $code)"; exit "$code"; fi
    ;;

  list)     check_wrangler; info "📋 Recent deployments ($PROJECT):"; wrangler pages deployment list --project-name="$PROJECT" ;;
  projects) check_wrangler; info "📦 Cloudflare Pages projects:"; wrangler pages project list ;;
  clients)
    check_wrangler; info "👥 Active clients/branches ($PROJECT):"
    if have jq; then deployments_json | jq -r '.[].Branch' 2>/dev/null | grep -vE '^(main|null)$' | sort -u \
        | while read -r b; do echo -e "   ${GREEN}•${NC} $b  ${DIM}→ https://$b.$PROJECT.pages.dev${NC}"; done
    else wrangler pages deployment list --project-name="$PROJECT" 2>/dev/null | grep -Eo "[a-z0-9-]+\.$PROJECT\.pages\.dev" | sed -E "s#\.$PROJECT\.pages\.dev##" | grep -v "^$PROJECT$" | sort -u; fi
    ;;
  open) URL=$(url_for "$(sanitize_branch "${1:-main}")"); info "🌐 $URL"; if have open; then open "$URL"; elif have xdg-open; then xdg-open "$URL"; else echo "$URL"; fi ;;
  copy) URL=$(url_for "$(sanitize_branch "${1:-main}")"); if have pbcopy; then echo "$URL"|pbcopy; elif have xclip; then echo "$URL"|xclip -selection clipboard; else warn "⚠️ clipboard unavailable"; fi; ok "📋 $URL" ;;

  # ───── PAGESPEED PRE-TEST (Google Lighthouse engine, same as pagespeed.web.dev) ─────
  audit|pagespeed|test)
    A="${1:-main}"; STRAT="${2:-mobile}"
    case "$A" in http*) URL="$A";; *) URL=$(url_for "$(sanitize_branch "$A")");; esac
    need_jq || exit 1; have curl || { err "curl missing"; exit 1; }
    ENC=$(jq -rn --arg u "$URL" '$u|@uri')
    API="https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=$ENC&strategy=$STRAT&category=PERFORMANCE&category=ACCESSIBILITY&category=BEST_PRACTICES&category=SEO"
    [ -n "$NT_PSI_KEY" ] && API="$API&key=$NT_PSI_KEY"
    info "🔬 PageSpeed (Google Lighthouse engine) — ${BOLD}$URL${NC}${BLUE}  [$STRAT]${NC}"
    echo -e "   ${DIM}analyzing (~20-40s)…${NC}"
    RESP=$(curl -sS --max-time 90 -w $'\n%{http_code}' "$API" 2>/dev/null); CODE="${RESP##*$'\n'}"; J="${RESP%$'\n'*}"
    if [ "$CODE" = 429 ]; then
      err "Google anonymous quota exceeded (HTTP 429)."
      echo -e "   Retry shortly, or use a ${BOLD}free${NC} API key:"
      echo -e "   ${BLUE}export NT_PSI_KEY=...${NC}  ${DIM}(console.cloud.google.com → PageSpeed Insights API)${NC}"
      exit 1
    fi
    { [ "$CODE" -ge 400 ] 2>/dev/null || [ -z "$CODE" ]; } && { err "PSI request failed (HTTP ${CODE:-?}): $(echo "$J"|jq -r '.error.message? // "network"' 2>/dev/null)"; exit 1; }
    bar(){ local s=$1 c=$RED n i fill="" emp=""; [ "$s" -ge 90 ]&&c=$GREEN||{ [ "$s" -ge 50 ]&&c=$YELLOW; }; n=$((s/5))
      for((i=0;i<n;i++));do fill+=█;done; for((i=n;i<20;i++));do emp+=░;done
      printf "${c}%s${DIM}%s${NC} ${c}${BOLD}%3s${NC}\n" "$fill" "$emp" "$s"; }
    P=$(echo "$J"|jq -r '(.lighthouseResult.categories.performance.score*100|round)')
    AC=$(echo "$J"|jq -r '(.lighthouseResult.categories.accessibility.score*100|round)')
    BP=$(echo "$J"|jq -r '(.lighthouseResult.categories["best-practices"].score*100|round)')
    SE=$(echo "$J"|jq -r '(.lighthouseResult.categories.seo.score*100|round)')
    echo ""; printf "   Performance     "; bar "$P"; printf "   Accessibility   "; bar "$AC"
    printf "   Best Practices  "; bar "$BP"; printf "   SEO             "; bar "$SE"
    echo ""; info "   Core Web Vitals:"
    for m in "first-contentful-paint:FCP" "largest-contentful-paint:LCP" "total-blocking-time:TBT" "cumulative-layout-shift:CLS" "speed-index:Speed Index"; do
      k="${m%%:*}"; lbl="${m##*:}"; v=$(echo "$J"|jq -r --arg k "$k" '.lighthouseResult.audits[$k].displayValue // "—"')
      printf "     ${BOLD}%-12s${NC} %s\n" "$lbl" "$v"
    done
    echo -e "   ${DIM}desktop run: nt-audit $A desktop  ·  same engine as pagespeed.web.dev${NC}"
    ;;

  # ───── ANALYTICS / TRAFFIC ─────
  analytics|stats)
    SUB="${1:-help}"; [ "$ACTION" = stats ] && SUB="stats" || shift 2>/dev/null
    case "$SUB" in
      inject)
        FOLDER="${1:-.}"; TOKEN="${2:-$NT_CF_BEACON}"
        [ -d "$FOLDER" ] || { err "Folder '$FOLDER' not found"; exit 1; }
        [ -z "$TOKEN" ] && { err "Need a Web Analytics token: nt-analytics inject <folder> <token>"; echo "   Create it: dash.cloudflare.com → Web Analytics → Add a site"; exit 1; }
        SNIP="<script defer src=\"https://static.cloudflareinsights.com/beacon.min.js\" data-cf-beacon='{\"token\":\"$TOKEN\"}'></script>"
        C=0; while IFS= read -r f; do
          grep -q "static.cloudflareinsights.com/beacon" "$f" && continue
          grep -qi "</body>" "$f" || continue
          awk -v s="$SNIP" '{ if(!d && tolower($0) ~ /<\/body>/){ sub(/<\/body>/, s"\n</body>"); d=1 } print }' "$f" > "$f.nt" && mv "$f.nt" "$f"; C=$((C+1))
        done < <(find "$FOLDER" -type f -name '*.html')
        ok "Beacon injected into $C file(s). Redeploy to start tracking."
        ;;
      open) U="https://dash.cloudflare.com/?to=/:account/web-analytics"; info "🌐 Opening Web Analytics: $U"; have open&&open "$U"||echo "$U" ;;
      stats)
        info "📊 Traffic stats (Cloudflare Web Analytics) — project: $PROJECT"
        if [ -z "$NT_CF_TOKEN" ] || [ -z "$NT_CF_ACCOUNT" ] || [ -z "$NT_CF_SITETAG" ]; then
          warn "   CLI stats need 3 env vars (one-time setup):"
          echo -e "     ${BLUE}export NT_CF_TOKEN=...${NC}    ${DIM}# API token with Analytics:Read${NC}"
          echo -e "     ${BLUE}export NT_CF_ACCOUNT=...${NC}  ${DIM}# Account ID${NC}"
          echo -e "     ${BLUE}export NT_CF_SITETAG=...${NC}  ${DIM}# site tag (from the beacon)${NC}"
          echo -e "   Or open the dashboard:  ${BLUE}nt-analytics open${NC}"
          exit 0
        fi
        need_jq || exit 1
        SINCE=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
        UNTIL=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        Q=$(jq -nc --arg a "$NT_CF_ACCOUNT" --arg t "$NT_CF_SITETAG" --arg s "$SINCE" --arg u "$UNTIL" \
          '{query:"query($a:String!,$t:String!,$s:Time!,$u:Time!){viewer{accounts(filter:{accountTag:$a}){rumPageloadEventsAdaptiveGroups(limit:1,filter:{siteTag:$t,datetime_geq:$s,datetime_leq:$u}){count sum{visits}}}}}",variables:{a:$a,t:$t,s:$s,u:$u}}')
        R=$(curl -fsSL --max-time 20 -H "Authorization: Bearer $NT_CF_TOKEN" -H "Content-Type: application/json" -d "$Q" https://api.cloudflare.com/client/v4/graphql) \
          || { err "API request failed."; exit 1; }
        echo "$R" | jq -e '.errors and (.errors|length>0)' >/dev/null 2>&1 && { err "API: $(echo "$R"|jq -r '.errors[0].message')"; exit 1; }
        G=$(echo "$R"|jq -r '.data.viewer.accounts[0].rumPageloadEventsAdaptiveGroups[0]')
        PV=$(echo "$G"|jq -r '.count // 0'); VS=$(echo "$G"|jq -r '.sum.visits // 0')
        echo -e "   Last 7 days →  Page views: ${BOLD}$PV${NC}   Visits: ${BOLD}$VS${NC}"
        ;;
      *) echo "Usage: nt-analytics inject <folder> <token> | open | stats" ;;
    esac
    ;;

  # ───── CLIENT NOTES ─────
  notes|note)
    CLIENT="${1:-}"; [ -z "$CLIENT" ] && { err "Usage: nt-notes <client> [\"note text\"]"; exit 1; }
    B=$(sanitize_branch "$CLIENT"); ND="$CONFIG_DIR/notes/$PROJECT"; mkdir -p "$ND"; F="$ND/$B.md"
    shift; TEXT="$*"
    if [ -n "$TEXT" ]; then echo "- [$(date '+%Y-%m-%d %H:%M')] $TEXT" >> "$F"; ok "Note added for '$B'."
    else info "🗒  Notes for '$B' (project: $PROJECT):"; [ -s "$F" ] && sed 's/^/   /' "$F" || warn "   no notes yet. Add one: nt-notes $B \"...\""; fi
    ;;

  # ───── TOOLKIT (works WITHOUT Cloudflare too) ─────
  serve)
    DIR="${1:-.}"; PORT="${2:-8080}"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    info "🖥  Local server: ${BOLD}http://localhost:$PORT${NC}${BLUE}  (Ctrl-C to stop)${NC}"
    if have python3; then (cd "$DIR" && python3 -m http.server "$PORT")
    elif have npx; then npx --yes serve -l "$PORT" "$DIR"
    else err "Need python3 or npx"; exit 1; fi
    ;;

  design)   # fetch a brand DESIGN.md from the community library (MIT, on-demand)
    SUB="${1:-list}"; shift 2>/dev/null
    BASE="https://raw.githubusercontent.com/VoltAgent/awesome-design-md/main/design-md"
    APIU="https://api.github.com/repos/VoltAgent/awesome-design-md/contents/design-md"
    have curl || { err "curl required"; exit 1; }
    case "$SUB" in
      list)
        info "🎨 Design templates ${DIM}(VoltAgent/awesome-design-md · MIT)${NC}:"
        if have jq; then
          curl -fsSL "$APIU" 2>/dev/null | jq -r '.[]|select(.type=="dir")|.name' \
            | (command -v column >/dev/null && column -c 76 || cat) | sed 's/^/   /'
        else curl -fsSL "$APIU" 2>/dev/null | grep -o '"name": "[^"]*"' | cut -d'"' -f4 | sed 's/^/   /'; fi
        echo -e "   ${DIM}Add one:${NC} nt-design add <brand>   ${DIM}(e.g. nt-design add bugatti)${NC}"
        ;;
      add)
        NAME=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
        [ -z "$NAME" ] && { err "Usage: nt-design add <brand> [destfile]"; exit 1; }
        DEST="${2:-DESIGN.md}"; TMP=$(mktemp)
        if curl -fsSL "$BASE/$NAME/DESIGN.md" -o "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
          [ -f "$DEST" ] && { cp "$DEST" "$DEST.bak"; warn "Backed up existing → $DEST.bak"; }
          { echo "<!-- Design template '$NAME' — source: github.com/VoltAgent/awesome-design-md (MIT), design-md/$NAME — fetched $(date +%F) -->"; echo; cat "$TMP"; } > "$DEST"
          rm -f "$TMP"; ok "Added '${BOLD}$NAME${NC}' template → ${BOLD}$DEST${NC}"
          echo -e "   ${DIM}AI agents will now follow this brand's design rules. Tweak as needed.${NC}"
        else rm -f "$TMP"; err "Template '$NAME' not found. Browse: nt-design list"; fi
        ;;
      *) echo "Usage: nt-design list | add <brand> [destfile]" ;;
    esac
    ;;

  create|scaffold)
    NAME="${1:-site}"; SAFE=$(sanitize_branch "$NAME"); URL=$(url_for "$SAFE")
    [ -e "$SAFE" ] && { err "'$SAFE' already exists"; exit 1; }
    STACK=""; SERVE=""
    for a in "${@:2}"; do case "$a" in
      --vite) STACK=vite;; --plain|--static) STACK=plain;; --serve) SERVE=yes;; --no-serve) SERVE=no;;
    esac; done
    if [ -z "$STACK" ]; then
      if [ -t 0 ]; then
        echo -e "${BOLD}Stack for '$SAFE':${NC}"
        echo "  1) HTML / CSS / JS  — no build, instant"
        echo "  2) Vite             — HMR + bundling"
        read -p "Choose [1]: " _s; [ "$_s" = 2 ] && STACK=vite || STACK=plain
      else STACK=plain; fi
    fi
    if [ -z "$SERVE" ]; then
      if [ -t 0 ]; then read -p "Start a dev server with live reload now? [y/N] " _d; [[ "$_d" =~ ^[sSyY]$ ]] && SERVE=yes || SERVE=no; else SERVE=no; fi
    fi
    if [ "$STACK" = vite ]; then
      mkdir -p "$SAFE/src" "$SAFE/public"
      nt_docs "$SAFE"; nt_meta "$SAFE/public"
      cat > "$SAFE/public/_headers" <<'HDR'
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: SAMEORIGIN
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
  Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; base-uri 'self'; form-action 'self'
/assets/*
  Cache-Control: public, max-age=31536000, immutable
HDR
      cat > "$SAFE/package.json" <<JSON
{
  "name": "$SAFE",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "build": "vite build", "preview": "vite preview" },
  "devDependencies": { "vite": "^5.4.0" }
}
JSON
      cat > "$SAFE/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>$NAME</title>
  <meta name="description" content="$NAME — built with nt-deploy + Vite.">
  <meta name="theme-color" content="#0b1020">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="manifest" href="/site.webmanifest">
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <header class="site-header"><strong>$NAME</strong></header>
  <main id="main">
    <section class="hero">
      <h1>$NAME</h1>
      <p>Vite + HMR — edit src/ and see changes live, no refresh.</p>
      <a class="cta" href="#">Get started</a>
    </section>
  </main>
  <footer class="site-footer"><small>© <span id="y"></span> $NAME</small></footer>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
HTML
      cat > "$SAFE/src/main.js" <<'JS'
import './style.css';
document.getElementById('y').textContent = new Date().getFullYear();
JS
      cat > "$SAFE/src/style.css" <<'CSS'
*,*::before,*::after{box-sizing:border-box;margin:0}
:root{--bg:#0b1020;--fg:#e6f0ff;--muted:#9fb0d0;--accent:#6d4aff;--accent2:#35e8ff;--max:1080px}
@media (prefers-color-scheme:light){:root{--bg:#fff;--fg:#0b1020;--muted:#5a6b88}}
body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--fg);line-height:1.6;min-height:100dvh;display:flex;flex-direction:column}
img{max-width:100%;height:auto;display:block}
.skip{position:absolute;left:-999px}.skip:focus{left:12px;top:12px;background:#fff;color:#000;padding:8px;border-radius:8px}
.site-header{padding:18px clamp(16px,5vw,40px)}
main{flex:1;width:100%;max-width:var(--max);margin:0 auto;padding:clamp(40px,9vw,110px) clamp(16px,5vw,40px)}
.hero h1{font-size:clamp(2.4rem,8vw,4.4rem);line-height:1.05;letter-spacing:-.02em;background:linear-gradient(120deg,var(--accent2),var(--accent));-webkit-background-clip:text;background-clip:text;color:transparent}
.hero p{margin:18px 0 28px;color:var(--muted);font-size:clamp(1rem,2.6vw,1.3rem);max-width:60ch}
.cta{display:inline-block;padding:14px 26px;border-radius:12px;text-decoration:none;font-weight:700;background:linear-gradient(120deg,var(--accent2),var(--accent));color:#04060f}
.site-footer{padding:24px clamp(16px,5vw,40px);color:var(--muted)}
CSS
      printf 'node_modules\ndist\n.DS_Store\n' > "$SAFE/.gitignore"
      ok "Created premium starter ${BOLD}$SAFE/${NC} ${DIM}(Vite + HMR)${NC}"
      echo -e "   ${DIM}files:${NC} index.html · src/main.js · src/style.css · package.json · DESIGN.md · AGENTS.md · CLAUDE.md · public/(_headers, robots, sitemap, manifest, favicon, 404)"
      echo -e "   ${DIM}dev:${NC} cd $SAFE && npm install && npm run dev   ${DIM}·  build+ship:${NC} nt-bp $SAFE"
      nt_devserve "$SAFE" vite "$SERVE"
      exit 0
    fi
    mkdir -p "$SAFE/assets"
    # — index.html : semantic, accessible, zero render-blocking fonts, deferred JS —
    cat > "$SAFE/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>$NAME</title>
  <meta name="description" content="$NAME — built with nt-deploy. Fast, accessible, production-ready.">
  <meta name="theme-color" content="#0b1020">
  <meta name="color-scheme" content="light dark">
  <meta property="og:type" content="website">
  <meta property="og:title" content="$NAME">
  <meta property="og:description" content="$NAME — fast, accessible, production-ready.">
  <meta property="og:url" content="$URL">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="canonical" href="$URL">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <header class="site-header"><strong>$NAME</strong></header>
  <main id="main">
    <section class="hero">
      <h1>$NAME</h1>
      <p>A fast, accessible starting point — scoring high on PageSpeed out of the box.</p>
      <a class="cta" href="#">Get started</a>
    </section>
  </main>
  <footer class="site-footer"><small>© <span id="y"></span> $NAME</small></footer>
  <script src="/app.js" defer></script>
</body>
</html>
HTML
    # — styles.css : system fonts (no web-font blocking), modern reset, dark-mode aware —
    cat > "$SAFE/styles.css" <<'CSS'
*,*::before,*::after{box-sizing:border-box;margin:0}
:root{--bg:#0b1020;--fg:#e6f0ff;--muted:#9fb0d0;--accent:#6d4aff;--accent2:#35e8ff;--max:1080px}
@media (prefers-color-scheme:light){:root{--bg:#ffffff;--fg:#0b1020;--muted:#5a6b88}}
html{-webkit-text-size-adjust:100%;scroll-behavior:smooth}
body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--fg);
 line-height:1.6;min-height:100dvh;display:flex;flex-direction:column}
img{max-width:100%;height:auto;display:block}
.skip{position:absolute;left:-999px}.skip:focus{left:12px;top:12px;background:#fff;color:#000;padding:8px;border-radius:8px;z-index:10}
.site-header{padding:18px clamp(16px,5vw,40px)}
main{flex:1;width:100%;max-width:var(--max);margin:0 auto;padding:clamp(40px,9vw,110px) clamp(16px,5vw,40px)}
.hero h1{font-size:clamp(2.4rem,8vw,4.4rem);line-height:1.05;letter-spacing:-.02em;
 background:linear-gradient(120deg,var(--accent2),var(--accent));-webkit-background-clip:text;background-clip:text;color:transparent}
.hero p{margin:18px 0 28px;color:var(--muted);font-size:clamp(1rem,2.6vw,1.3rem);max-width:60ch}
.cta{display:inline-block;padding:14px 26px;border-radius:12px;text-decoration:none;font-weight:700;
 background:linear-gradient(120deg,var(--accent2),var(--accent));color:#04060f}
.cta:focus-visible{outline:3px solid var(--accent2);outline-offset:3px}
.site-footer{padding:24px clamp(16px,5vw,40px);color:var(--muted)}
@media (prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
CSS
    echo 'document.getElementById("y").textContent=new Date().getFullYear();' > "$SAFE/app.js"
    nt_docs "$SAFE"
    # — Cloudflare _headers : security + long-cache (plain stack) —
    cat > "$SAFE/_headers" <<'HDR'
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: SAMEORIGIN
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
  Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; base-uri 'self'; form-action 'self'
/assets/*
  Cache-Control: public, max-age=31536000, immutable
/styles.css
  Cache-Control: public, max-age=31536000, immutable
/app.js
  Cache-Control: public, max-age=31536000, immutable
HDR
    nt_meta "$SAFE"
    ok "Created premium starter ${BOLD}$SAFE/${NC} ${DIM}(plain HTML/CSS/JS)${NC}"
    echo -e "   ${DIM}files:${NC} index.html · styles.css · app.js · DESIGN.md · AGENTS.md · CLAUDE.md · _headers · robots.txt · sitemap.xml · site.webmanifest · favicon.svg · 404.html"
    echo -e "   ${DIM}preview:${NC} nt-serve $SAFE   ${DIM}·  ship:${NC} nt-push $SAFE $SAFE   ${DIM}·  audit:${NC} nt-audit $SAFE"
    nt_devserve "$SAFE" plain "$SERVE"
    ;;

  new)
    NAME="${1:-site}"; SAFE=$(sanitize_branch "$NAME")
    [ -e "$SAFE" ] && { err "'$SAFE' already exists"; exit 1; }
    mkdir -p "$SAFE"
    cat > "$SAFE/index.html" <<HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$NAME</title><link rel="stylesheet" href="styles.css"></head>
<body><main><h1>$NAME</h1><p>Made with nt-deploy. Ready to ship.</p>
<button id="b">Hello 👋</button></main><script src="app.js"></script></body></html>
HTML
    cat > "$SAFE/styles.css" <<'CSS'
*{margin:0;box-sizing:border-box}body{min-height:100dvh;display:grid;place-items:center;
font-family:system-ui,sans-serif;background:#0b1020;color:#e6f0ff}
main{text-align:center;padding:2rem}h1{font-size:clamp(2rem,8vw,4rem)}
button{margin-top:1.5rem;padding:.8rem 1.6rem;border:0;border-radius:10px;cursor:pointer;
background:linear-gradient(120deg,#35e8ff,#8b6cff);color:#04060f;font-weight:700}
CSS
    echo "document.getElementById('b').onclick=()=>alert('Deploy with: nt-push $SAFE');" > "$SAFE/app.js"
    echo "NT_PROJECT=$PROJECT" > "$SAFE/.ntdeploy"
    ok "Created ${BOLD}$SAFE/${NC}"; echo -e "   ${DIM}nt-serve $SAFE   ·   nt-push $SAFE $SAFE${NC}"
    ;;

  build)   run_build; OUT=$(detect_outdir); [ -n "$OUT" ] && { ok "Build ready in ${BOLD}$OUT${NC}"; exec "$0" size "$OUT"; } ;;

  images|webp)   # convert png/jpg/jpeg/gif → WebP and rewrite <img>/url() references
    DIR="${1:-.}"; Q="${2:-82}"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    CONV=""; for t in cwebp magick convert; do have "$t" && { CONV="$t"; break; }; done
    [ -z "$CONV" ] && have sips && CONV=sips
    [ -z "$CONV" ] && { err "Need cwebp, imagemagick or sips. Install: brew install webp"; exit 1; }
    info "🖼  Converting images in ${BOLD}$DIR${NC}${BLUE} to WebP (q$Q, via $CONV)…${NC}"
    N=0; SAVED=0
    while IFS= read -r f; do
      out="${f%.*}.webp"
      case "$CONV" in
        cwebp)  cwebp -quiet -q "$Q" "$f" -o "$out" 2>/dev/null ;;
        magick) magick "$f" -quality "$Q" "$out" 2>/dev/null ;;
        convert) convert "$f" -quality "$Q" "$out" 2>/dev/null ;;
        sips)   sips -s format webp "$f" --out "$out" >/dev/null 2>&1 ;;
      esac
      if [ -s "$out" ]; then
        old=$(wc -c < "$f"); new=$(wc -c < "$out"); SAVED=$((SAVED + old - new))
        base=$(basename "$f"); wbase=$(basename "$out")
        # rewrite references (src=, href=, url()) across html/css/js
        grep -rlF "$base" "$DIR" --include='*.html' --include='*.css' --include='*.js' 2>/dev/null \
          | while IFS= read -r ref; do sedi "s|$base|$wbase|g" "$ref"; done
        echo -e "   ${GREEN}✓${NC} $base → $wbase  ${DIM}($(human_size "$old") → $(human_size "$new"))${NC}"
        N=$((N+1))
      else echo -e "   ${RED}✗${NC} $(basename "$f")"; fi
    done < <(find "$DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' \) ! -iname '*.webp')
    [ "$N" = 0 ] && { warn "No PNG/JPEG/GIF images found in $DIR."; exit 0; }
    ok "$N image(s) → WebP, references rewritten. Saved ~$(human_size "$SAVED"). Originals kept."
    echo -e "   ${DIM}Delete originals when happy:  find $DIR \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) -delete${NC}"
    ;;

  size)
    DIR="${1:-$(detect_outdir)}"; DIR="${DIR:-./dist}"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    info "📏 Size of ${BOLD}$DIR${NC}:"
    echo -e "   Total: ${BOLD}$(du -sh "$DIR" 2>/dev/null | cut -f1)${NC}   Files: $(find "$DIR" -type f | wc -l | tr -d ' ')"
    echo -e "   ${DIM}Top 8 files:${NC}"
    find "$DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -8 | sed 's/^/   /'
    ;;

  zip)
    DIR="${1:-$(detect_outdir)}"; DIR="${DIR:-.}"; OUT="${2:-$(basename "$(cd "$DIR"&&pwd)")-$(date +%Y%m%d).zip}"
    [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }; have zip || { err "'zip' not found"; exit 1; }
    (cd "$DIR" && zip -rq "$OLDPWD/$OUT" . -x '*.DS_Store' 'node_modules/*' '.git/*'); ok "Created ${BOLD}$OUT${NC} ($(human_size "$(wc -c < "$OUT")"))"
    ;;

  check)
    A="${1:-main}"; case "$A" in http*) URL="$A";; *) URL=$(url_for "$(sanitize_branch "$A")");; esac
    have curl || { err "curl not found"; exit 1; }; info "🩺 Checking ${BOLD}$URL${NC}"
    read -r code ttime size < <(curl -kso /dev/null -w '%{http_code} %{time_total} %{size_download}' "$URL")
    C=$RED; [ "$code" -ge 200 ] 2>/dev/null && [ "$code" -lt 400 ] && C=$GREEN
    echo -e "   Status: ${C}${BOLD}$code${NC}   Time: ${BOLD}${ttime}s${NC}   Size: ${BOLD}$(human_size "${size:-0}")${NC}"
    ;;

  qr)
    A="${1:-main}"; case "$A" in http*) URL="$A";; *) URL=$(url_for "$(sanitize_branch "$A")");; esac
    info "🔳 QR for ${BOLD}$URL${NC}"
    if have qrencode; then qrencode -t ANSIUTF8 "$URL"
    elif have npx; then npx --yes qrcode-terminal "$URL"
    else warn "Install qrencode (brew install qrencode) for the QR."; echo "   $URL"; fi
    ;;

  doctor)
    banner; info "🩺 Environment check:"
    chk(){ if have "$1"; then echo -e "   ${GREEN}✓${NC} $1 ${DIM}$($1 --version 2>/dev/null|head -1)${NC}"; else echo -e "   ${RED}✗${NC} $1 ${DIM}(missing)${NC}"; fi; }
    chk node; chk npm; chk wrangler; chk git; chk jq; chk curl; chk qrencode; chk python3
    echo ""; echo -e "   Project: ${BOLD}$PROJECT${NC} ${DIM}[$NT_SOURCE]${NC}"
    if have wrangler; then who=$(wrangler whoami 2>/dev/null | grep -i -m1 'email\|account' | sed 's/^/   /'); [ -n "$who" ] && echo -e "${DIM}$who${NC}" || echo -e "   ${YELLOW}Cloudflare: not logged in (nt-init)${NC}"; fi
    # auto-detect heavy images and recommend conversion
    BIG=$(find . -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -size +200k 2>/dev/null | head -6)
    if [ -n "$BIG" ]; then
      echo ""; warn "🖼  Heavy images found (>200KB) — convert to WebP for a higher PageSpeed score:"
      echo "$BIG" | while read -r f; do [ -n "$f" ] && echo -e "   ${DIM}$(human_size "$(wc -c < "$f")")  ${f#./}${NC}"; done
      echo -e "   Fix (keeps quality, rewrites HTML refs):  ${BLUE}nt-images .${NC}"
    fi
    ;;

  clean)
    info "🧹 Cleaning build artifacts in the current folder:"
    TARGETS=(dist build out .output .svelte-kit .wrangler .turbo node_modules/.cache .next/cache)
    FOUND=(); for t in "${TARGETS[@]}"; do [ -e "$t" ] && FOUND+=("$t"); done
    [ "${#FOUND[@]}" = 0 ] && { ok "Already clean."; exit 0; }
    printf '   %s\n' "${FOUND[@]}"; read -p "   Delete? [y/N] " C; [[ "$C" =~ ^[sSyY]$ ]] || { info "Cancelled."; exit 0; }
    rm -rf "${FOUND[@]}"; ok "Clean."
    ;;

  # ───── KILL COMBO: ship ─────
  ship)
    CLIENT="${1:-main}"; info "📦 SHIP → build + deploy + QR + open"
    [ -f package.json ] && "$0" push --build "$CLIENT" -y || "$0" push . "$CLIENT" -y
    "$0" qr "$CLIENT"; "$0" open "$CLIENT"
    ;;

  # ───── BETA: shareable client card (HTML + PDF) ─────
  card|share)
    warn "🧪 BETA feature — experimental, may change or be removed. Feedback welcome."
    A="${1:-main}"; case "$A" in http*) URL="$A"; NAME="site";; *) NAME="$(sanitize_branch "$A")"; URL=$(url_for "$NAME");; esac
    TITLE="${2:-$NAME}"; OUT="${NT_CARD_OUT:-nt-card-$NAME}"; HTML="$OUT.html"; PDF="$OUT.pdf"; SHOT="$(mktemp -u).png"
    CHROME=""
    for c in "$NT_CHROME" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium" "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
      [ -n "$c" ] && [ -x "$c" ] && { CHROME="$c"; break; }; done
    [ -z "$CHROME" ] && for c in google-chrome chromium chromium-browser brave-browser; do have "$c" && { CHROME="$(command -v "$c")"; break; }; done
    IMG_TAG="<div class=\"ph\">$TITLE</div>"
    if [ -n "$CHROME" ]; then
      info "📸 Capturing $URL…"
      "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,820 --screenshot="$SHOT" "$URL" >/dev/null 2>&1
      if [ -s "$SHOT" ] && have base64; then IMG_TAG="<img class=\"shot\" alt=\"preview\" src=\"data:image/png;base64,$(base64 < "$SHOT" | tr -d '\n')\">"; fi
      rm -f "$SHOT"
    fi
    QR=""; have qrencode && QR=$(qrencode -o - -t SVG -m 1 "$URL" 2>/dev/null)
    cat > "$HTML" <<HTML
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>$TITLE — preview</title>
<style>@page{size:A4;margin:0}*{margin:0;box-sizing:border-box;font-family:-apple-system,Segoe UI,Roboto,system-ui,sans-serif}
body{color:#0b1020}.card{width:794px;min-height:1123px;margin:0 auto;background:#fff;display:flex;flex-direction:column}
.hero{padding:54px 56px;background:linear-gradient(135deg,#0b1020,#1a1740);color:#fff}
.hero .tag{font-size:13px;letter-spacing:.22em;color:#7fdcff;text-transform:uppercase}
.hero h1{font-size:46px;margin:10px 0 6px;line-height:1.05}.hero a{color:#c7b9ff;font-size:16px;text-decoration:none}
.shotwrap{padding:36px 56px;flex:1}.shot{width:100%;border:1px solid #e4e4e7;border-radius:14px;box-shadow:0 18px 50px rgba(0,0,0,.14)}
.ph{height:360px;display:grid;place-items:center;border-radius:14px;background:linear-gradient(135deg,#35e8ff,#8b6cff);color:#04060f;font-size:40px;font-weight:800}
.foot{display:flex;align-items:center;justify-content:space-between;padding:30px 56px;border-top:1px solid #e4e4e7}
.foot .qr{width:120px;height:120px}.foot .info b{display:block;font-size:18px}.foot .info span{color:#71717a;font-size:14px}
.brand{font-size:12px;color:#a1a1aa;text-align:right}</style></head>
<body><div class="card">
<div class="hero"><div class="tag">Live preview</div><h1>$TITLE</h1><a href="$URL">$URL</a></div>
<div class="shotwrap">$IMG_TAG</div>
<div class="foot"><div class="qr">$QR</div>
<div class="info"><b>Scan to open</b><span>$URL</span></div>
<div class="brand">prepared with<br><b>nt-deploy</b></div></div>
</div></body></html>
HTML
    ok "Created ${BOLD}$HTML${NC}"
    if [ -n "$CHROME" ]; then
      ABS="file://$(cd "$(dirname "$HTML")"&&pwd)/$(basename "$HTML")"
      "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="$PDF" "$ABS" >/dev/null 2>&1
      [ -s "$PDF" ] && ok "Created ${BOLD}$PDF${NC} — a single file to send your client ($(human_size "$(wc -c < "$PDF")"))"
    else warn "Install Chrome/Chromium to export a PDF too. For now: open $HTML and print to PDF."; fi
    have open && open "$HTML" 2>/dev/null
    ;;

  # ───── GUI ─────
  gui)
    if [ "$1" = dns ]; then
      if grep -qE "^[^#]*[[:space:]]nt\.local([[:space:]]|$)" /etc/hosts 2>/dev/null; then ok "nt.local is already configured."; else
        info "To always open the GUI at ${BOLD}http://nt.local:7700${NC}${BLUE}, run once:${NC}"
        echo -e "   ${BLUE}echo '127.0.0.1 nt.local' | sudo tee -a /etc/hosts${NC}"
      fi; exit 0
    fi
    PORT="${1:-7700}"; GUI="$CONFIG_DIR/nt-gui.py"; [ -f "$GUI" ] || GUI="$(dirname "$0")/nt-gui.py"
    [ -f "$GUI" ] || { err "nt-gui.py not found"; exit 1; }
    have python3 || { err "python3 required"; exit 1; }
    HOST=localhost
    if grep -qE "^[^#]*[[:space:]]nt\.local([[:space:]]|$)" /etc/hosts 2>/dev/null; then HOST=nt.local
    else warn "💡 Tip: open it at nt.local with  ${BLUE}nt-gui dns${NC}${YELLOW} (one-time setup)"; fi
    URL="http://$HOST:$PORT"
    info "🪟 GUI → ${BOLD}$URL${NC}${BLUE}  (Ctrl-C to stop)${NC}"
    have open && (sleep 1; open "$URL") &
    NT_PROJECT="$PROJECT" NT_SCRIPT="$(cd "$(dirname "$0")"&&pwd)/$(basename "$0")" python3 "$GUI" "$PORT"
    ;;

  # ───── SETUP ─────
  init)
    check_wrangler; banner
    if [ -n "${NT_PROJECT:-}" ]; then info "📦 Project: ${GREEN}$PROJECT${NC} ${DIM}[$NT_SOURCE]${NC}"; read -p "Change it? [y/N] " CH; [[ "$CH" =~ ^[sSyY]$ ]] || SKIP=1; fi
    if [ -z "${SKIP:-}" ]; then echo ""; echo "Cloudflare Pages project name:"; echo -e "  • base:   ${YELLOW}<name>.pages.dev${NC}"; echo -e "  • client: ${YELLOW}client.<name>.pages.dev${NC}"; echo ""
      read -p "Name [anteprima]: " UP; UP=$(sanitize_branch "${UP:-anteprima}"); mkdir -p "$CONFIG_DIR"; echo "NT_PROJECT=$UP" > "$CONFIG_FILE"; PROJECT="$UP"; ok "Saved to $CONFIG_FILE"; echo ""; fi
    info "🔧 Cloudflare login…"; wrangler login
    info "🔧 Creating project '$PROJECT'…"; wrangler pages project create "$PROJECT" --production-branch=main 2>/dev/null || warn "ℹ️  '$PROJECT' already exists, reusing it"
    echo ""; ok "Ready!"; echo -e "   ${BLUE}nt-push ./dist${NC} → https://$PROJECT.pages.dev"; echo -e "   ${BLUE}nt-ship${NC}        → build + deploy + QR + open"
    check_for_updates
    ;;
  config)
    info "⚙️  Configuration:"; echo "  Project:     $PROJECT  [$NT_SOURCE]"; echo "  Base URL:    https://$PROJECT.pages.dev"
    echo "  Snapshots:   $SNAP_ROOT/$PROJECT  (keep last $SNAP_KEEP)"; echo "  Auto-update: ${NT_AUTO_UPDATE:-0}"
    echo -e "  ${DIM}Global: nt-init  ·  per-repo: a .ntdeploy file with NT_PROJECT=name${NC}"
    ;;
  version|--version|-v) echo "nt-deploy v$VERSION" ;;
  update) self_update ;;

  help|--help|-h|"")
    banner
    cat <<EOF
${BOLD}DEPLOY${NC}
  nt-push [dir] [client]     Deploy a folder (default ./dist → production)
  nt-push --build [client]   Build (npm/pnpm/yarn/bun) + deploy automatically
  nt-push … --dry-run / -y   Simulate / skip production confirmation
  nt-ship [client]           ${MAGENTA}★${NC} build + deploy + QR + open, all in one
  nt-bp [client]             Shortcut for 'nt-push --build'

${BOLD}TIME MACHINE${NC} ${MAGENTA}(kill feature)${NC}
  nt-rollback [client] [ts]  Restore a previous deploy (impossible with wrangler alone!)
  nt-snapshots [client]      List local snapshots

${BOLD}MANAGE${NC}
  nt-list / nt-clients / nt-projects   Deployments, clients, projects
  nt-rm <client> [-y]        Delete a client's deployments (asks to confirm)
  nt-rmproject <name>        Delete a whole project (retype name to confirm)
  nt-logs [client]           Live log tail
  nt-open / nt-copy [client]  Open / copy the URL

${BOLD}QUALITY & TRAFFIC${NC}
  nt-audit [url|client] [mobile|desktop]   PageSpeed pre-test with score (Google engine)
  nt-analytics inject <dir> <token>        Enable visit tracking (Web Analytics)
  nt-analytics open | nt-stats             Open dashboard / show visits

${BOLD}TOOLKIT${NC} ${DIM}(works without Cloudflare too)${NC}
  nt-serve [dir] [port]      Local static server
  nt-create [client]         Premium scaffold (DESIGN.md, AGENTS.md, _headers, manifest…) tuned for top PageSpeed
  nt-design list|add <brand> Fetch a brand DESIGN.md from the community library (Stripe, Linear, Notion…)
  nt-new [name]              Minimal starter site, ready to deploy
  nt-build                   Run the build and show its size
  nt-size [dir]              Output weight report + top files
  nt-zip [dir] [out.zip]     Package a folder
  nt-images [dir] [quality]  Convert PNG/JPEG/GIF → WebP and rewrite references in HTML/CSS/JS
  nt-check [url|client]      Health-check: HTTP status, time, size
  nt-qr [url|client]         QR code in the terminal
  nt-clean                   Remove dist/build/cache
  nt-doctor                  Environment diagnostics
  nt-notes <client> ["…"]    Per-client notes (view/add)
  nt-card [url|client]       ${MAGENTA}🧪 beta${NC} — a shareable one-pager (HTML + PDF) to send a client
  nt-gui [port]              Lightweight browser GUI

${BOLD}SETUP${NC}
  nt-init · nt-config · nt-update · nt-version

${DIM}Tip: 'nt <command>' (e.g. nt ship) · project: -p <name> · auto-update: NT_AUTO_UPDATE=1${NC}
EOF
    ;;
  *) err "Unknown command: $ACTION"; echo "Run 'nt-help' for the list"; exit 1 ;;
esac
