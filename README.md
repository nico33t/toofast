<div align="center">

# ⚡ nt-deploy

### Ship your site in **one command** — and a lot more.

Deploy to Cloudflare Pages, **instant rollback**, real PageSpeed audits, a featherweight GUI,
and a complete developer toolkit. All from your terminal. Zero dependencies beyond `wrangler`.

[![version](https://img.shields.io/badge/version-2.0.0-6d4aff)](https://github.com/nico33t/nt-deploy)
[![shell](https://img.shields.io/badge/bash-5%2B-1f8a55)](#)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

**English** · [Italiano](README.it.md) · [Español](README.es.md) · [Deutsch](README.de.md)

</div>

---

```bash
curl -fsSL https://raw.githubusercontent.com/nico33t/nt-deploy/main/install.sh | bash
```

```bash
nt-init            # log in to Cloudflare + create a project
nt-ship client     # build + deploy + QR + open, all in one
nt-rollback client # ⏪ instantly restore the previous deploy
```

## Why nt-deploy

`wrangler` deploys. nt-deploy gives you the **whole workflow** around it: client branches,
build pipelines, quality audits, traffic, a GUI, and the one thing wrangler can't do —
**rollback**.

## ★ Kill feature — Time Machine

Cloudflare has **no CLI rollback** for Pages. nt-deploy archives every deploy locally,
so you can restore any previous version in seconds.

```bash
nt-snapshots client          # see the deploy history
nt-rollback  client          # back to the previous version
nt-rollback  client 17000000 # roll back to an exact snapshot
```

## Features

| | |
|---|---|
| 🚀 **Deploy** | `nt-push [dir] [client]` · static folder or auto build (`--build`, detects npm/pnpm/yarn/bun) |
| ⏪ **Time Machine** | local snapshots + true `nt-rollback` |
| 🔬 **PageSpeed audit** | `nt-audit` — real score via Google Lighthouse engine (same as pagespeed.web.dev) |
| 🪟 **GUI** | `nt-gui` — light browser console (shadcn-style), manage clients/projects/settings, served at `nt.local` |
| 📊 **Traffic** | `nt-analytics inject` to enable Web Analytics, `nt-stats` to read visits |
| 🧰 **Toolkit** | `nt-serve`, `nt-new`, `nt-build`, `nt-size`, `nt-zip`, `nt-check`, `nt-qr`, `nt-clean`, `nt-doctor`, `nt-notes` |
| 🛡 **Safe** | exit-code aware, production overwrite confirmation, `--dry-run` |
| 🔄 **Self-updating** | daily check + `nt-update` (or `NT_AUTO_UPDATE=1`) |

## Commands

```
DEPLOY     nt-push · nt-ship · nt-bp
TIME MACHINE  nt-rollback · nt-snapshots
MANAGE     nt-list · nt-clients · nt-projects · nt-rm · nt-rmproject · nt-logs · nt-open · nt-copy
QUALITY    nt-audit · nt-analytics · nt-stats
SCAFFOLD   nt-create · nt-design · nt-new · nt-card (beta)
TOOLKIT    nt-serve · nt-build · nt-size · nt-zip · nt-images · nt-check · nt-qr · nt-clean · nt-doctor · nt-notes · nt-gui
SETUP      nt-init · nt-config · nt-update · nt-version
```

Run `nt-help` for the full reference. You can also use a single entrypoint: `nt <command>`.

## Scaffold a perfect site

```bash
nt-create acme            # asks: HTML/CSS/JS or Vite, and whether to start a live-reload dev server
nt-design add stripe      # pull a brand DESIGN.md from the community library (MIT)
nt-images .               # convert PNG/JPEG → WebP and rewrite the HTML references
```

`nt-create` ships a PageSpeed-tuned starter: semantic `index.html`, `DESIGN.md` (9-section
agent spec), `AGENTS.md`, `CLAUDE.md`, `_headers` (CSP + caching), `robots.txt`, `sitemap.xml`,
`site.webmanifest`, `favicon.svg`, `404.html`. AI agents read `DESIGN.md` and ask you to fill
the empty sections before generating UI.

## Claude Code plugin (+ MCP)

Drive nt-deploy from Claude Code in natural language — deploy, roll back, audit and scaffold.
See [`integrations/claude-code/`](integrations/claude-code/).

## Multiple projects

```bash
nt-push ./dist client -p other-project    # target any project, one-off
echo 'NT_PROJECT=my-project' > .ntdeploy   # or pin a project per repo
```

## The GUI

```bash
nt-gui            # opens a light control panel in your browser
nt-gui dns        # one-time setup to reach it at http://nt.local:7700
```

Light theme, shadcn / next-forge inspired. Manage clients and projects, run audits and checks,
show QR codes, roll back, and configure your **PageSpeed API key** and **Web Analytics tokens**
— all from the browser. It binds to `127.0.0.1` only and runs a strict command whitelist.

## Requirements

- **Node.js** (for `wrangler`, installed automatically if missing)
- Optional: `jq` (richer output), `qrencode` (terminal QR), `python3` (GUI + local server)

## License

MIT © [nico33t](https://github.com/nico33t)
