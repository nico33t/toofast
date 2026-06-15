<div align="center">

# ⚡ nt-deploy

### Pubblica il tuo sito in **un comando** — e molto di più.

Deploy su Cloudflare Pages, **rollback istantaneo**, audit PageSpeed reali, una GUI leggera
e un toolkit completo per sviluppatori. Tutto dal terminale. Zero dipendenze oltre a `wrangler`.

[![version](https://img.shields.io/badge/version-2.0.0-6d4aff)](https://github.com/nico33t/nt-deploy)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[English](README.md) · **Italiano** · [Español](README.es.md) · [Deutsch](README.de.md)

</div>

---

```bash
curl -fsSL https://raw.githubusercontent.com/nico33t/nt-deploy/main/install.sh | bash
```

```bash
nt-init            # login Cloudflare + crea il progetto
nt-ship cliente    # build + deploy + QR + apri, tutto in uno
nt-rollback cliente # ⏪ ripristina all'istante il deploy precedente
```

## Perché nt-deploy

`wrangler` fa il deploy. nt-deploy ti dà tutto il **flusso di lavoro** intorno: branch per
cliente, build, audit di qualità, traffico, una GUI, e l'unica cosa che wrangler non sa fare:
il **rollback**.

## ★ Kill feature — Time Machine

Cloudflare non offre rollback da CLI per Pages. nt-deploy archivia ogni deploy in locale,
così puoi ripristinare qualunque versione in pochi secondi.

```bash
nt-snapshots cliente          # storico dei deploy
nt-rollback  cliente          # torna al precedente
nt-rollback  cliente 17000000 # a uno snapshot esatto
```

## Funzioni

| | |
|---|---|
| 🚀 **Deploy** | `nt-push [dir] [cliente]` · cartella statica o build automatica (`--build`) |
| ⏪ **Time Machine** | snapshot locali + `nt-rollback` vero |
| 🔬 **Audit PageSpeed** | `nt-audit` — punteggio reale (motore Google Lighthouse) |
| 🪟 **GUI** | `nt-gui` — console leggera nel browser (stile shadcn), su `nt.local` |
| 📊 **Traffico** | `nt-analytics inject` per attivare Web Analytics, `nt-stats` per le visite |
| 🧰 **Toolkit** | `nt-serve`, `nt-create`, `nt-design`, `nt-images`, `nt-zip`, `nt-check`, `nt-qr`, `nt-clean`, `nt-doctor`, `nt-notes` |
| 🛡 **Sicuro** | controllo exit-code, conferma in produzione, `--dry-run` |

## Scaffold di un sito perfetto

```bash
nt-create acme       # chiede: HTML/CSS/JS o Vite, e se avviare un dev server con live reload
nt-design add stripe # scarica un DESIGN.md di brand dalla libreria community (MIT)
nt-images .          # converte PNG/JPEG → WebP e riscrive i riferimenti nell'HTML
```

`nt-create` genera uno starter ottimizzato per PageSpeed: `index.html` semantico, `DESIGN.md`
(spec a 9 sezioni per agenti AI), `AGENTS.md`, `CLAUDE.md`, `_headers` (CSP + cache),
`robots.txt`, `sitemap.xml`, `site.webmanifest`, `favicon.svg`, `404.html`.

## Plugin Claude Code (+ MCP)

Usa nt-deploy da Claude Code in linguaggio naturale. Vedi [`integrations/claude-code/`](integrations/claude-code/).

## Requisiti

- **Node.js** (per `wrangler`, installato in automatico se manca)
- Opzionali: `jq`, `qrencode`, `python3` (GUI + server locale), `cwebp` (conversione immagini)

## Licenza

MIT © [nico33t](https://github.com/nico33t)
