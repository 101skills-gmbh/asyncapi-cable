# asyncapi_cable — Usergroup talk

A ~13–18 min [Slidev](https://sli.dev) presentation introducing `asyncapi_cable`
— the WebSocket companion to the `openapi_ruby` talk. 15 slides.

## Run it

```bash
cd presentation
pnpm install
pnpm dev         # opens http://localhost:3030
```

Uses pnpm, pinned via mise (`.tool-versions` → `pnpm 10.28.1`) and
`packageManager` in `package.json`. `mise install` provisions it; then bare
`pnpm` resolves inside this folder.

## Presenting

- Press `f` for fullscreen, `o` for slide overview.
- Speaker notes are the `<!-- ... -->` block under each slide — open the
  **presenter view** (`/presenter` on the URL, or the "person" icon) to read
  them on a second screen.
- Arrow keys / space advance.

## Export

```bash
pnpm build        # static site into dist/
pnpm export       # slides.pdf (needs playwright-chromium)
```

## Theme

A self-contained LCARS (Star Trek: Strange New Worlds) theme, tuned to the same
brass-and-teal palette as the `openapi_ruby` deck so the two read as a set. The
LCARS chrome, palette, and typography helpers live in `style.css` (auto-loaded
by Slidev); `theme: none` in the frontmatter.

- Palette: `--gold`, `--coral`, `--teal`, `--cream`, `--steel` on a deep navy
  `--bg`, defined as CSS custom properties in `style.css`.
- The persistent LCARS frame (elbow, side rail, segmented bars) is a small HTML
  block repeated at the top of every slide. The `NCC · SEC nn/nn` readout is
  **live** via `$slidev.nav` (works because `mdc: true`). The top-bar tag reads
  `ASYNCAPI-CABLE`.
- `canvasWidth: 1920` — px sizes are authored against a 1920×1080 canvas.
- Fonts: Barlow + JetBrains Mono via the `fonts:` frontmatter; Antonio (headings)
  via an `@import` in `style.css`. **The Antonio `@import` needs network** — for
  a fully offline export, self-host it or add it to `fonts:`.
- `.tealrail` on a code block swaps its left rail from coral to teal — used to
  mark the "output"/shared side (generated docs, dual-scope schema).

Tune colors via the `--*` CSS variables at the top of `style.css`.

> This deck was imported from the Claude Design project
> `asyncapi_cable-talk.dc.html` (kept under `design/` for reference). The
> runnable deck is this folder's `slides.md`.

## Style: hybrid-minimal

Slides are deliberately sparse — one idea or one code block each, no explanatory
prose on the slide. **The content lives in the speaker notes** (the `<!-- ... -->`
block under each slide), written in a casual talk voice. Open presenter view to
read them while presenting.

## Structure (15 slides)

1. Cover — `asyncapi_cable`
2. Speaker — Marten Klitzke / fobizz
3. Payload drift — channel sends one thing, client expects another
4. What is AsyncAPI? (OpenAPI, but for messages)
5. Typing a WebSocket on Rails: your options
6. **asyncapi_cable** — one engine, three jobs (divider)
7. **Components** — the same schema classes as REST
8. **Scopes** — one definition, two specs
9. **Generation** — the doc comes from channel tests
10. **Testing** — one assert fires it and checks it
11. Test in, doc out (`rake asyncapi_cable:generate`)
12. **Validation** — every broadcast, checked at runtime
13. Typed frontend — the same contract types your client
14. Why it can't drift — define once; tests, runtime & frontend from one schema
15. Thank you / Questions

Edit `slides.md` to adjust content; the GitHub handle lives on the speaker slide.
