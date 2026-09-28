# omarchy-kakaotalk-mac Guide Site Design System

## 0. Research Log

- Embedded refs: shortlisted `notion`, `claude`, `vercel` → picked Layer A `minimalist-skill` + Layer B `notion`, because this is a long-form Korean setup guide (document-first reading, code blocks, tables) and Notion's warm-paper editorial system fits reading better than a dark product showcase.
- Lazyweb: skipped — single static documentation page whose layout is dictated by the README's own structure (summary → install steps → components → troubleshooting); no product-screen grammar to borrow.
- Imagen drafts: skipped — the page carries no imagery; the hero focal object is a CSS layer-stack diagram built from real content (the runtime stack), which a bitmap would only fake.

## 1. Atmosphere & Identity

A field notebook for getting a Windows messenger running on an ARM Mac: warm paper, quiet ink, and exact commands. It should feel like a well-kept engineering note, not a product landing page. The signature is the **runtime layer stack** in the hero: four stacked paper cards (KakaoTalk.exe → FEX wow64 → ARM64EC Wine → Asahi + Hyprland), each lifted by Notion's multi-layer whisper shadow, with a single yellow marker on the top layer. The yellow marker (KakaoTalk yellow) is the only saturated color on the page and is never used for text.

## 2. Color

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Surface/primary | --surface-primary | #FFFFFF | Page canvas, cards |
| Surface/warm | --surface-warm | #F6F5F4 | Alternating sections, code block chrome, kbd |
| Surface/ink | --surface-ink | #31302E | Code blocks background |
| Text/primary | --text-primary | rgba(0,0,0,0.9) | Headings, body |
| Text/secondary | --text-secondary | #615D59 | Descriptions, captions (5.5:1 on white) |
| Text/tertiary | --text-tertiary | #8A847E | Meta text on white only (3.6:1, large/labels only) |
| Text/on-ink | --text-on-ink | #F6F5F4 | Code text on ink |
| Text/on-ink-muted | --text-on-ink-muted | #B8B2AB | Code comments on ink |
| Border/default | --border-default | rgba(0,0,0,0.1) | Whisper borders, dividers |
| Border/on-ink | --border-on-ink | rgba(255,255,255,0.12) | Divider inside code chrome |
| Accent/link | --accent-link | #0B6BC8 | Links, primary button (5.3:1 on white) |
| Accent/link-hover | --accent-link-hover | #005BAB | Link / button hover |
| Accent/marker | --accent-marker | #FEE500 | Layer-stack marker, step number chips (background only, dark text) |
| Status/ok-bg | --status-ok-bg | #EDF3EC | "동작함" badge bg |
| Status/ok-text | --status-ok-text | #346538 | "동작함" badge text |
| Status/fail-bg | --status-fail-bg | #FDEBEC | "실패" badge bg |
| Status/fail-text | --status-fail-text | #9F2F2D | "실패" badge text |
| Status/note-bg | --status-note-bg | #FBF3DB | Warning callout bg |
| Status/note-text | --status-note-text | #7A5200 | Warning callout text |
| Focus | --focus-ring | #097FE8 | focus-visible outline |

Rules: accent-link is the only interactive color. The marker yellow is decorative-meaningful (marks "the app" layer and step numbers) and never carries text contrast on white.

## 3. Typography

| Level | Size | Weight | Line Height | Tracking | Usage |
|-------|------|--------|-------------|----------|-------|
| Display | clamp(2.25rem, 5vw, 3.5rem) | 700 | 1.12 | -0.03em | Hero title |
| H2 | clamp(1.625rem, 3vw, 2.25rem) | 700 | 1.2 | -0.02em | Section titles |
| H3 | 1.25rem | 700 | 1.35 | -0.01em | Step / card titles |
| Body/lg | 1.125rem | 400 | 1.7 | 0 | Hero lead, section intros |
| Body | 1rem | 400 | 1.75 | 0 | Default reading text |
| Body/sm | 0.875rem | 500 | 1.5 | 0 | Table cells, captions, nav |
| Code | 0.8125rem | 400 | 1.65 | 0 | Code blocks, inline code |
| Overline | 0.75rem | 600 | 1.3 | 0.08em | Section labels (uppercase latin only) |

