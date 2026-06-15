<div align="center">

# ⚡ nt-deploy

### Bring deine Seite online — mit **einem Befehl**, und vielem mehr.

Deploy auf Cloudflare Pages, **sofortiges Rollback**, echte PageSpeed-Audits, eine leichte GUI
und ein komplettes Entwickler-Toolkit. Alles im Terminal. Keine Abhängigkeiten außer `wrangler`.

[![version](https://img.shields.io/badge/version-2.0.0-6d4aff)](https://github.com/nico33t/nt-deploy)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · **Deutsch**

</div>

---

```bash
curl -fsSL https://raw.githubusercontent.com/nico33t/nt-deploy/main/install.sh | bash
```

```bash
nt-init             # bei Cloudflare anmelden + Projekt anlegen
nt-ship kunde       # Build + Deploy + QR + öffnen, alles in einem
nt-rollback kunde   # ⏪ sofort den vorherigen Deploy wiederherstellen
```

## Warum nt-deploy

`wrangler` deployt. nt-deploy gibt dir den ganzen **Workflow** drumherum: Branches pro Kunde,
Builds, Qualitäts-Audits, Traffic, eine GUI — und das Eine, was wrangler allein nicht kann:
**Rollback**.

## ★ Killer-Feature — Time Machine

Cloudflare bietet kein CLI-Rollback für Pages. nt-deploy archiviert jeden Deploy lokal,
so stellst du jede Version in Sekunden wieder her.

```bash
nt-snapshots kunde          # Deploy-Verlauf
nt-rollback  kunde          # zurück zum vorherigen
nt-rollback  kunde 17000000 # zu einem genauen Snapshot
```

## Funktionen

| | |
|---|---|
| 🚀 **Deploy** | `nt-push [dir] [kunde]` · statischer Ordner oder automatischer Build (`--build`) |
| ⏪ **Time Machine** | lokale Snapshots + echtes `nt-rollback` |
| 🔬 **PageSpeed-Audit** | `nt-audit` — echter Score (Google-Lighthouse-Engine) |
| 🪟 **GUI** | `nt-gui` — leichte Browser-Konsole (shadcn-Stil), unter `nt.local` |
| 📊 **Traffic** | `nt-analytics inject` für Web Analytics, `nt-stats` für Besuche |
| 🧰 **Toolkit** | `nt-serve`, `nt-create`, `nt-design`, `nt-images`, `nt-zip`, `nt-check`, `nt-qr`, `nt-clean`, `nt-doctor`, `nt-notes` |
| 🛡 **Sicher** | Exit-Code-bewusst, Bestätigung in Produktion, `--dry-run` |

## Eine perfekte Seite erzeugen

```bash
nt-create acme       # fragt: HTML/CSS/JS oder Vite, und ob ein Dev-Server mit Live-Reload starten soll
nt-design add stripe # holt eine Marken-DESIGN.md aus der Community-Bibliothek (MIT)
nt-images .          # konvertiert PNG/JPEG → WebP und schreibt die HTML-Referenzen um
```

`nt-create` liefert einen PageSpeed-optimierten Starter: semantisches `index.html`, `DESIGN.md`
(9-Abschnitt-Spec für KI-Agenten), `AGENTS.md`, `CLAUDE.md`, `_headers` (CSP + Caching),
`robots.txt`, `sitemap.xml`, `site.webmanifest`, `favicon.svg`, `404.html`.

## Claude-Code-Plugin (+ MCP)

Steuere nt-deploy aus Claude Code in natürlicher Sprache. Siehe [`integrations/claude-code/`](integrations/claude-code/).

## Voraussetzungen

- **Node.js** (für `wrangler`, wird bei Bedarf automatisch installiert)
- Optional: `jq`, `qrencode`, `python3` (GUI + lokaler Server), `cwebp` (Bildkonvertierung)

## Lizenz

MIT © [nico33t](https://github.com/nico33t)
