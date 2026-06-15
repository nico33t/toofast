# Third-party notices

nt-deploy is licensed under the **MIT License** (see `LICENSE`). All source code, the default
`DESIGN.md`/`AGENTS.md`/`CLAUDE.md` templates, the GUI and the live editor are original work.

## Fetched on demand (not bundled)

- **`nt-design`** retrieves brand `DESIGN.md` files from
  [`VoltAgent/awesome-design-md`](https://github.com/VoltAgent/awesome-design-md) **(MIT License)**
  at runtime, into the user's own project, with a source/attribution header added to each file.
  These templates are **not vendored** in this repository — nothing is redistributed here.
  Their copyright and MIT license remain with their authors.

- **`nt-audit`** calls Google's public **PageSpeed Insights API**. **`nt-card`** and **`nt-images`**
  use locally installed tools if present (headless Chrome, `cwebp`/ImageMagick/`sips`).
  **`nt-push`/deploy** wraps **Cloudflare `wrangler`**. These are external tools/services used at
  runtime under their own licenses; none of their code is included here.

## Brand names

Brand names referenced by `nt-design` (e.g. Stripe, Linear, Notion) are trademarks of their
respective owners and are used only to identify the corresponding community templates. nt-deploy
is not affiliated with or endorsed by them.
