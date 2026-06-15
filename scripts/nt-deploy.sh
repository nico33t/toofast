#!/bin/bash
# toofast (formerly nt-deploy): the web super-tool. Sites & SaaS from idea to live.
# https://github.com/nico33t/toofast   ·   commands: toofast | tf | nt | too *

VERSION="3.0.0"
REPO_RAW="https://raw.githubusercontent.com/nico33t/toofast/main"

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
  echo -e "${BOLD} ⚡ TooFast ${DIM}v$VERSION${NC} ${DIM}— sites & SaaS from idea to live, ${NC}${BOLD}fast${NC}"
  echo -e " ${DIM}https://github.com/nico33t/toofast  ·  commands: toofast | tf | too *${NC}\n"
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
    else echo ""; warn "💡 New version available: ${GREEN}$rv${YELLOW} (yours: $VERSION)"; echo -e "   Update: ${BLUE}too update${NC} ${DIM}(or set NT_AUTO_UPDATE=1)${NC}"; fi
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
> as guardrails for every generation. This is a strong DEFAULT base — values are sensible
> professional defaults you can keep or change. Items marked (edit) should be tailored with
> the user (see "9. Agent Prompt Guide"). For a real brand starting point: \`too design add <brand>\`.

## 1. Visual Theme & Atmosphere
- Purpose: in one line, what this site must represent and the single primary action (the goal). (edit)
- Direction: clean, modern, contetoo first — generous whitespace, restrained color, strong type hierarchy. (edit)
- Calm and trustworthy; a single accent color used sparingly for actions. (edit)

## 2. Color Palette & Roles
| Role | Token | Value |
|---|---|---|
| background | --bg | #ffffff |
| surface | --surface | #f6f7f9 |
| foreground (text) | --fg | #14181f |
| muted text | --muted | #5b6573 |
| border | --border | #e5e8ec |
| primary | --primary | #2563eb |
| accent | --accent | #2563eb |
| success | --success | #16a34a |
| error | --error | #dc2626 |
- Dark mode: invert bg/fg via \`prefers-color-scheme\`. (edit)

## 3. Typography Rules
- Font families: system stack (system-ui, -apple-system, "Segoe UI", Roboto) — zero network cost. Use a web font only if essential, and \`preload\` it. (edit)
- Type scale (fluid): h1 \`clamp(2.2rem,6vw,3.5rem)\` · h2 \`clamp(1.6rem,4vw,2.2rem)\` · body 1rem · small .875rem.
- Weights: 400 body · 600 medium · 700 headings.
- Line heights: 1.6 body · 1.15 headings.

## 4. Component Stylings
- Buttons: radius 10px, padding .7rem 1.2rem. primary = solid --primary; secondary = --surface + 1px --border; ghost = transparent. States: hover (darker/raised), focus-visible (3px ring), disabled (.5 opacity).
- Cards: white/--surface, 1px --border, radius 12px, shadow-sm, 20–24px padding.
- Forms/inputs: 1px --border, radius 8px, padding .6rem .8rem; focus = 2px --primary ring; error = --error border + helper text.
- Navigation: sticky top, backdrop-blur, 1px bottom border; mobile = hamburger → panel.
- Motion: sober — short (120–200ms), eased, purposeful (feedback/orientation only); honor \`prefers-reduced-motion\`; never decorative or distracting.

## 5. Layout Principles
- Container max-width 1080px, centered; side padding \`clamp(16px,5vw,40px)\`.
- 12-column mental grid; card lists via \`auto-fit minmax(260px,1fr)\`.
- Spacing rhythm: 8px base (8/12/16/24/32/48/64).
- Padding & whitespace: consistent rhythm on the 8px scale; nothing cramped or arbitrary; let key elements breathe.

## 6. Depth & Elevation
- Shadows: sm \`0 1px 2px rgba(0,0,0,.06)\` · md \`0 6px 20px rgba(0,0,0,.10)\` · lg \`0 18px 50px rgba(0,0,0,.16)\`.
- Z-index: base 0 · sticky/nav 10 · dropdown 50 · overlay/modal 100 · toast 1000.
- Keep elevation subtle; reserve lg shadows for modals.

## 7. Do's and Don'ts
- ✅ Do: one accent color, generous whitespace, visible focus, set \`width\`/\`height\` on media, WebP images (\`too images\`).
- ❌ Don't: render-blocking web fonts, contrast < 4.5:1, layout-shifting elements, more than 2 type families.

## 8. Responsive Behavior
- Breakpoints: mobile < 640 · tablet 640–1024 · desktop > 1024.
- Desktop: multi-column, full nav. Tablet: 2-column, condensed. Mobile: single column, tap targets ≥ 44px, collapsed nav.

## 9. Agent Prompt Guide
Instructions for AI agents reading this file:
- These are professional DEFAULTS — confirm or change them WITH the user before building.
- If the user has a brand kit or reference, adapt the values above to it, or run
  \`too design add <brand>\` to start from a real brand template.
- Ask the user: 1) feeling/aesthetic? 2) brand colors/logo? 3) typography vibe? 4) reference
  sites? 5) light, dark, or both? 6) audience and main devices?
- Before building, reason explicitly about: the DIRECTION and what the site must represent;
  the user's EYE PATH (F/Z reading pattern, one clear primary CTA above the fold, visual
  hierarchy by size/contrast/space); UNIFORMITY (reuse the same components, spacing and voice
  everywhere); MOTION sobriety; correct PADDING rhythm. Leave nothing to chance — keep it SIMPLE.
- Use ONLY values defined above; never introduce off-scale colors, fonts, or spacing.
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
- Keep payload lean; convert images to WebP (\`too images\`).

## Project
- Static site deployed to Cloudflare Pages with nt-deploy: \`too push . <client>\`.
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
- Preview: \`too serve .\`  ·  Audit: \`too audit <client>\`  ·  Ship: \`too push . <client>\`
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
# Legal docs (GDPR-aware TEMPLATES, not legal advice). $1 = web dir.
nt_legal(){
  local D="$(date +%Y-%m-%d)"
  cat > "$1/privacy.html" <<MD
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>Privacy Policy — $NAME</title><link rel="stylesheet" href="/styles.css"></head>
<body><main class="legal">
<p><a href="/">← $NAME</a></p>
<h1>Privacy Policy</h1>
<p class="legal__date">Last updated: $D</p>
<div class="legal__note"><strong>Template — not legal advice.</strong> Review with a qualified
professional and complete every [placeholder] before publishing.</div>

<h2>1. Data controller</h2>
<p>[Company name], [address] — contact: [email]. VAT/Reg: [number].</p>

<h2>2. Data we process</h2>
<ul>
<li><strong>Contact data</strong> you submit (e.g. name, email, message) — only if you contact us.</li>
<li><strong>Technical logs</strong> (IP address, user agent, timestamps) processed by our hosting
provider for security and operation.</li>
<li>No advertising or tracking cookies are set by default.</li>
</ul>

<h2>3. Purposes &amp; legal basis (GDPR Art. 6)</h2>
<ul>
<li>Replying to your request — consent / pre-contractual steps.</li>
<li>Operating and securing the site — legitimate interest.</li>
<li>Legal obligations — where applicable.</li>
</ul>

<h2>4. Recipients</h2>
<p>Hosting/CDN provider [e.g. Cloudflare, Inc.] as data processor. We do not sell your data.
International transfers, if any, rely on adequacy decisions or Standard Contractual Clauses.</p>

<h2>5. Retention</h2>
<p>Contact data: [period, e.g. 24 months]. Logs: [period]. Then deleted or anonymized.</p>

<h2>6. Your rights</h2>
<p>Access, rectification, erasure, restriction, portability, objection, and withdrawal of consent.
To exercise them: [email]. You may lodge a complaint with your supervisory authority
([e.g. Garante per la protezione dei dati personali, Italy]).</p>

<h2>7. Contact</h2>
<p>[email] — [Company name].</p>
</main></body></html>
MD
  cat > "$1/cookie-policy.html" <<MD
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>Cookie Policy — $NAME</title><link rel="stylesheet" href="/styles.css"></head>
<body><main class="legal">
<p><a href="/">← $NAME</a></p>
<h1>Cookie Policy</h1>
<p class="legal__date">Last updated: $D</p>
<div class="legal__note"><strong>Template — not legal advice.</strong> Update this if you add
analytics or third-party embeds, and complete the [placeholders].</div>
<h2>Cookies we use</h2>
<p>By default this site sets <strong>no tracking or advertising cookies</strong>. Only strictly
necessary cookies may be used to deliver the site securely (technical, no consent required).</p>
<h2>If you enable analytics</h2>
<p>If you add a measurement tool (e.g. privacy-friendly analytics), list it here with provider,
purpose, duration, and obtain prior consent via a banner where required.</p>
<h2>Managing cookies</h2>
<p>You can block or delete cookies in your browser settings. See also our
<a href="/privacy.html">Privacy Policy</a>.</p>
</main></body></html>
MD
  cat > "$1/terms.html" <<MD
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>Terms of Use — $NAME</title><link rel="stylesheet" href="/styles.css"></head>
<body><main class="legal">
<p><a href="/">← $NAME</a></p>
<h1>Terms of Use</h1>
<p class="legal__date">Last updated: $D</p>
<div class="legal__note"><strong>Template — not legal advice.</strong> Review with a professional
and complete the [placeholders] before publishing.</div>
<h2>1. Acceptance</h2><p>By using $NAME you agree to these terms.</p>
<h2>2. Intellectual property</h2><p>All content is owned by [Company name] unless stated otherwise.</p>
<h2>3. Acceptable use</h2><p>Do not misuse, disrupt, or attempt to gain unauthorized access to the site.</p>
<h2>4. Disclaimer &amp; liability</h2><p>The site is provided "as is"; to the extent permitted by law
[Company name] is not liable for indirect or incidental damages.</p>
<h2>5. Governing law</h2><p>These terms are governed by the laws of [country/region]. Venue: [city].</p>
<h2>6. Contact</h2><p>[email] — [Company name].</p>
</main></body></html>
MD
}

# optional dev server with live reload. \$1=dir \$2=stack \$3=serve(yes|no)
nt_chrome(){  # echo path to a Chromium-based browser, or empty
  local c
  for c in "$NT_CHROME" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium" "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return; }; done
  for c in google-chrome chromium chromium-browser brave-browser; do have "$c" && { command -v "$c"; return; }; done
  echo ""
}
# SaaS planning + research docs (templates the agent fills). $1=dir
nt_saas_docs(){
  cat > "$1/BUSINESS_PLAN.md" <<MD
# Business Plan — $NAME

> Template — the AI agent fills this WITH the user, then exports BUSINESS_PLAN.pdf.

## 0. Architecture & scalability (core — decide first)
- **Docker-first**: ship as a small, stateless container (see \`Dockerfile\` + \`docker-compose.yml\`).
- **Scale horizontally**: stateless app + managed DB/cache; \`docker compose up --scale app=N\`, then Kubernetes/Fly/ECS when needed.
- **Multi-tenant** by default; rate limits + billing alerts on every paid API; observability (logs/metrics/traces) from day one.

## 1. Problem
- What painful, frequent, expensive problem does $NAME solve? For whom?

## 2. Solution
- The product in one sentence. The core workflow. Why now.

## 3. Ideal customer (ICP)
- Segment, role, company size, where they hang out.

## 4. Market & potential
- TAM / SAM / SOM (estimate + source). Trend. Why it's growing.

## 5. Competitors
- See COMPETITORS.md. Summarize the 3 closest and our edge.

## 6. Killer feature
- See KILLER_FEATURE.md. The one thing rivals don't have.

## 7. Business model
- Pricing tiers, free trial vs freemium, expected ACV / MRR path.

## 8. Go-to-market
- See LAUNCH.md. First 100 users plan, channels, content.

## 9. Roadmap
- MVP (weeks 1–4), v1, v2. What's explicitly out of scope.

## 10. Risks & mitigations
- Top 3 risks (market, tech, legal) and how we de-risk.
MD
  cat > "$1/COMPETITORS.md" <<MD
# Competitors — $NAME

| Competitor | What they do | Pricing | Strength | Weakness | Our edge |
|---|---|---|---|---|---|
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |

> Agent: research the real market (web). Be specific and honest. Our edge must be defensible.
MD
  cat > "$1/KILLER_FEATURE.md" <<MD
# Killer feature — $NAME

> Every SaaS built here MUST ship one killer feature competitors don't have.

## The feature
- One sentence:

## Why it's a killer
- [ ] 10x better at one job (not 10% better)
- [ ] Defensible (data, workflow lock-in, integration, or speed others can't match)
- [ ] Demoable in < 30 seconds
- [ ] Tied directly to the core value, not a gimmick

## How we build it first
- The MVP slice that proves it, and how we show it on the landing page.
MD
  cat > "$1/LAUNCH.md" <<MD
# Launch checklist — $NAME

## Validate before building
- [ ] Talked to 5+ real prospects; confirmed the problem and willingness to pay.

## Build foundations
- [ ] Multi-tenant from day one (right default for ~90% of SaaS).
- [ ] Auth + billing (Stripe) + transactional email wired early.
- [ ] Hard rate limits + billing alerts on every paid API (avoid runaway bills).
- [ ] GDPR basics now; SOC 2 groundwork before enterprise asks.

## Landing page (outcome-driven, converts)
- [ ] Hero states the OUTCOME + who it's for in one line; one primary CTA.
- [ ] Show transformation, not a feature list; interactive demo / product tour.
- [ ] Social proof (logos, testimonials, metrics). Bento grid for features.
- [ ] Mobile-first; load < 2–3s; copy at a 5th–7th grade reading level.

## Launch
- [ ] Analytics + key events; feedback channel.
- [ ] Channels: warm list, communities, Product Hunt, content/SEO, partnerships.
- [ ] Day-1 monitoring: errors, latency, signups, churn.
MD
  cat > "$1/SETUP.md" <<MD
# Setup — $NAME

## Tailwind + shadcn/ui (Vite)
\`\`\`bash
npm i -D tailwindcss postcss autoprefixer && npx tailwindcss init -p
npx shadcn@latest init        # then: npx shadcn@latest add button card input ...
\`\`\`

## Run
\`\`\`bash
npm install && npm run dev    # preview before writing features
\`\`\`

## Deploy
- Static/SPA build: \`too push dist <client>\`. Full-stack Next.js: deploy on Vercel.
MD
}
# Read colors from $1/DESIGN.md and apply them to the site's CSS :root (so each
# DESIGN.md produces its own brand colors). Best-effort, Python-based.
nt_apply_palette(){
  have python3 || return 0
  python3 - "$1" <<'PY'
import sys, re, os
d = sys.argv[1]; dm = os.path.join(d, "DESIGN.md")
cssf = os.path.join(d, "styles.css")
if not os.path.exists(cssf): cssf = os.path.join(d, "src", "style.css")
if not os.path.exists(dm) or not os.path.exists(cssf): sys.exit(0)
txt = open(dm, encoding="utf-8", errors="replace").read()
hexes = re.findall(r'#[0-9a-fA-F]{6}\b', txt)
if not hexes: sys.exit(0)
def rgb(h): h = h[1:]; return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def lum(h): r, g, b = [c/255 for c in rgb(h)]; return 0.2126*r + 0.7152*g + 0.0722*b
def sat(h):
    r, g, b = rgb(h); mx = max(r, g, b); mn = min(r, g, b)
    return 0 if mx == 0 else (mx - mn) / mx
def darken(h, f=0.82): r, g, b = rgb(h); return "#%02x%02x%02x" % (int(r*f), int(g*f), int(b*f))
seen = []
for h in hexes:
    if h.lower() not in seen: seen.append(h.lower())
colored = [h for h in seen if sat(h) > 0.35 and 0.08 < lum(h) < 0.92]
neutrals = [h for h in seen if sat(h) <= 0.18]
darks = sorted(neutrals, key=lum); lights = sorted(neutrals, key=lum, reverse=True)
def pick(lst, i, fb): return lst[i] if len(lst) > i else fb
def labeled(keys, avoid=()):
    for ln in txt.splitlines():
        low = ln.lower()
        if any(k in low for k in keys) and not any(a in low for a in avoid):
            m = re.search(r'#[0-9a-fA-F]{6}', ln)
            c = m.group(0).lower() if m else ""
            if c and sat(c) > 0.2 and 0.08 < lum(c) < 0.9: return c
    return None
AV = ("error", "success", "danger", "warning", "warn", "destructive", "semantic")
prim = labeled(("primary", "brand", "accent", "cta", "action", "link"), AV) or (colored[0] if colored else "#2563eb")
acc = labeled(("accent", "secondary"), AV) or next((c for c in colored if c != prim), prim)
# Theme is decided by the BACKGROUND/canvas color, NOT by the mere presence of dark
# colors (those are usually text). Default to LIGHT unless the background is dark.
bgc = None
for ln in txt.splitlines():
    low = ln.lower()
    if any(k in low for k in ("background", "canvas", "page bg", "--bg", "base color", "body bg", "surface base")):
        m = re.search(r'#[0-9a-fA-F]{6}', ln)
        if m: bgc = m.group(0).lower(); break
if bgc is None:
    bgc = lights[0] if (lights and lum(lights[0]) > 0.85) else "#ffffff"
dark = lum(bgc) < 0.32
if dark:
    bg = bgc; surface = (pick(darks, 1, "#1c1917") if darks else "#1c1917"); fg = (max(seen, key=lum) if lum(max(seen, key=lum)) > 0.6 else "#e7e5e4")
    muted = pick([h for h in neutrals if 0.3 < lum(h) < 0.7], 0, "#a8a29e"); border = pick(darks, 2, surface)
    scheme = "dark"
else:
    bg = bgc if lum(bgc) > 0.92 else "#ffffff"
    surface = pick([h for h in lights if 0.9 < lum(h) < 0.995], 0, "#f6f7f9"); fg = (min(seen, key=lum) if lum(min(seen, key=lum)) < 0.4 else "#14181f")
    muted = pick([h for h in neutrals if 0.3 < lum(h) < 0.62], 0, "#5b6573"); border = pick([h for h in lights if 0.85 < lum(h) < 0.97], 0, "#e5e8ec")
    scheme = "light"
root = ("--bg:%s;--surface:%s;--fg:%s;--muted:%s;--border:%s;--primary:%s;--primary-h:%s;--accent:%s;--accent2:%s;--max:1100px;--r:14px"
        % (bg, surface, fg, muted, border, prim, darken(prim), acc, prim))
css = open(cssf, encoding="utf-8").read()
css2 = re.sub(r':root\{[^}]*--r:[^}]*\}', ':root{' + root + '}', css, count=1)
if css2 != css:
    open(cssf, "w", encoding="utf-8").write(css2)
ix = os.path.join(d, "index.html")
if os.path.exists(ix):
    h = open(ix, encoding="utf-8").read()
    h = re.sub(r'(<meta name="theme-color" content=")[^"]*(">)', r'\g<1>' + bg + r'\g<2>', h)
    h = re.sub(r'(<meta name="color-scheme" content=")[^"]*(">)', r'\g<1>' + scheme + r'\g<2>', h)
    open(ix, "w", encoding="utf-8").write(h)
print("   palette from DESIGN.md applied: %s theme · primary %s · bg %s" % (scheme, prim, bg))
PY
}
nt_devserve(){
  [ "$3" = yes ] || return 0
  if [ "$2" = vite ]; then
    have npm || { warn "npm not found — start later with: cd $1 && npm install && npm run dev"; return 0; }
    info "📦 Installing deps + starting Vite (HMR — edit and see changes live)…"
    ( cd "$1" && npm install && npm run dev )
  else
    E="$CONFIG_DIR/nt-edit.py"; [ -f "$E" ] || E="$(dirname "$0")/nt-edit.py"
    if [ -f "$E" ] && have python3; then
      info "🔁 Live editor + auto-reload at http://localhost:8080 (drag the bottom-right widget)…"
      have open && (sleep 1; open "http://localhost:8080") &
      python3 "$E" "$1" 8080
    elif have npx; then info "🔁 Starting live-server (auto-reload)…"; ( cd "$1" && npx --yes live-server )
    elif have python3; then warn "serving without auto-reload (refresh manually)."; ( cd "$1" && python3 -m http.server 8080 )
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
    if [ -n "$TS" ]; then ARCHIVE="$DIR/$TS.tar.gz"; [ -f "$ARCHIVE" ] || { err "Snapshot $TS not found. See: too snapshots $BRANCH"; exit 1; }
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
    echo -e "   ${DIM}Restore with: too rollback $BRANCH [timestamp]${NC}"
    ;;

  # ───── MANAGE (Cloudflare) ─────
  rm|delete)
    check_wrangler; need_jq || exit 1
    CLIENT=""; YES=0; for a in "$@"; do case "$a" in -y|--yes) YES=1;; *) CLIENT="$a";; esac; done
    [ -z "$CLIENT" ] && { err "Usage: too rm <client> [-y]"; exit 1; }
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
    [ -z "$NAME" ] && { err "Usage: too rmproject <project-name>"; exit 1; }
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
  audit|pagespeed)
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
    echo -e "   ${DIM}desktop run: too audit $A desktop  ·  same engine as pagespeed.web.dev${NC}"
    ;;

  # ───── ANALYTICS / TRAFFIC ─────
  analytics|stats)
    SUB="${1:-help}"; [ "$ACTION" = stats ] && SUB="stats" || shift 2>/dev/null
    case "$SUB" in
      inject)
        FOLDER="${1:-.}"; TOKEN="${2:-$NT_CF_BEACON}"
        [ -d "$FOLDER" ] || { err "Folder '$FOLDER' not found"; exit 1; }
        [ -z "$TOKEN" ] && { err "Need a Web Analytics token: too analytics inject <folder> <token>"; echo "   Create it: dash.cloudflare.com → Web Analytics → Add a site"; exit 1; }
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
          echo -e "   Or open the dashboard:  ${BLUE}too analytics open${NC}"
          exit 0
        fi
        need_jq || exit 1
        SINCE=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
        UNTIL=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        Q=$(jq -nc --arg a "$NT_CF_ACCOUNT" --arg t "$NT_CF_SITETAG" --arg s "$SINCE" --arg u "$UNTIL" \
          '{query:"query($a:String!,$t:String!,$s:Time!,$u:Time!){viewer{accounts(filter:{accountTag:$a}){rumPageloadEventsAdaptiveGroups(limit:1,filter:{siteTag:$t,datetime_geq:$s,datetime_leq:$u}){count sum{visits}}}}}",variables:{a:$a,t:$t,s:$s,u:$u}}')
        R=$(curl -fsSL --max-time 20 -H "Authorization: Bearer $NT_CF_TOKEN" -H "Contetoo Type: application/json" -d "$Q" https://api.cloudflare.com/client/v4/graphql) \
          || { err "API request failed."; exit 1; }
        echo "$R" | jq -e '.errors and (.errors|length>0)' >/dev/null 2>&1 && { err "API: $(echo "$R"|jq -r '.errors[0].message')"; exit 1; }
        G=$(echo "$R"|jq -r '.data.viewer.accounts[0].rumPageloadEventsAdaptiveGroups[0]')
        PV=$(echo "$G"|jq -r '.count // 0'); VS=$(echo "$G"|jq -r '.sum.visits // 0')
        echo -e "   Last 7 days →  Page views: ${BOLD}$PV${NC}   Visits: ${BOLD}$VS${NC}"
        ;;
      *) echo "Usage: too analytics inject <folder> <token> | open | stats" ;;
    esac
    ;;

  # ───── CLIENT NOTES ─────
  notes|note)
    CLIENT="${1:-}"; [ -z "$CLIENT" ] && { err "Usage: too notes <client> [\"note text\"]"; exit 1; }
    B=$(sanitize_branch "$CLIENT"); ND="$CONFIG_DIR/notes/$PROJECT"; mkdir -p "$ND"; F="$ND/$B.md"
    shift; TEXT="$*"
    if [ -n "$TEXT" ]; then echo "- [$(date '+%Y-%m-%d %H:%M')] $TEXT" >> "$F"; ok "Note added for '$B'."
    else info "🗒  Notes for '$B' (project: $PROJECT):"; [ -s "$F" ] && sed 's/^/   /' "$F" || warn "   no notes yet. Add one: too notes $B \"...\""; fi
    ;;

  # ───── TOOLKIT (works WITHOUT Cloudflare too) ─────
  serve)
    DIR="${1:-.}"; PORT="${2:-8080}"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    info "🖥  Local server: ${BOLD}http://localhost:$PORT${NC}${BLUE}  (Ctrl-C to stop)${NC}"
    have open && (sleep 1; open "http://localhost:$PORT") &
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
        echo -e "   ${DIM}Add one:${NC} too design add <brand>   ${DIM}(e.g. too design add bugatti)${NC}"
        ;;
      add)
        NAME=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
        [ -z "$NAME" ] && { err "Usage: too design add <brand> [destfile]"; exit 1; }
        DEST="${2:-DESIGN.md}"; TMP=$(mktemp)
        if curl -fsSL "$BASE/$NAME/DESIGN.md" -o "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
          [ -f "$DEST" ] && { cp "$DEST" "$DEST.bak"; warn "Backed up existing → $DEST.bak"; }
          { echo "<!-- Design template '$NAME' — source: github.com/VoltAgent/awesome-design-md (MIT), design-md/$NAME — fetched $(date +%F) -->"; echo; cat "$TMP"; } > "$DEST"
          rm -f "$TMP"; ok "Added '${BOLD}$NAME${NC}' template → ${BOLD}$DEST${NC}"
          echo -e "   ${DIM}AI agents will now follow this brand's design rules. Tweak as needed.${NC}"
        else rm -f "$TMP"; err "Template '$NAME' not found. Browse: too design list"; fi
        ;;
      *) echo "Usage: too design list | add <brand> [destfile]" ;;
    esac
    ;;

  create|scaffold)
    NAME="${1:-site}"; SAFE=$(sanitize_branch "$NAME"); URL=$(url_for "$SAFE")
    [ -e "$SAFE" ] && { err "'$SAFE' already exists"; exit 1; }
    STACK=""; SERVE=""; DESIGN_BRAND=""
    for a in "${@:2}"; do case "$a" in
      --vite) STACK=vite;; --plain|--static) STACK=plain;; --serve) SERVE=yes;; --no-serve) SERVE=no;;
      --design=*) DESIGN_BRAND="${a#--design=}";;
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
    if [ -z "$DESIGN_BRAND" ] && [ -t 0 ]; then
      read -p "Use a brand DESIGN.md as a base? (e.g. stripe, linear, notion — empty = blank spec) " DESIGN_BRAND
    fi
    if [ "$STACK" = vite ]; then
      mkdir -p "$SAFE/src" "$SAFE/public"
      nt_docs "$SAFE"; nt_meta "$SAFE/public"; nt_legal "$SAFE/public"
      cat > "$SAFE/public/_headers" <<'HDR'
/*
  X-Contetoo Type-Options: nosniff
  X-Frame-Options: SAMEORIGIN
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
  Contetoo Security-Policy: default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; script-src 'self'; base-uri 'self'; form-action 'self'
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
:root{--bg:#fff;--fg:#0b1020;--muted:#5a6b88;--accent:#6d4aff;--accent2:#35e8ff;--max:1080px}
/* Light by default. Dark opt-in: @media (prefers-color-scheme:dark){:root{--bg:#0b1020;--fg:#e6f0ff;--muted:#9fb0d0}} */
body{fotoo family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--fg);line-height:1.6;min-height:100dvh;display:flex;flex-direction:column}
img{max-width:100%;height:auto;display:block}
.skip{position:absolute;left:-999px}.skip:focus{left:12px;top:12px;background:#fff;color:#000;padding:8px;border-radius:8px}
.site-header{padding:18px clamp(16px,5vw,40px)}
main{flex:1;width:100%;max-width:var(--max);margin:0 auto;padding:clamp(40px,9vw,110px) clamp(16px,5vw,40px)}
.hero h1{fotoo size:clamp(2.4rem,8vw,4.4rem);line-height:1.05;letter-spacing:-.02em;background:linear-gradient(120deg,var(--accent2),var(--accent));-webkit-background-clip:text;background-clip:text;color:transparent}
.hero p{margin:18px 0 28px;color:var(--muted);fotoo size:clamp(1rem,2.6vw,1.3rem);max-width:60ch}
.cta{display:inline-block;padding:14px 26px;border-radius:12px;text-decoration:none;fotoo weight:700;background:linear-gradient(120deg,var(--accent2),var(--accent));color:#04060f}
.site-footer{padding:24px clamp(16px,5vw,40px);color:var(--muted)}
CSS
      printf 'node_modules\ndist\n.DS_Store\n' > "$SAFE/.gitignore"
      ok "Created premium starter ${BOLD}$SAFE/${NC} ${DIM}(Vite + HMR)${NC}"
      echo -e "   ${DIM}files:${NC} index.html · src/main.js · src/style.css · package.json · DESIGN.md · AGENTS.md · CLAUDE.md · public/(_headers, robots, sitemap, manifest, favicon, 404)"
      echo -e "   ${DIM}dev:${NC} cd $SAFE && npm install && npm run dev   ${DIM}·  build+ship:${NC} too bp $SAFE"
      [ -n "$DESIGN_BRAND" ] && { "$0" design add "$DESIGN_BRAND" "$SAFE/DESIGN.md"; rm -f "$SAFE/DESIGN.md.bak"; }
      nt_apply_palette "$SAFE"
      nt_devserve "$SAFE" vite "$SERVE"
      exit 0
    fi
    mkdir -p "$SAFE/assets"
    # — assets/hero.svg : original lightweight illustration (real image, scalable, responsive) —
    cat > "$SAFE/assets/hero.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 480" role="img" aria-label="Abstract product illustration">
  <defs>
    <linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2563eb"/><stop offset="1" stop-color="#6d4aff"/>
    </linearGradient>
    <linearGradient id="g2" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#35e8ff"/><stop offset="1" stop-color="#2563eb"/>
    </linearGradient>
  </defs>
  <rect width="640" height="480" rx="28" fill="#0b1020"/>
  <circle cx="470" cy="150" r="150" fill="url(#g1)" opacity="0.5"/>
  <circle cx="180" cy="360" r="120" fill="url(#g2)" opacity="0.35"/>
  <g stroke="#ffffff" stroke-opacity="0.08">
    <path d="M0 120H640M0 240H640M0 360H640M160 0V480M320 0V480M480 0V480"/>
  </g>
  <rect x="90" y="120" width="300" height="150" rx="16" fill="#15171d" stroke="#ffffff" stroke-opacity="0.12"/>
  <rect x="112" y="146" width="150" height="14" rx="7" fill="url(#g2)"/>
  <rect x="112" y="176" width="220" height="10" rx="5" fill="#ffffff" fill-opacity="0.18"/>
  <rect x="112" y="196" width="180" height="10" rx="5" fill="#ffffff" fill-opacity="0.12"/>
  <rect x="112" y="226" width="90" height="26" rx="13" fill="url(#g1)"/>
  <rect x="300" y="250" width="250" height="120" rx="16" fill="#15171d" stroke="#ffffff" stroke-opacity="0.12"/>
  <circle cx="335" cy="285" r="14" fill="url(#g1)"/>
  <rect x="360" y="278" width="150" height="10" rx="5" fill="#ffffff" fill-opacity="0.18"/>
  <rect x="322" y="320" width="206" height="10" rx="5" fill="#ffffff" fill-opacity="0.12"/>
  <rect x="322" y="340" width="140" height="10" rx="5" fill="#ffffff" fill-opacity="0.10"/>
</svg>
SVG
    # — index.html : rich, responsive, real sections + imagery —
    cat > "$SAFE/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>$NAME</title>
  <meta name="description" content="$NAME — a fast, modern, accessible website built with nt-deploy.">
  <meta name="theme-color" content="#ffffff">
  <meta name="color-scheme" content="light dark">
  <meta property="og:type" content="website">
  <meta property="og:title" content="$NAME">
  <meta property="og:description" content="$NAME — fast, modern, accessible.">
  <meta property="og:url" content="$URL">
  <meta property="og:image" content="$URL/assets/hero.svg">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="canonical" href="$URL">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <header class="nav" id="top">
    <a class="brand" href="#top"><span class="brand__dot"></span> $NAME</a>
    <nav class="nav__links" id="menu" aria-label="Primary">
      <a href="#features">Features</a><a href="#how">How</a><a href="#pricing">Pricing</a><a href="#faq">FAQ</a><a href="#contact">Contact</a>
    </nav>
    <a class="btn btn--sm" href="#contact">Get in touch</a>
    <button class="nav__toggle" id="navToggle" aria-label="Menu" aria-expanded="false">☰</button>
  </header>

  <main id="main">
    <section class="hero">
      <div class="hero__text reveal">
        <p class="eyebrow">Welcome to $NAME</p>
        <h1>Build something <span class="accent">people love</span>.</h1>
        <p class="lede">A fast, modern, accessible starting point — responsive by default and
          tuned for top PageSpeed scores. Replace this copy with your story.</p>
        <div class="hero__cta">
          <a class="btn" href="#contact">Get started</a>
          <a class="btn btn--ghost" href="#features">Learn more →</a>
        </div>
      </div>
      <img class="hero__art reveal" src="/assets/hero.svg" alt="" width="640" height="480" loading="eager">
    </section>

    <section class="trust"><span>Trusted by teams that ship</span>
      <div class="trust__row" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i></div>
    </section>

    <section id="features" class="section">
      <header class="section__head reveal"><p class="eyebrow">Features</p><h2>Everything you need, nothing you don't.</h2></header>
      <div class="cards">
        <article class="card reveal">
          <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h7l-1 8 10-12h-7l1-8z"/></svg>
          <h3>Fast by default</h3><p>No render-blocking fonts, deferred JS, optimized assets. Loads instantly.</p>
        </article>
        <article class="card reveal">
          <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2 2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
          <h3>Responsive</h3><p>Looks right on every screen — mobile, tablet, desktop — out of the box.</p>
        </article>
        <article class="card reveal">
          <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
          <h3>Accessible &amp; safe</h3><p>Semantic, keyboard-friendly, with secure headers configured.</p>
        </article>
      </div>
    </section>

    <section id="how" class="section">
      <header class="section__head reveal"><p class="eyebrow">How it works</p><h2>Three steps to live.</h2></header>
      <div class="steps">
        <div class="step reveal"><b>01</b><h3>Plan</h3><p>We align on goals, audience and the one job the page must do.</p></div>
        <div class="step reveal"><b>02</b><h3>Build</h3><p>Design and code in tight loops — you see something real every few days.</p></div>
        <div class="step reveal"><b>03</b><h3>Ship</h3><p>Audited for speed &amp; accessibility, then deployed in one command.</p></div>
      </div>
    </section>

    <section id="showcase" class="section section--split">
      <div class="reveal"><p class="eyebrow">Showcase</p><h2>Show your work beautifully.</h2>
        <p class="lede">Swap this illustration for a screenshot or photo. Keep images light —
          run <code>too images</code> to convert them to WebP automatically.</p>
        <a class="btn btn--ghost" href="#contact">See more →</a></div>
      <!-- DRAFT placeholder photo (royalty-free, Lorem Picsum). Replace with a real/self-hosted image, then run too images. -->
      <img class="panel reveal" src="https://picsum.photos/seed/$SAFE/1200/800" alt="Placeholder — replace with your image" width="1200" height="800" loading="lazy">
    </section>

    <section class="stats reveal">
      <div><b>99+</b><span>PageSpeed score</span></div>
      <div><b>0</b><span>tracking cookies</span></div>
      <div><b>&lt;1s</b><span>to first paint</span></div>
    </section>

    <section id="testimonials" class="section">
      <header class="section__head reveal"><p class="eyebrow">Testimonials</p><h2>Loved by the people who use it.</h2></header>
      <div class="quotes">
        <figure class="quote reveal"><blockquote>"Exactly what we needed — fast, clean, and shipped in days, not months."</blockquote><figcaption>— Replace with a real client quote</figcaption></figure>
        <figure class="quote reveal"><blockquote>"The handoff was flawless. Everything was documented and easy to take over."</blockquote><figcaption>— Replace with a real client quote</figcaption></figure>
      </div>
    </section>

    <section id="pricing" class="section">
      <header class="section__head reveal"><p class="eyebrow">Pricing</p><h2>Simple, transparent pricing.</h2></header>
      <div class="pricing">
        <div class="tier reveal"><h3>Starter</h3><div class="price">€—</div><ul><li>Landing page</li><li>Responsive &amp; accessible</li><li>1 revision</li></ul><a class="btn btn--ghost" href="#contact">Choose</a></div>
        <div class="tier feat reveal"><h3>Pro</h3><div class="price">€—</div><ul><li>Multi-page site</li><li>SEO + analytics</li><li>3 revisions</li></ul><a class="btn" href="#contact">Choose</a></div>
        <div class="tier reveal"><h3>Scale</h3><div class="price">€—</div><ul><li>Custom build</li><li>Integrations</li><li>Ongoing support</li></ul><a class="btn btn--ghost" href="#contact">Talk to us</a></div>
      </div>
    </section>

    <section id="faq" class="section">
      <header class="section__head reveal"><p class="eyebrow">FAQ</p><h2>Questions, answered.</h2></header>
      <div class="faq reveal">
        <details open><summary>How long does a project take?</summary><p>A focused landing page ships in days; larger sites in a few weeks.</p></details>
        <details><summary>Do I own the code?</summary><p>Yes — you get the full source and design system, no lock-in.</p></details>
        <details><summary>Is it fast and accessible?</summary><p>Every build targets PageSpeed ≥ 95 and WCAG-friendly accessibility.</p></details>
        <details><summary>Can you maintain it after launch?</summary><p>Yes, ongoing support is available on the Scale plan.</p></details>
      </div>
    </section>

    <section id="contact" class="section cta-band reveal">
      <h2>Ready to start?</h2>
      <p class="lede">Tell us what you're building. We'll get back within a day.</p>
      <a class="btn btn--lg" href="mailto:hello@example.com">hello@example.com</a>
    </section>
  </main>

  <footer class="footer">
    <div class="footer__brand"><span class="brand__dot"></span> $NAME</div>
    <nav class="footer__links" aria-label="Legal">
      <a href="/privacy.html">Privacy</a><a href="/cookie-policy.html">Cookies</a><a href="/terms.html">Terms</a>
    </nav>
    <p class="footer__meta">© <span id="y"></span> $NAME</p>
  </footer>
  <script src="/app.js" defer></script>
</body>
</html>
HTML
    # — styles.css : rich, responsive, light theme (DESIGN.md defaults) —
    cat > "$SAFE/styles.css" <<'CSS'
*,*::before,*::after{box-sizing:border-box;margin:0}
:root{--bg:#fff;--surface:#f6f7f9;--fg:#14181f;--muted:#5b6573;--border:#e5e8ec;
 --primary:#2563eb;--primary-h:#1e51c8;--accent:#6d4aff;--accent2:#35e8ff;--max:1100px;--r:14px}
/* Default theme: LIGHT (preferred unless the client asks for dark).
   To opt into auto dark, add: @media (prefers-color-scheme:dark){:root{--bg:#0b1020;--surface:#13182a;--fg:#e9eefb;--muted:#9fb0d0;--border:#222a44}} */
html{-webkit-text-size-adjust:100%;scroll-behavior:smooth}
body{fotoo family:system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;background:var(--bg);color:var(--fg);line-height:1.6;-webkit-fotoo smoothing:antialiased}
img{max-width:100%;height:auto;display:block}a{color:inherit;text-decoration:none}
:focus-visible{outline:2px solid var(--primary);outline-offset:3px;border-radius:4px}
.skip{position:absolute;left:-999px}.skip:focus{left:12px;top:12px;background:var(--fg);color:var(--bg);padding:8px 12px;border-radius:8px;z-index:30}
.eyebrow{fotoo size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);margin-bottom:12px}
.lede{color:var(--muted);fotoo size:clamp(1rem,2.2vw,1.2rem);max-width:60ch}
h1,h2,h3{letter-spacing:-.02em;line-height:1.08}h2{fotoo size:clamp(1.7rem,4.4vw,2.5rem)}h3{fotoo size:1.15rem}
.accent{background:linear-gradient(120deg,var(--primary),var(--accent));-webkit-background-clip:text;background-clip:text;color:transparent}
.btn{display:inline-flex;align-items:center;gap:8px;background:var(--primary);color:#fff;fotoo weight:600;fotoo size:15px;padding:12px 20px;border-radius:10px;border:0;cursor:pointer;transition:.15s;box-shadow:0 6px 22px rgba(37,99,235,.25)}
.btn:hover{background:var(--primary-h);transform:translateY(-1px)}
.btn--sm{padding:8px 15px;fotoo size:14px}.btn--lg{padding:15px 28px;fotoo size:16px}
.btn--ghost{background:transparent;color:var(--fg);box-shadow:inset 0 0 0 1px var(--border)}
.btn--ghost:hover{background:var(--surface)}
.nav{display:flex;align-items:center;gap:22px;max-width:var(--max);margin:0 auto;padding:16px clamp(16px,5vw,40px)}
.brand{display:flex;align-items:center;gap:9px;fotoo weight:700}
.brand__dot{width:11px;height:11px;border-radius:50%;background:var(--primary);box-shadow:0 0 12px var(--primary)}
.nav__links{display:flex;gap:24px;margin-left:auto;fotoo size:14px;color:var(--muted)}
.nav__links a:hover{color:var(--fg)}.nav__toggle{display:none;margin-left:auto;background:0;border:0;fotoo size:22px;color:var(--fg);cursor:pointer}
main{max-width:var(--max);margin:0 auto;padding:0 clamp(16px,5vw,40px)}
.hero{display:grid;grid-template-columns:1.1fr .9fr;gap:clamp(28px,5vw,56px);align-items:center;padding:clamp(40px,8vw,96px) 0}
.hero h1{fotoo size:clamp(2.4rem,7vw,4rem);margin-bottom:18px}
.hero__cta{display:flex;flex-wrap:wrap;gap:14px;margin-top:26px}
.hero__art{width:100%;border-radius:var(--r);box-shadow:0 30px 70px rgba(0,0,0,.18)}
.trust{max-width:var(--max);margin:0 auto;padding:8px clamp(16px,5vw,40px) 24px;color:var(--muted);fotoo size:13px;text-align:center}
.trust__row{display:flex;justify-content:center;gap:30px;margin-top:14px;flex-wrap:wrap}
.trust__row i{width:78px;height:22px;border-radius:6px;background:var(--border)}
.section{padding:clamp(48px,9vw,104px) 0;border-top:1px solid var(--border)}
.section__head{margin-bottom:clamp(26px,5vw,44px)}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px}
.card{border:1px solid var(--border);border-radius:var(--r);padding:26px;background:var(--surface);transition:.2s}
.card:hover{transform:translateY(-4px);box-shadow:0 16px 40px rgba(0,0,0,.10)}
.ic{width:30px;height:30px;color:var(--primary);margin-bottom:14px}
.card h3{margin-bottom:8px}.card p{color:var(--muted);fotoo size:.96rem}
.section--split{display:grid;grid-template-columns:1fr 1fr;gap:clamp(28px,6vw,60px);align-items:center}
.section--split h2{margin:12px 0 14px}.section--split .btn{margin-top:20px}
.panel{width:100%;border-radius:var(--r);border:1px solid var(--border);box-shadow:0 20px 50px rgba(0,0,0,.12)}
code{fotoo family:ui-monospace,Menlo,monospace;background:var(--surface);padding:2px 6px;border-radius:6px;fotoo size:.9em}
.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;padding:clamp(40px,7vw,80px) 0;border-top:1px solid var(--border);text-align:center}
.stats b{display:block;fotoo size:clamp(1.8rem,5vw,2.8rem);background:linear-gradient(120deg,var(--primary),var(--accent));-webkit-background-clip:text;background-clip:text;color:transparent}
.stats span{color:var(--muted);fotoo size:.9rem}
.cta-band{text-align:center}.cta-band .lede{margin:14px auto 26px}
.steps{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}
.step{border:1px solid var(--border);border-radius:var(--r);padding:24px;background:#fff}
.step b{color:var(--primary);fotoo family:ui-monospace,Menlo,monospace}.step h3{margin:10px 0 6px}.step p{color:var(--muted);fotoo size:.95rem}
.quotes{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}
.quote{border:1px solid var(--border);border-radius:var(--r);padding:24px;background:var(--surface)}
.quote blockquote{fotoo size:1.05rem}.quote figcaption{margin-top:14px;color:var(--mfg);fotoo size:.9rem}
.pricing{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}
.tier{border:1px solid var(--border);border-radius:var(--r);padding:28px;background:#fff;display:flex;flex-direction:column}
.tier.feat{border-color:var(--primary);box-shadow:0 16px 44px rgba(37,99,235,.14)}
.tier .price{fotoo size:2rem;fotoo weight:700;margin:8px 0}
.tier ul{list-style:none;margin:14px 0;display:flex;flex-direction:column;gap:8px;color:var(--muted);fotoo size:.95rem}
.tier .btn{margin-top:auto}
.faq{max-width:760px}
.faq details{border-bottom:1px solid var(--border);padding:14px 0}
.faq summary{cursor:pointer;fotoo weight:600;list-style:none}.faq summary::-webkit-details-marker{display:none}
.faq p{color:var(--muted);margin-top:8px}
.footer{max-width:var(--max);margin:0 auto;padding:30px clamp(16px,5vw,40px) 48px;border-top:1px solid var(--border);display:flex;flex-wrap:wrap;gap:16px;align-items:center;color:var(--muted);fotoo size:14px}
.footer__brand{display:flex;align-items:center;gap:8px;color:var(--fg);fotoo weight:700}
.footer__links{display:flex;gap:18px;margin:0 auto}.footer__links a:hover{color:var(--fg)}
.legal{max-width:760px;margin:0 auto;padding:clamp(28px,6vw,64px) clamp(16px,5vw,40px)}
.legal h1{margin:8px 0 4px}.legal h2{fotoo size:1.2rem;margin:26px 0 8px}.legal p,.legal li{color:var(--muted)}
.legal__date{color:var(--muted);fotoo size:14px}.legal ul{margin:8px 0 8px 20px}
.legal__note{border:1px solid var(--border);background:var(--surface);border-radius:10px;padding:12px 14px;margin:14px 0;fotoo size:14px}
.reveal{opacity:1}.js .reveal{opacity:0;transform:translateY(14px);transition:opacity .6s ease,transform .6s ease}.js .reveal.in{opacity:1;transform:none}
@media (max-width:760px){.hero{grid-template-columns:1fr}.section--split{grid-template-columns:1fr}.nav__links{display:none}.nav__toggle{display:block}
 .nav__links.open{display:flex;position:absolute;left:0;right:0;top:62px;flex-direction:column;gap:0;background:var(--bg);border-bottom:1px solid var(--border);padding:8px 24px}.nav__links.open a{padding:10px 0}}
@media (prefers-reduced-motion:reduce){html{scroll-behavior:auto}.reveal{opacity:1;transform:none}}
CSS
    cat > "$SAFE/app.js" <<'JS'
// progressive enhancement: content is visible without JS; JS only adds motion
document.documentElement.classList.add("js");
document.getElementById("y").textContent = new Date().getFullYear();
// mobile nav
var tg = document.getElementById("navToggle"), menu = document.getElementById("menu");
if (tg) tg.addEventListener("click", function(){ var o = menu.classList.toggle("open"); tg.setAttribute("aria-expanded", o); });
// reveal on scroll (with a safety net so content is never left hidden)
var els = document.querySelectorAll(".reveal");
function showAll(){ els.forEach(function(el){ el.classList.add("in"); }); }
if ("IntersectionObserver" in window) {
  var io = new IntersectionObserver(function(es){ es.forEach(function(e){ if(e.isIntersecting){ e.target.classList.add("in"); io.unobserve(e.target);} }); }, {rootMargin:"0px 0px -8% 0px"});
  els.forEach(function(el){ io.observe(el); });
  setTimeout(showAll, 1500);
} else { showAll(); }
JS
    nt_docs "$SAFE"
    # — Cloudflare _headers : security + long-cache (plain stack) —
    cat > "$SAFE/_headers" <<'HDR'
/*
  X-Contetoo Type-Options: nosniff
  X-Frame-Options: SAMEORIGIN
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
  Contetoo Security-Policy: default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; script-src 'self'; base-uri 'self'; form-action 'self'
/assets/*
  Cache-Control: public, max-age=31536000, immutable
/styles.css
  Cache-Control: public, max-age=31536000, immutable
/app.js
  Cache-Control: public, max-age=31536000, immutable
HDR
    nt_meta "$SAFE"; nt_legal "$SAFE"
    ok "Created premium starter ${BOLD}$SAFE/${NC} ${DIM}(plain HTML/CSS/JS)${NC}"
    echo -e "   ${DIM}files:${NC} index.html · styles.css · app.js · assets/hero.svg · DESIGN.md · AGENTS.md · CLAUDE.md · privacy/cookie/terms · _headers · robots · sitemap · manifest · favicon · 404"
    echo -e "   ${DIM}preview:${NC} too serve $SAFE   ${DIM}·  ship:${NC} too push $SAFE $SAFE   ${DIM}·  audit:${NC} too audit $SAFE"
    [ -n "$DESIGN_BRAND" ] && { "$0" design add "$DESIGN_BRAND" "$SAFE/DESIGN.md"; rm -f "$SAFE/DESIGN.md.bak"; }
    nt_apply_palette "$SAFE"
    nt_devserve "$SAFE" plain "$SERVE"
    ;;

  create-saas|saas|saas-new)
    banner
    NAME="${1:-saas}"; SAFE=$(sanitize_branch "$NAME"); URL=$(url_for "$SAFE")
    STACK=""; SERVE=""
    for a in "${@:2}"; do case "$a" in
      --next-forge|--nextforge) STACK=nextforge;; --vite) STACK=vite;; --minimal|--static) STACK=minimal;; --serve) SERVE=yes;;
    esac; done
    if [ -z "$STACK" ]; then
      if [ -t 0 ]; then
        echo -e "${BOLD}SaaS stack for '$SAFE':${NC}"
        echo "  1) next-forge  — Next.js + shadcn monorepo (recommended)"
        echo "  2) Vite + React + TS  — lighter SPA (+ Tailwind/shadcn)"
        echo "  3) Minimal  — landing + planning docs only"
        read -p "Choose [1]: " _s; case "$_s" in 2) STACK=vite;; 3) STACK=minimal;; *) STACK=nextforge;; esac
      else STACK=nextforge; fi
    fi
    warn "🧪 SaaS scaffolder (beta): sets up the full structure + planning docs. The agent then"
    warn "   researches the market, defines the killer feature, and writes the code."

    case "$STACK" in
      nextforge)
        have npx || { err "npx required (Node)"; exit 1; }
        [ -e "$SAFE" ] && { err "'$SAFE' already exists"; exit 1; }
        info "🏗  Scaffolding next-forge (Next.js + shadcn)…"
        npx --yes next-forge@latest init "$SAFE" || { err "next-forge init failed (check Node version)"; exit 1; }
        ;;
      vite)
        have npm || { err "npm required"; exit 1; }
        [ -e "$SAFE" ] && { err "'$SAFE' already exists"; exit 1; }
        info "🏗  Scaffolding Vite + React + TypeScript…"
        npm create vite@latest "$SAFE" -- --template react-ts || { err "vite create failed"; exit 1; }
        ;;
      minimal)
        [ -e "$SAFE" ] && { err "'$SAFE' already exists"; exit 1; }
        mkdir -p "$SAFE"
        ;;
    esac
    mkdir -p "$SAFE"
    # agent guardrails + planning + legal
    nt_docs "$SAFE"; nt_saas_docs "$SAFE"; nt_legal "$SAFE"
    # Docker-first + scalability (core for every SaaS)
    cat > "$SAFE/Dockerfile" <<'DOCK'
# Multi-stage, small, production image. Stateless → scales horizontally.
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
FROM node:22-alpine AS run
WORKDIR /app
ENV NODE_ENV=production PORT=3000
COPY --from=build /app .
EXPOSE 3000
# Run as non-root; replace with your start command
USER node
CMD ["npm","start"]
DOCK
    cat > "$SAFE/docker-compose.yml" <<'DC'
services:
  app:
    build: .
    ports: ["3000:3000"]
    env_file: [.env]
    restart: unless-stopped
    # scale horizontally:  docker compose up --scale app=3
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-change-me}
    volumes: ["dbdata:/var/lib/postgresql/data"]
    restart: unless-stopped
volumes:
  dbdata:
DC
    printf 'node_modules\n.git\ndist\n.next\n.env\n*.log\n' > "$SAFE/.dockerignore"
    echo -e "   ${DIM}🐳 Docker:${NC} docker compose up --build  ${DIM}(scale: --scale app=3)${NC}"
    # business plan → PDF (best-effort, headless Chrome)
    CHROME=$(nt_chrome)
    if [ -n "$CHROME" ]; then
      TMPH=$(mktemp -u).html
      { echo "<!DOCTYPE html><html><head><meta charset=UTF-8><style>@page{margin:18mm}body{font:14px/1.6 -apple-system,system-ui,sans-serif;color:#14181f;max-width:760px;margin:auto}h1{fotoo size:30px}h2{fotoo size:18px;margin-top:22px;border-top:1px solid #e5e8ec;padding-top:14px}code{background:#f6f7f9;padding:1px 5px;border-radius:4px}</style></head><body>";
        if have python3; then python3 - "$SAFE/BUSINESS_PLAN.md" <<'PY'
import sys,html,re
for ln in open(sys.argv[1]):
    s=ln.rstrip("\n")
    if s.startswith("## "): print("<h2>"+html.escape(s[3:])+"</h2>")
    elif s.startswith("# "): print("<h1>"+html.escape(s[2:])+"</h1>")
    elif s.startswith("> "): print("<p><em>"+html.escape(s[2:])+"</em></p>")
    elif s.startswith("- "): print("<li>"+html.escape(s[2:])+"</li>")
    elif s.strip()=="": print("<br>")
    else: print("<p>"+html.escape(s)+"</p>")
PY
        else cat "$SAFE/BUSINESS_PLAN.md"; fi
        echo "</body></html>"; } > "$TMPH"
      "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --pritoo to-pdf="$SAFE/BUSINESS_PLAN.pdf" "file://$TMPH" >/dev/null 2>&1
      rm -f "$TMPH"
      [ -s "$SAFE/BUSINESS_PLAN.pdf" ] && echo -e "   ${GREEN}✓${NC} BUSINESS_PLAN.pdf generated"
    else warn "   (install Chrome/Chromium to auto-export BUSINESS_PLAN.pdf)"; fi
    echo ""; ok "SaaS '${BOLD}$SAFE${NC}' scaffolded ${DIM}($STACK)${NC}"
    echo -e "   ${DIM}docs:${NC} BUSINESS_PLAN(.md/.pdf) · COMPETITORS.md · KILLER_FEATURE.md · LAUNCH.md · SETUP.md · DESIGN/AGENTS/CLAUDE · privacy/cookie/terms"
    echo -e "   ${DIM}next:${NC} 1) research market  2) fill the plan  3) lock the killer feature  4) build  5) preview (too edit)  6) audit  7) ship"
    [ "$SERVE" = yes ] && [ "$STACK" != minimal ] && ( cd "$SAFE" && have npm && { npm install && npm run dev; } )
    exit 0
    ;;

  apply-design|design-apply|theme)
    DIR="${1:-.}"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    [ -f "$DIR/DESIGN.md" ] || { err "No DESIGN.md in '$DIR' — add one (e.g. too design add <brand>)"; exit 1; }
    info "🎨 Applying DESIGN.md colors to ${BOLD}$DIR${NC}…"
    nt_apply_palette "$DIR"
    echo -e "   ${DIM}Colors updated. Structure/components: rebuild from DESIGN.md as the brand needs.${NC}"
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
fotoo family:system-ui,sans-serif;background:#0b1020;color:#e6f0ff}
main{text-align:center;padding:2rem}h1{fotoo size:clamp(2rem,8vw,4rem)}
button{margin-top:1.5rem;padding:.8rem 1.6rem;border:0;border-radius:10px;cursor:pointer;
background:linear-gradient(120deg,#35e8ff,#8b6cff);color:#04060f;fotoo weight:700}
CSS
    echo "document.getElementById('b').onclick=()=>alert('Deploy with: too push $SAFE');" > "$SAFE/app.js"
    echo "NT_PROJECT=$PROJECT" > "$SAFE/.ntdeploy"
    ok "Created ${BOLD}$SAFE/${NC}"; echo -e "   ${DIM}too serve $SAFE   ·   too push $SAFE $SAFE${NC}"
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
    if have wrangler; then who=$(wrangler whoami 2>/dev/null | grep -i -m1 'email\|account' | sed 's/^/   /'); [ -n "$who" ] && echo -e "${DIM}$who${NC}" || echo -e "   ${YELLOW}Cloudflare: not logged in (too init)${NC}"; fi
    # auto-detect heavy images and recommend conversion
    BIG=$(find . -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -size +200k 2>/dev/null | head -6)
    if [ -n "$BIG" ]; then
      echo ""; warn "🖼  Heavy images found (>200KB) — convert to WebP for a higher PageSpeed score:"
      echo "$BIG" | while read -r f; do [ -n "$f" ] && echo -e "   ${DIM}$(human_size "$(wc -c < "$f")")  ${f#./}${NC}"; done
      echo -e "   Fix (keeps quality, rewrites HTML refs):  ${BLUE}too images .${NC}"
    fi
    SKF="$HOME/.claude/skills/nt-deploy/SKILL.md"
    [ -f "$SKF" ] && echo -e "   ${GREEN}✓${NC} Claude Code skill installed ${DIM}(~/.claude/skills/nt-deploy)${NC}" || echo -e "   ${YELLOW}▲${NC} Claude Code skill not installed — run: ${BLUE}too skill${NC}"
    ;;

  skill)
    SK="$HOME/.claude/skills/nt-deploy"; SRC="$(cd "$(dirname "$0")" && pwd)/../integrations/claude-code/skill/SKILL.md"
    if [ "$1" = status ]; then [ -f "$SK/SKILL.md" ] && ok "Claude Code skill installed: $SK/SKILL.md" || warn "Not installed — run: too skill"; exit 0; fi
    mkdir -p "$SK"
    if [ -f "$SRC" ]; then cp "$SRC" "$SK/SKILL.md"
    else curl -fsSL "$REPO_RAW/integrations/claude-code/skill/SKILL.md" -o "$SK/SKILL.md" 2>/dev/null; fi
    [ -f "$SK/SKILL.md" ] && ok "Claude Code skill installed → $SK/SKILL.md ${DIM}(restart Claude Code to load)${NC}" || err "Could not install the skill"
    ;;

  assets|brand)   # discover existing brand assets (logos, images, fonts, colors)
    DIR="${1:-.}"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    info "🎨 Brand & asset scan in ${BOLD}$DIR${NC}:"
    imgs=$(find "$DIR" -type f \( -iname '*.svg' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.gif' -o -iname '*.ico' \) ! -path '*/node_modules/*' 2>/dev/null)
    logos=$(echo "$imgs" | grep -iE 'logo|brand|mark' )
    fonts=$(find "$DIR" -type f \( -iname '*.woff' -o -iname '*.woff2' -o -iname '*.ttf' -o -iname '*.otf' \) ! -path '*/node_modules/*' 2>/dev/null)
    srcf=$(find "$DIR" -type f \( -iname '*.ai' -o -iname '*.eps' -o -iname '*.psd' -o -iname '*.sketch' -o -iname '*.fig' \) 2>/dev/null)
    echo -e "   ${BOLD}Logos / brand marks:${NC}"; [ -n "$logos" ] && echo "$logos" | sed 's#^#     #' || echo -e "     ${DIM}none found — ask the client for a logo${NC}"
    echo -e "   ${BOLD}Images:${NC} $(echo "$imgs" | grep -c . | tr -d ' ') file(s)"
    raster=$(echo "$imgs" | grep -iE '\.(png|jpe?g|gif)$')
    [ -n "$raster" ] && echo -e "     ${YELLOW}↳ raster images present — convert to WebP: too images $DIR${NC}"
    echo -e "   ${BOLD}Fonts:${NC}"; [ -n "$fonts" ] && echo "$fonts" | sed 's#^#     #' || echo -e "     ${DIM}none (system fonts)${NC}"
    [ -n "$srcf" ] && { echo -e "   ${BOLD}Brand source files:${NC}"; echo "$srcf" | sed 's#^#     #'; }
    cols=$(grep -rhoiE '#[0-9a-f]{6}' "$DIR" --include='*.css' --include='*.svg' 2>/dev/null | tr 'A-F' 'a-f' | sort | uniq -c | sort -rn | head -6)
    [ -n "$cols" ] && { echo -e "   ${BOLD}Most-used colors:${NC}"; echo "$cols" | sed 's#^#     #'; }
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
    warn "🧪 BETA — full handoff card (HTML + PDF) with desktop & mobile screenshots."
    A="${1:-main}"; case "$A" in http*) URL="$A"; NAME="site";; *) NAME="$(sanitize_branch "$A")"; URL=$(url_for "$NAME");; esac
    TITLE="${2:-$NAME}"; OUT="${NT_CARD_OUT:-too card-$NAME}"; HTML="$OUT.html"; PDF="$OUT.pdf"
    CHROME=$(nt_chrome); DATE="$(date '+%Y-%m-%d')"
    DESK="<div class=\"ph\">$TITLE</div>"; MOB=""
    if [ -n "$CHROME" ]; then
      info "📸 Capturing desktop (1440) + mobile (390)…"
      D="$(mktemp -u).png"; M="$(mktemp -u).png"
      "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1440,2200 --screenshot="$D" "$URL" >/dev/null 2>&1
      "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size=390,2200 --screenshot="$M" "$URL" >/dev/null 2>&1
      [ -s "$D" ] && have base64 && DESK="<img class=\"shot\" alt=\"desktop preview\" src=\"data:image/png;base64,$(base64 < "$D" | tr -d '\n')\">"
      [ -s "$M" ] && have base64 && MOB="<img class=\"mob\" alt=\"mobile preview\" src=\"data:image/png;base64,$(base64 < "$M" | tr -d '\n')\">"
      rm -f "$D" "$M"
    fi
    QR=""; have qrencode && QR=$(qrencode -o - -t SVG -m 1 "$URL" 2>/dev/null)
    cat > "$HTML" <<HTML
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>$TITLE — handoff</title>
<style>@page{size:A4;margin:14mm}*{margin:0;box-sizing:border-box;fotoo family:-apple-system,Segoe UI,Roboto,system-ui,sans-serif}
body{color:#14181f;max-width:820px;margin:auto}
.hero{padding:40px 44px;border-radius:18px;background:linear-gradient(135deg,#0b1020,#1a1740);color:#fff;margin-bottom:26px}
.hero .tag{fotoo size:12px;letter-spacing:.24em;color:#7fdcff;text-transform:uppercase}
.hero h1{fotoo size:40px;margin:10px 0 6px;line-height:1.05}.hero a{color:#c7b9ff;fotoo size:15px;text-decoration:none}
.hero .meta{margin-top:14px;fotoo size:13px;color:#aeb8d6}
h2{fotoo size:14px;letter-spacing:.12em;text-transform:uppercase;color:#5b6573;margin:26px 0 12px}
.shot{width:100%;border:1px solid #e4e4e7;border-radius:12px;box-shadow:0 14px 40px rgba(0,0,0,.12)}
.ph{height:300px;display:grid;place-items:center;border-radius:12px;background:linear-gradient(135deg,#35e8ff,#8b6cff);color:#04060f;fotoo size:34px;fotoo weight:800}
.split{display:flex;gap:24px;align-items:flex-start}
.mobcol{flex:0 0 260px}.mob{width:260px;border:1px solid #e4e4e7;border-radius:22px;box-shadow:0 14px 40px rgba(0,0,0,.12)}
.info{flex:1}.info dl{display:grid;grid-template-columns:120px 1fr;gap:8px 12px;fotoo size:14px}
.info dt{color:#5b6573}.info dd{color:#14181f;word-break:break-all}
.qr{width:120px;height:120px;margin-top:14px}
.notes{border:1px solid #e4e4e7;border-radius:12px;padding:18px 20px;background:#f6f7f9;fotoo size:14px;color:#3a4452}
.brand{margin-top:26px;fotoo size:12px;color:#a1a1aa;text-align:center}</style></head>
<body>
<div class="hero"><div class="tag">Project handoff</div><h1>$TITLE</h1>
<a href="$URL">$URL</a><div class="meta">Prepared $DATE · live preview below (desktop &amp; mobile)</div></div>

<h2>Desktop</h2>$DESK
<h2>Mobile &amp; details</h2>
<div class="split">
  <div class="mobcol">${MOB:-<div class=ph style=height:420px>$TITLE</div>}</div>
  <div class="info">
    <dl>
      <dt>Live URL</dt><dd><a href="$URL">$URL</a></dd>
      <dt>Prepared</dt><dd>$DATE</dd>
      <dt>Status</dt><dd>Preview — pending review</dd>
      <dt>Scan on phone</dt><dd></dd>
    </dl>
    <div class="qr">$QR</div>
  </div>
</div>

<h2>Notes for the team</h2>
<div class="notes">
  <p><strong>Stack &amp; structure:</strong> [fill: HTML/CSS/JS or Vite/Next, key folders].</p>
  <p><strong>Design system:</strong> see <code>DESIGN.md</code> in the repo for tokens, type, components.</p>
  <p><strong>Deploy:</strong> <code>too push &lt;dir&gt; &lt;client&gt;</code> (Cloudflare) · also Vercel/AWS.</p>
  <p><strong>To do before launch:</strong> [replace placeholders, add real copy/images, run <code>too test</code>].</p>
</div>
<div class="brand">prepared with <strong>TooFast</strong></div>
</body></html>
HTML
    ok "Created ${BOLD}$HTML${NC}"
    if [ -n "$CHROME" ]; then
      ABS="file://$(cd "$(dirname "$HTML")"&&pwd)/$(basename "$HTML")"
      "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --pritoo to-pdf="$PDF" "$ABS" >/dev/null 2>&1
      [ -s "$PDF" ] && ok "Created ${BOLD}$PDF${NC} — one file for the client/team ($(human_size "$(wc -c < "$PDF")"))"
    else warn "Install Chrome/Chromium to export a PDF and screenshots. For now open $HTML and print to PDF."; fi
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
    else warn "💡 Tip: open it at nt.local with  ${BLUE}too gui dns${NC}${YELLOW} (one-time setup)"; fi
    URL="http://$HOST:$PORT"
    info "🪟 GUI → ${BOLD}$URL${NC}${BLUE}  (Ctrl-C to stop)${NC}"
    have open && (sleep 1; open "$URL") &
    NT_PROJECT="$PROJECT" NT_SCRIPT="$(cd "$(dirname "$0")"&&pwd)/$(basename "$0")" python3 "$GUI" "$PORT"
    ;;

  # ───── LIVE EDITOR (dev server + in-browser text editor) ─────
  edit)
    DIR="${1:-.}"; PORT="${2:-8080}"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    E="$CONFIG_DIR/nt-edit.py"; [ -f "$E" ] || E="$(dirname "$0")/nt-edit.py"
    [ -f "$E" ] || { err "nt-edit.py not found"; exit 1; }
    have python3 || { err "python3 required"; exit 1; }
    HOST=localhost
    grep -qE "^[^#]*[[:space:]]nt\.local([[:space:]]|$)" /etc/hosts 2>/dev/null && HOST=nt.local
    URL="http://$HOST:$PORT"
    info "✎ Live editor → ${BOLD}$URL${NC}${BLUE}  (edit files in the browser · auto-reload on save · Ctrl-C to stop)${NC}"
    have open && (sleep 1; open "$URL") &
    python3 "$E" "$DIR" "$PORT"
    ;;

  # ───── QA / PRE-PRODUCTION TEST ─────
  test|qa|preflight)
    A="${1:-.}"; info "🧪 Pre-production check"
    pass=0; warnc=0
    P(){ echo -e "   ${GREEN}✓${NC} $1"; pass=$((pass+1)); }
    W(){ echo -e "   ${YELLOW}▲${NC} $1"; warnc=$((warnc+1)); }
    case "$A" in
      http*)
        have curl || { err "curl required"; exit 1; }
        info "→ URL: $A"
        H=$(curl -sSIL --max-time 20 "$A" 2>/dev/null)
        echo -e "   ${DIM}$(printf '%s' "$H" | grep -i '^HTTP' | tail -1)${NC}"
        [[ "$A" == https://* ]] && P "HTTPS" || W "not served over HTTPS"
        for hd in "contetoo security-policy:Contetoo Security-Policy" "x-contetoo type-options:X-Contetoo Type-Options" "strict-transport-security:HSTS" "x-frame-options:X-Frame-Options" "referrer-policy:Referrer-Policy"; do
          k="${hd%%:*}"; lbl="${hd##*:}"
          printf '%s' "$H" | grep -qi "^$k:" && P "$lbl" || W "missing security header: $lbl"
        done
        t=$(curl -so /dev/null -w '%{time_total}' --max-time 20 "$A" 2>/dev/null); echo -e "   ${DIM}response time: ${t}s${NC}"
        ;;
      *)
        DIR="$A"; [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
        info "→ folder: $DIR"
        [ -f "$DIR/index.html" ] && P "index.html present" || W "no index.html"
        [ -f "$DIR/_headers" ] && P "_headers (security/cache)" || W "no _headers (security headers)"
        [ -f "$DIR/robots.txt" ] && P "robots.txt" || W "no robots.txt"
        [ -f "$DIR/sitemap.xml" ] && P "sitemap.xml" || W "no sitemap.xml"
        ls "$DIR"/404.html &>/dev/null && P "404 page" || W "no 404.html"
        grep -rilq 'name="description"' "$DIR" --include='*.html' 2>/dev/null && P "meta description" || W "missing meta description"
        noalt=$(grep -roE '<img [^>]*>' "$DIR" --include='*.html' 2>/dev/null | grep -vci 'alt=')
        [ "${noalt:-0}" = 0 ] && P "all <img> have alt" || W "$noalt <img> without alt text"
        mc=$(grep -rlE "(src|href)=[\"']http://" "$DIR" --include='*.html' --include='*.css' 2>/dev/null | grep -c .)
        [ "${mc:-0}" = 0 ] && P "no http:// (mixed content) refs" || W "$mc file(s) with insecure http:// refs"
        big=$(find "$DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -size +200k 2>/dev/null | grep -c .)
        [ "${big:-0}" = 0 ] && P "no heavy raster images" || W "$big heavy image(s) — run too images"
        find "$DIR" -name '.env*' ! -name '.env.example' -not -path '*/node_modules/*' 2>/dev/null | grep -q . && W ".env present — keep secrets out of the deploy folder" || P "no .env in folder"
        ph=$(grep -rlE 'picsum\.photos|\[placeholder\]|hello@example\.com|Placeholder — replace|TEMPLATE — not legal' "$DIR" --include='*.html' 2>/dev/null | grep -c .)
        [ "${ph:-0}" = 0 ] && P "no leftover placeholders" || W "$ph file(s) with placeholders/templates to finish"
        ;;
    esac
    echo ""; echo -e "   ${BOLD}$pass passed${NC} · ${YELLOW}$warnc to review${NC}"
    [ "$warnc" = 0 ] && ok "Looks production-ready." || warn "Review the ▲ items before going live."
    ;;

  # ───── MULTI-PROVIDER DEPLOY (Cloudflare stays the default via too push) ─────
  vercel)
    have npx || { err "npx required (Node)"; exit 1; }
    DIR="${1:-.}"; PROD=""
    for a in "$@"; do [ "$a" = "--prod" ] && PROD="--prod"; done
    [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    info "▲ Deploying to Vercel${PROD:+ (production)}… (first run asks you to log in)"
    npx --yes vercel deploy "$DIR" $PROD
    ;;
  aws|s3)
    have aws || { err "AWS CLI required — brew install awscli (then 'aws configure')"; exit 1; }
    DIR="${1:-.}"; BUCKET="${2:-$AWS_BUCKET}"
    [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    [ -z "$BUCKET" ] && { err "Usage: too aws <dir> <s3-bucket>  (or set AWS_BUCKET)"; exit 1; }
    info "☁  Syncing ${BOLD}$DIR${NC}${BLUE} → s3://$BUCKET …${NC}"
    aws s3 sync "$DIR" "s3://$BUCKET" --delete || { err "s3 sync failed"; exit 1; }
    if [ -n "$AWS_CF_DISTRIBUTION" ]; then
      aws cloudfront create-invalidation --distribution-id "$AWS_CF_DISTRIBUTION" --paths '/*' >/dev/null 2>&1 && ok "CloudFront cache invalidated"
    fi
    ok "Synced to s3://$BUCKET${AWS_S3_URL:+ ($AWS_S3_URL)}"
    ;;

  # ───── EXPORT TO WORDPRESS (installable theme) ─────
  wordpress|wp)
    DIR="${1:-.}"; THEME=$(sanitize_branch "${2:-$(basename "$(cd "$DIR" 2>/dev/null && pwd)")}")
    [ -d "$DIR" ] || { err "Folder '$DIR' not found"; exit 1; }
    [ -f "$DIR/index.html" ] || { err "No index.html in '$DIR'"; exit 1; }
    have zip || { err "'zip' required"; exit 1; }; have python3 || { err "python3 required"; exit 1; }
    WORK=$(mktemp -d); TD="$WORK/$THEME"; mkdir -p "$TD"
    cp -R "$DIR"/. "$TD"/ 2>/dev/null; rm -f "$TD"/index.html
    python3 - "$DIR/index.html" "$TD/index.php" <<'PY'
import sys, re
src = open(sys.argv[1], encoding="utf-8").read()
u = "<?php echo get_template_directory_uri(); ?>"
# drop the static css/js tags (functions.php enqueues them)
src = re.sub(r'\s*<link rel="stylesheet"[^>]*>', '', src)
src = re.sub(r'\s*<script src="/app\.js"[^>]*></script>', '', src)
# rewrite remaining root-absolute asset URLs to the theme dir
src = re.sub(r'(href|src)="/(?!/)', lambda m: m.group(1) + '="' + u + '/', src)
src = src.replace('</head>', '<?php wp_head(); ?>\n</head>', 1)
src = src.replace('</body>', '<?php wp_footer(); ?>\n</body>', 1)
open(sys.argv[2], "w", encoding="utf-8").write(src)
PY
    cat > "$TD/style.css" <<CSS
/*
Theme Name: $THEME
Author: TooFast
Version: 1.0
Description: Static site exported to a WordPress theme by TooFast.
*/
CSS
    cat > "$TD/functions.php" <<'PHP'
<?php
add_action('wp_enqueue_scripts', function () {
  $u = get_template_directory_uri();
  wp_enqueue_style('toofast-site', $u . '/styles.css', [], '1.0');
  wp_enqueue_script('toofast-site', $u . '/app.js', [], '1.0', true);
});
PHP
    ( cd "$WORK" && zip -rq "$OLDPWD/$THEME-wp-theme.zip" "$THEME" -x '*.DS_Store' )
    rm -rf "$WORK"
    ok "Created ${BOLD}$THEME-wp-theme.zip${NC} ($(human_size "$(wc -c < "$THEME-wp-theme.zip")"))"
    echo -e "   ${DIM}WordPress → Appearance → Themes → Add New → Upload Theme → Activate.${NC}"
    ;;

  # ───── SETUP ─────
  init)
    check_wrangler; banner
    if [ -n "${NT_PROJECT:-}" ]; then info "📦 Project: ${GREEN}$PROJECT${NC} ${DIM}[$NT_SOURCE]${NC}"; read -p "Change it? [y/N] " CH; [[ "$CH" =~ ^[sSyY]$ ]] || SKIP=1; fi
    if [ -z "${SKIP:-}" ]; then echo ""; echo "Cloudflare Pages project name:"; echo -e "  • base:   ${YELLOW}<name>.pages.dev${NC}"; echo -e "  • client: ${YELLOW}client.<name>.pages.dev${NC}"; echo ""
      read -p "Name [anteprima]: " UP; UP=$(sanitize_branch "${UP:-anteprima}"); mkdir -p "$CONFIG_DIR"; echo "NT_PROJECT=$UP" > "$CONFIG_FILE"; PROJECT="$UP"; ok "Saved to $CONFIG_FILE"; echo ""; fi
    info "🔧 Cloudflare login…"; wrangler login
    info "🔧 Creating project '$PROJECT'…"; wrangler pages project create "$PROJECT" --production-branch=main 2>/dev/null || warn "ℹ️  '$PROJECT' already exists, reusing it"
    echo ""; ok "Ready!"; echo -e "   ${BLUE}too push ./dist${NC} → https://$PROJECT.pages.dev"; echo -e "   ${BLUE}too ship${NC}        → build + deploy + QR + open"
    check_for_updates
    ;;
  config)
    info "⚙️  Configuration:"; echo "  Project:     $PROJECT  [$NT_SOURCE]"; echo "  Base URL:    https://$PROJECT.pages.dev"
    echo "  Snapshots:   $SNAP_ROOT/$PROJECT  (keep last $SNAP_KEEP)"; echo "  Auto-update: ${NT_AUTO_UPDATE:-0}"
    echo -e "  ${DIM}Global: too init  ·  per-repo: a .ntdeploy file with NT_PROJECT=name${NC}"
    ;;
  version|--version|-v) echo "toofast v$VERSION ${DIM}(formerly nt-deploy)${NC}" ;;
  update) self_update ;;

  help|--help|-h|"")
    banner
    cat <<EOF
${BOLD}DEPLOY${NC}
  too push [dir] [client]     Deploy a folder (default ./dist → production)
  too push --build [client]   Build (npm/pnpm/yarn/bun) + deploy automatically
  too push … --dry-run / -y   Simulate / skip production confirmation
  too ship [client]           ${MAGENTA}★${NC} build + deploy + QR + open, all in one
  too bp [client]             Shortcut for 'too push --build'
  too vercel [dir] [--prod]   Deploy to Vercel  ·  too aws <dir> <bucket>  Deploy to AWS S3/CloudFront
  too wordpress <dir> [name]  Export a static site as an installable WordPress theme (.zip)

${BOLD}TIME MACHINE${NC} ${MAGENTA}(kill feature)${NC}
  too rollback [client] [ts]  Restore a previous deploy (impossible with wrangler alone!)
  too snapshots [client]      List local snapshots

${BOLD}MANAGE${NC}
  too list / too clients / too projects   Deployments, clients, projects
  too rm <client> [-y]        Delete a client's deployments (asks to confirm)
  too rmproject <name>        Delete a whole project (retype name to confirm)
  too logs [client]           Live log tail
  too open / too copy [client]  Open / copy the URL

${BOLD}QUALITY & TRAFFIC${NC}
  too audit [url|client] [mobile|desktop]   PageSpeed pre-test with score (Google engine)
  too test [dir|url]                        QA / pre-production check (headers, alts, mixed content, placeholders)
  too analytics inject <dir> <token>        Enable visit tracking (Web Analytics)
  too analytics open | too stats             Open dashboard / show visits

${BOLD}TOOLKIT${NC} ${DIM}(works without Cloudflare too)${NC}
  too serve [dir] [port]      Local static server
  too edit [dir] [port]       Live dev server + in-browser text editor (auto-reload on save)
  too create [client]         Premium scaffold (DESIGN.md, AGENTS.md, _headers, manifest…) tuned for top PageSpeed
  too create-saas [name]      Full SaaS scaffold (next-forge / Vite) + business plan PDF + killer feature
  too design list|add <brand> Fetch a brand DESIGN.md from the community library (Stripe, Linear, Notion…)
  too apply-design [dir]     Re-color a site from its DESIGN.md (run after you swap DESIGN.md)
  too new [name]              Minimal starter site, ready to deploy
  too build                   Run the build and show its size
  too size [dir]              Output weight report + top files
  too zip [dir] [out.zip]     Package a folder
  too images [dir] [quality]  Convert PNG/JPEG/GIF → WebP and rewrite references in HTML/CSS/JS
  too check [url|client]      Health-check: HTTP status, time, size
  too qr [url|client]         QR code in the terminal
  too clean                   Remove dist/build/cache
  too doctor                  Environment diagnostics
  too assets [dir]            Scan for existing brand assets (logos, images, fonts, colors)
  too notes <client> ["…"]    Per-client notes (view/add)
  too card [url|client]       ${MAGENTA}🧪 beta${NC} — a shareable one-pager (HTML + PDF) to send a client
  too gui [port]              Lightweight browser GUI

${BOLD}SETUP${NC}
  too init · too config · too update · too version

${DIM}Tip: 'nt <command>' (e.g. nt ship) · project: -p <name> · auto-update: NT_AUTO_UPDATE=1${NC}
EOF
    ;;
  *) err "Unknown command: $ACTION"; echo "Run 'too help' for the list"; exit 1 ;;
esac
