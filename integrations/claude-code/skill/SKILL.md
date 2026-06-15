---
name: nt-deploy
description: Use to scaffold, preview, audit, deploy and roll back static websites with the nt-deploy CLI. Trigger when the user wants to create a new client/site base (nt-create), deploy to Cloudflare Pages (nt-push/nt-ship), roll back a deploy (nt-rollback), run a PageSpeed audit (nt-audit), convert images to WebP (nt-images), pull a brand DESIGN.md (nt-design), or open the GUI (nt-gui). Also triggers on "create a site for client X", "deploy this", "publish to Cloudflare", "rollback", "lighthouse/pagespeed score".
---

# nt-deploy

CLI installed at `~/.nt-tools/nt-deploy.sh` (aliases `nt-*` and `nt <command>`). Cloudflare Pages + dev toolkit.

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
seed the design from it (or pull a close one with `nt-design add <brand>`). Otherwise ask the
questions in the "Agent Prompt Guide" before generating any UI. **If the user can't or doesn't want to
answer** (e.g. "propose it yourself", "give me a base"), don't stall: offer a base to draw
from — either propose sensible defaults and write them into `DESIGN.md`, or fetch a ready
brand template with `nt-design add <brand>` (e.g. stripe, linear, notion). Always fill
`DESIGN.md` first, then build against it; never invent values silently.

Scaffold flags: `--plain` / `--vite`, `--serve` / `--no-serve`, `--design=<brand>` (start the
DESIGN.md from a brand template, e.g. `--design=stripe`).

## Workflow: build a client site (follow this)
1. **Understand the client.** Ask: what does the business do / industry? Audience and goal
   (leads, sales, bookings, info)? **Do they already have a website?** (get the URL). Brand
   assets (logo, colors, fonts, tone)? Which pages and languages? Reference sites they like?
2. **If they already have a site**, inspect it: `nt-check <url>` and `nt-audit <url>` to learn
   its structure/quality and what to improve.
3. **Design.** Fill `DESIGN.md` from their brand, or seed from a template (`nt-design add <brand>`),
   or keep the rich defaults — confirm the direction with the user; if they can't answer, propose
   sensible defaults, don't stall.
4. **Scaffold.** `nt-create <client>` (ask HTML/CSS/JS vs Vite; offer a live-reload dev server;
   `--design=<brand>` to seed the DESIGN.md).
5. **Build** strictly against `DESIGN.md`: accessible, standards-based, PageSpeed-first. Keep the
   output portable (plain HTML/CSS/JS or Vite) so it works with any tool.
6. **Images.** Check the project for raster images (PNG/JPEG). If any, run `nt-images <dir>` to
   convert them to WebP (keeps quality, rewrites references). `nt-doctor` also flags heavy images.
7. **Preview & iterate** with `nt-edit <dir>`: live reload (CSS hot-swaps with no full refresh),
   in-browser editor, and click-to-source (🎯) to jump from any element to its line.
8. **Audit.** `nt-audit <dir|client>` — aim for ≥ 95 on mobile; fix issues.
9. **When you judge it's ready, ASK the user whether to publish it to Cloudflare so the client can
   preview it.** If yes: `nt-push <dir> <client>` → the live URL becomes
   `<client>.<project>.pages.dev` (e.g. `tynk.nicolatomassini.pages.dev`). Share it, or
   `nt-card <client>` (one-pager) / `nt-qr <client>` (QR).

## All commands
**Deploy** — `nt-push <dir> <client>` · `nt-ship <client>` (build+deploy+QR+open) · `nt-bp <client>` (build+push)
**Time Machine** — `nt-rollback <client> [ts]` · `nt-snapshots <client>`
**Manage** — `nt-list` · `nt-clients` · `nt-projects` · `nt-rm <client>` · `nt-rmproject <name>` · `nt-logs <client>` · `nt-open <client>` · `nt-copy <client>`
**Quality & traffic** — `nt-audit <url|client> [mobile|desktop]` · `nt-analytics inject|open` · `nt-stats`
**Scaffold** — `nt-create <client> [--plain|--vite] [--serve] [--design=<brand>]` · `nt-design list|add <brand>` · `nt-new <name>` · `nt-card <url|client>` (beta)
**Dev server** — `nt-serve <dir> [port]` (auto-opens browser) · `nt-edit <dir> [port]` (live reload + in-browser editor + draggable widget)
**Toolkit** — `nt-build` · `nt-size <dir>` · `nt-zip <dir>` · `nt-images <dir>` · `nt-check <url|client>` · `nt-qr <url|client>` · `nt-clean` · `nt-doctor` · `nt-notes <client> ["…"]` · `nt-gui [port]`
**Setup** — `nt-init` · `nt-config` · `nt-update` · `nt-version`
**Global** — append `-p <project>` to target any project · `NT_AUTO_UPDATE=1` for silent updates · full help: `nt-help`

## Notes
- Deploy/rollback are non-interactive with `-y`; production overwrite asks to confirm.
- Needs `wrangler` (Cloudflare). `nt-init` logs in and creates the project.
