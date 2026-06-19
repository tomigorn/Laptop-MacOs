# Obsidian

Tweaks for [Obsidian](https://obsidian.md/).

## Fix: remove strikethrough/dimming on completed tasks

### Problem

By default Obsidian renders a completed checkbox task (`- [x]`) with
**strikethrough and dimmed text** on top of ticking the box. This is Obsidian's
default styling, not a Markdown error — the underlying file is standard Markdown.
The goal is to keep the checkbox functional but drop the strikethrough/dimming so
completed lines stay readable.

### Solution

A CSS snippet that overrides the strikethrough and restores normal text color.

- **File:** `<vault>/.obsidian/snippets/no-strikethrough.css`
  (on this machine: `~/Documents/Obsidian Vault/.obsidian/snippets/no-strikethrough.css`)
- A copy lives in this repo at [no-strikethrough.css](no-strikethrough.css) for reference.

```css
/* Reading mode */
.markdown-preview-view ul > li.task-list-item.is-checked,
.markdown-preview-view ol > li.task-list-item.is-checked {
  text-decoration: none;
  color: var(--text-normal);
}

/* Live Preview / edit mode */
.markdown-source-view.mod-cm6 .HyperMD-task-line[data-task="x"] {
  text-decoration: none;
  color: var(--text-normal);
}
```

### Enable it (manual GUI step)

Obsidian doesn't pick up new snippets automatically — enable it once in the UI:

**Settings → Appearance → CSS snippets → reload icon (↻) → toggle
`no-strikethrough` on.**

### Scoping note

The edit-mode rule is scoped to `[data-task="x"]` so it **only** affects standard
completed tasks. Custom checkbox states — `[/]` (in progress), `[-]` (cancelled),
`[>]` (forwarded), etc. — keep their normal styling and are left untouched.