Font stack:
- Primary: `"Pretendard Variable", Pretendard, "Apple SD Gothic Neo", "Noto Sans KR", "Noto Sans CJK KR", system-ui, sans-serif` — Korean-first; Inter is banned by the Layer A skill and has no Hangul anyway.
- Mono: `"JetBrains Mono", "SF Mono", ui-monospace, "Noto Sans Mono CJK KR", monospace` (system-installed only, no webfont).
- Serif: not used — a Korean display serif webfont costs several hundred KB; hierarchy comes from weight and tracking (Notion's approach).

Pretendard is used only when installed locally; no webfont is downloaded. A swapped-in Korean webfont caused measurable layout shift (Lighthouse CLS) and a third-party request, so the system Korean font is the rendered default.

## 4. Spacing & Layout

Base 4px. Tokens: --space-1 4px, --space-2 8px, --space-3 12px, --space-4 16px, --space-6 24px, --space-8 32px, --space-10 40px, --space-12 48px, --space-16 64px, --space-24 96px.

- Content column: --measure 46rem (reading width). Page shell max: --shell 72rem.
- Desktop ≥ 1080px: two columns — content + sticky table of contents (15rem) on the right. The document is the scroll owner; the TOC is `position: sticky`, no inner scroll.
- Section rhythm: --space-24 vertical padding desktop, --space-16 mobile. Sections alternate primary / warm surface.
- Mobile 375px: one column, no horizontal page scroll; code blocks own their own horizontal scroll (`overflow-x: auto`).

## 5. Components

### Button
- Structure: `<a class="btn btn--primary|btn--ghost">label + optional svg</a>`
- Variants: primary (accent-link bg, white text), ghost (surface-warm bg, primary text).
- Spacing: padding --space-3 / --space-6, gap --space-2. Radius --radius-sm.
- States: hover → primary bg accent-link-hover / ghost bg rgba(0,0,0,0.08); active → scale(0.98); focus-visible → 2px focus ring offset 2px.

### Badge
- Structure: `<span class="badge badge--ok|fail|neutral">`
- Radius full, Overline-ish 0.75rem/600, padding --space-1 / --space-2.
- ok/fail use status pastel pairs; neutral uses surface-warm + text-secondary. Always paired with a text word, never color alone.

### Code block
- Structure: `<figure class="code"><figcaption>lang + copy button</figcaption><pre><code>`
- Ink surface, radius --radius-md, header bar on ink with border-on-ink divider.
- Copy button states: default "복사", hover wash, focus ring, done "복사됨" (text + check glyph) for 1.6s, error "복사 실패".
- Horizontal overflow scrolls inside `pre` (scroll owner), `tabindex="0"` for keyboard scroll.

### Step
- Structure: `<li class="step"><span class="step__num">1</span><div><h3>…</h3>…</div></li>`
- Number chip: marker yellow bg, text-primary, radius --radius-sm, 2rem square.

### Card (component grid)
- White surface, whisper border, radius --radius-md, soft-card shadow, padding --space-6 (mobile) / --space-8.
- Grid: `repeat(auto-fit, minmax(min(18rem, 100%), 1fr))`, gap --space-4.

### Callout
- note variant: status-note pastel pair, radius --radius-sm, padding --space-4 --space-6, leading warning glyph.

### Table
- Whisper-bordered wrapper with its own horizontal scroll on mobile; header row surface-warm; cells Body/sm.

### FAQ (troubleshooting)
- `<details>` items separated by whisper bottom border; summary with + / − glyph; focus ring on summary.

### TOC
- Sticky list of section links, Body/sm. Current section: text-primary + 600 weight + ink-alpha wash rgba(0,0,0,0.05) background (no accent border). Others text-secondary.

### Layer stack (hero)
- Four stacked cards, each offset by translateY and slight scale, deep shadow on the top card. The top card carries the marker dot. Pure CSS, `aria-label` describing the stack.

## 6. Motion & Interaction

| Type | Duration | Easing | Usage |
|------|----------|--------|-------|
| Micro | 120ms | ease-out | Button press, copy state |
| Standard | 200ms | ease-in-out | Hover washes, FAQ glyph |
| Emphasis | 600ms | cubic-bezier(0.16, 1, 0.3, 1) | Section reveal, hero stack settle |

- Reveal on scroll via IntersectionObserver (opacity + translateY 12px), once per block. Content is visible without JS (reveal class added only by JS).
- Hero stack settles once on load (layers slide into their offsets).
- `prefers-reduced-motion`: reveal becomes opacity-only; hero stack appears in place.
- Only transform / opacity animate.

## 7. Depth & Surface

Strategy: mixed — whisper borders for structure, Notion's multi-layer shadows only for cards and the hero stack.

| Level | Value | Usage |
|-------|-------|-------|
| Soft card | 0 4px 18px rgba(0,0,0,0.04), 0 2px 7.8px rgba(0,0,0,0.027), 0 0.8px 2.9px rgba(0,0,0,0.02), 0 0.18px 1px rgba(0,0,0,0.01) | Cards, stack layers |
| Deep | 0 1px 3px rgba(0,0,0,0.01), 0 3px 7px rgba(0,0,0,0.02), 0 7px 15px rgba(0,0,0,0.02), 0 14px 28px rgba(0,0,0,0.04), 0 23px 52px rgba(0,0,0,0.05) | Top hero layer |

Radius: --radius-sm 6px (buttons, chips, callouts), --radius-md 12px (cards, code, tables), --radius-lg 16px (hero stack), --radius-full 9999px (badges). Code header inherits outer radius on top corners only.

Hero background: warm surface with one soft radial light (opacity ≤ 0.6 of warm white on white) — depth without gradient color.

## 8. Accessibility Constraints & Accepted Debt

Constraints: WCAG 2.2 AA; body contrast ≥ 4.5:1 (text-tertiary used only for ≥ 14px 600 labels, never body); visible focus on every link, button, summary, and scrollable pre; skip link to main; `lang="ko"`; landmarks header/nav/main/footer; reduced motion respected.

Accepted debt: none.
