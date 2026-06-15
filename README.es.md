<div align="center">

# ⚡ nt-deploy

### Publica tu sitio en **un comando** — y mucho más.

Despliega en Cloudflare Pages, **rollback instantáneo**, auditorías PageSpeed reales, una GUI
ligera y un toolkit completo para desarrolladores. Todo desde la terminal. Sin dependencias
salvo `wrangler`.

[![version](https://img.shields.io/badge/version-2.0.0-6d4aff)](https://github.com/nico33t/nt-deploy)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[English](README.md) · [Italiano](README.it.md) · **Español** · [Deutsch](README.de.md)

</div>

---

```bash
curl -fsSL https://raw.githubusercontent.com/nico33t/nt-deploy/main/install.sh | bash
```

```bash
nt-init             # inicia sesión en Cloudflare + crea el proyecto
nt-ship cliente     # build + deploy + QR + abrir, todo en uno
nt-rollback cliente # ⏪ restaura al instante el despliegue anterior
```

## Por qué nt-deploy

`wrangler` despliega. nt-deploy te da todo el **flujo de trabajo** alrededor: ramas por cliente,
builds, auditorías de calidad, tráfico, una GUI, y lo único que wrangler no puede hacer:
el **rollback**.

## ★ Función estrella — Time Machine

Cloudflare no ofrece rollback por CLI para Pages. nt-deploy archiva cada despliegue en local,
así puedes restaurar cualquier versión en segundos.

```bash
nt-snapshots cliente          # historial de despliegues
nt-rollback  cliente          # vuelve al anterior
nt-rollback  cliente 17000000 # a un snapshot exacto
```

## Funciones

| | |
|---|---|
| 🚀 **Deploy** | `nt-push [dir] [cliente]` · carpeta estática o build automático (`--build`) |
| ⏪ **Time Machine** | snapshots locales + `nt-rollback` real |
| 🔬 **Auditoría PageSpeed** | `nt-audit` — puntuación real (motor Google Lighthouse) |
| 🪟 **GUI** | `nt-gui` — consola ligera en el navegador (estilo shadcn), en `nt.local` |
| 📊 **Tráfico** | `nt-analytics inject` para activar Web Analytics, `nt-stats` para las visitas |
| 🧰 **Toolkit** | `nt-serve`, `nt-create`, `nt-design`, `nt-images`, `nt-zip`, `nt-check`, `nt-qr`, `nt-clean`, `nt-doctor`, `nt-notes` |
| 🛡 **Seguro** | control de exit-code, confirmación en producción, `--dry-run` |

## Crea un sitio perfecto

```bash
nt-create acme       # pregunta: HTML/CSS/JS o Vite, y si arrancar un dev server con recarga en vivo
nt-design add stripe # descarga un DESIGN.md de marca de la biblioteca de la comunidad (MIT)
nt-images .          # convierte PNG/JPEG → WebP y reescribe las referencias del HTML
```

`nt-create` genera un starter optimizado para PageSpeed: `index.html` semántico, `DESIGN.md`
(spec de 9 secciones para agentes de IA), `AGENTS.md`, `CLAUDE.md`, `_headers` (CSP + caché),
`robots.txt`, `sitemap.xml`, `site.webmanifest`, `favicon.svg`, `404.html`.

## Plugin de Claude Code (+ MCP)

Usa nt-deploy desde Claude Code en lenguaje natural. Ver [`integrations/claude-code/`](integrations/claude-code/).

## Requisitos

- **Node.js** (para `wrangler`, se instala automáticamente si falta)
- Opcionales: `jq`, `qrencode`, `python3` (GUI + servidor local), `cwebp` (conversión de imágenes)

## Licencia

MIT © [nico33t](https://github.com/nico33t)
