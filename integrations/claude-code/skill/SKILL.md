---
name: nt-deploy
description: Use to scaffold, preview, audit, deploy and roll back static websites with the nt-deploy CLI. Trigger when the user wants to create a new client/site base (too create), deploy to Cloudflare Pages (too push/too ship), roll back a deploy (too rollback), run a PageSpeed audit (too audit), convert images to WebP (too images), pull a brand DESIGN.md (too design), or open the GUI (too gui). Also triggers on "create a site for client X", "deploy this", "publish to Cloudflare", "rollback", "lighthouse/pagespeed score".
---

# nt-deploy

CLI installed at `~/.nt-tools/nt-deploy.sh` (aliases `too *` and `nt <command>`). Cloudflare Pages + dev toolkit.

## Scaffold a client site (most common)
Non-interactive (use flags so it doesn't prompt):
```bash
~/.nt-tools/nt-deploy.sh create <client> --plain --no-serve   # HTML/CSS/JS base
~/.nt-tools/nt-deploy.sh create <client> --vite  --no-serve   # Vite + HMR
```
Folder name = sanitized client name. Generates: index.html, styles.css, app.js,
DESIGN.md (9-section spec — empty, ask the user to fill it), AGENTS.md, CLAUDE.md,
_headers, robots.txt, sitemap.xml, site.webmanifest, favicon.svg, 404.html.

Before/after scaffolding, also **ask the user whether to start a live-reload dev server**.
If yes: `~/.nt-tools/nt-deploy.sh serve <dir>` (plain) or `cd <dir> && npm install && npm run dev`
(Vite). You can also pass `--serve` to `create` to start it automatically.

After scaffolding, read the new `DESIGN.md`. **First ask whether the user already has an
example `DESIGN.md`** (or a reference site / brand kit) to draw inspiration from — if so,
seed the design from it (or pull a close one with `too design add <brand>`). Otherwise ask the
questions in the "Agent Prompt Guide" before generating any UI. **If the user can't or doesn't want to
answer** (e.g. "propose it yourself", "give me a base"), don't stall: offer a base to draw
from — either propose sensible defaults and write them into `DESIGN.md`, or fetch a ready
brand template with `too design add <brand>` (e.g. stripe, linear, notion). Always fill
`DESIGN.md` first, then build against it; never invent values silently.

Scaffold flags: `--plain` / `--vite`, `--serve` / `--no-serve`, `--design=<brand>` (start the
DESIGN.md from a brand template, e.g. `--design=stripe`).

## Workflow: build a client site (follow this)
1. **Understand the client.** Ask: what does the business do / industry? Audience and goal
   (leads, sales, bookings, info)? **Do they already have a website?** (get the URL). Brand
   assets (logo, colors, fonts, tone)? Which pages and languages? Reference sites they like?
   Also run `too assets .` to discover logos, images, fonts and colors already in the project and
   **reuse what exists** — never invent assets when real ones are available.
2. **If they already have a site**, inspect it: `too check <url>` and `too audit <url>` to learn
   its structure/quality and what to improve.
3. **Design.** Fill `DESIGN.md` from their brand, or seed from a template (`too design add <brand>`),
   or keep the rich defaults — confirm the direction with the user; if they can't answer, propose
   sensible defaults, don't stall.
4. **Scaffold.** `too create <client>` (ask HTML/CSS/JS vs Vite; offer a live-reload dev server;
   `--design=<brand>` to seed the DESIGN.md).
5. **Build** strictly against `DESIGN.md`: accessible, standards-based, PageSpeed-first. Keep the
   output portable (plain HTML/CSS/JS or Vite) so it works with any tool.
6. **Images.** A real site needs at least some imagery — use the client's assets (from `too assets`)
   or the scaffold's SVGs. **Judge whether raster images need optimizing: if PNG/JPEG are present,
   run `too images <dir>` automatically** to convert to WebP (keeps quality, rewrites references).
   `too doctor` also flags heavy images. Always set `width`/`height` on `<img>`.
7. **Preview & iterate** with `too edit <dir>`: live reload (CSS hot-swaps with no full refresh),
   in-browser editor, and click-to-source (🎯) to jump from any element to its line.
8. **Audit.** `too audit <dir|client>` — aim for ≥ 95 on mobile; fix issues.
9. **When you judge it's ready, ASK the user whether to publish it to Cloudflare so the client can
   preview it.** If yes: `too push <dir> <client>` → the live URL becomes
   `<client>.<project>.pages.dev` (e.g. `tynk.nicolatomassini.pages.dev`). Share it, or
   `too card <client>` (one-pager) / `too qr <client>` (QR).

## Hero style & layout (decide with the user)
Pick the hero/layout that fits the business — ask if unsure, then confirm:
- **Full-bleed image hero** (image covers the area, text + CTA overlaid, dark scrim for contrast) — emotion/brand: hospitality, fashion, security, real estate.
- **Video hero** (muted, autoplay+loop, lightweight `poster`, lazy, pause on `prefers-reduced-motion`) — motion/atmosphere/product.
- **Split hero** (text + visual side-by-side) — clarity: SaaS, B2B.
- **Type-led minimal hero** — editorial, agencies, dev tools.
Match style to audience and goal, never to fashion.

## Eye-flow & conversion psychology (rules)
- One job per page; **one primary CTA**, repeated — key message + CTA **above the fold**.
- Lead the eye along the natural path (**F/Z pattern**): use size, contrast, whitespace and direction (faces/arrows point toward the CTA).
- Hierarchy: outcome headline → subhead → proof → CTA. **Outcome-first, not feature-first.**
- **Trust early**: logos, reviews, numbers near the hero; reduce risk ("no card needed", guarantees).
- Cognitive ease: short lines, ~5th–7th grade reading level, scannable bento/sections, generous spacing.
- Persuasion used **honestly**: social proof, authority, reciprocity (free value), commitment (small first step); scarcity/urgency only if true.
- **Speed converts**: every second of load loses conversions — WebP, no render-blocking fonts, defer JS.
- Accessibility = more customers: contrast ≥ 4.5:1, visible focus, captions/poster on video.

## Make each site unique (don't ship the default template)
- `too create` is a STARTING scaffold, not the final site. Reason like a senior UI/UX designer and
  rebuild it for THIS brand: colors, type, hero style, sections, copy and imagery.
- **Colors come from DESIGN.md** — run `too apply-design <dir>` (or `--design=<brand>` at create) so
  the palette matches the brand; theme follows the brand's BACKGROUND (light unless the bg is dark).
- **If the client already has a website**, inspect it first (`too check`/`too audit` + look at it) and
  carry over real brand colors, logo, tone and structure.
- **Animations**: purposeful and subtle — staggered reveal on scroll, gentle hover/press states,
  smooth focus; 120–220ms, eased; honor `prefers-reduced-motion`. Never decorative noise.
- Vary structure to fit the business — section order, hero type, density — so no two sites look the same.

## SaaS rule (`too create-saas`)
When building a SaaS, treat these as the PRIMARY points and call them out:
- **Docker-first & scalability**: a stateless container (Dockerfile + docker-compose are generated); scale horizontally (`--scale app=N` → k8s/Fly/ECS); multi-tenant by default; rate limits + billing alerts; observability.
- **One killer feature** rivals don't have (see `KILLER_FEATURE.md`) — 10x, defensible, demoable.
- Study the idea + market first (`BUSINESS_PLAN.md`, `COMPETITORS.md`), then build the code.

## All commands
**Deploy** — `too push <dir> <client>` · `too ship <client>` (build+deploy+QR+open) · `too bp <client>` (build+push)
**Time Machine** — `too rollback <client> [ts]` · `too snapshots <client>`
**Manage** — `too list` · `too clients` · `too projects` · `too rm <client>` · `too rmproject <name>` · `too logs <client>` · `too open <client>` · `too copy <client>`
**Quality & traffic** — `too audit <url|client> [mobile|desktop]` · `too analytics inject|open` · `too stats`
**Scaffold** — `too create <client> [--plain|--vite] [--serve] [--design=<brand>]` · `too design list|add <brand>` · `too new <name>` · `too card <url|client>` (beta)
**Dev server** — `too serve <dir> [port]` (auto-opens browser) · `too edit <dir> [port]` (live reload + in-browser editor + draggable widget)
**Toolkit** — `too build` · `too size <dir>` · `too zip <dir>` · `too images <dir>` · `too check <url|client>` · `too qr <url|client>` · `too clean` · `too doctor` · `too notes <client> ["…"]` · `too gui [port]`
**Setup** — `too init` · `too config` · `too update` · `too version`
**Global** — append `-p <project>` to target any project · `NT_AUTO_UPDATE=1` for silent updates · full help: `too help`

## Notes
- Deploy/rollback are non-interactive with `-y`; production overwrite asks to confirm.
- Needs `wrangler` (Cloudflare). `too init` logs in and creates the project.
