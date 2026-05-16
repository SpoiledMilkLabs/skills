# Handoff — 2026-05-15 18:42

**Project:** ~/code/notes-app
**Branch:** feat/markdown-export
**HEAD:** a4f3c21 wip: ExportMenu component scaffold
**Working tree:** 3 modified, 1 untracked
- M src/components/Editor.tsx
- M src/components/Sidebar.tsx
- M src/lib/export.ts
- ?? src/components/ExportMenu.tsx (new file, not staged)

## Goal
Add markdown export to the notes app. User picks one or many notes, hits Export, gets a downloaded `.md` or `.zip`.

## Status

### DONE
- `src/lib/export.ts:23` — `noteToMarkdown(note)` converts a note's TipTap JSON to markdown using `marked`. Tested manually on three sample notes, output looks right.
- Sidebar multi-select wired (cmd-click to add, shift-click for range). `Sidebar.tsx:88`.

### PARTIAL
- `ExportMenu.tsx` exists but the dropdown only renders, doesn't fire. The `onClick` handler is stubbed. Needs to call `noteToMarkdown` then trigger download via Blob.
- Zip export for multi-select: chose `jszip` but haven't installed it yet.

### NOT DONE
- Settings toggle for "include frontmatter in export". Low priority, parked.

## Next step
Wire `ExportMenu.tsx:42` `handleExport` to call `noteToMarkdown` for each selected note, then trigger download. Single note exports as `.md`, multiple exports as `.zip` (install jszip first: `npm i jszip`).

## Files to know
| Path | Why it matters |
|------|----------------|
| `src/lib/export.ts` | Markdown conversion lives here. Don't duplicate. |
| `src/components/ExportMenu.tsx` | The dropdown shell. `handleExport` is the half-done part. |
| `src/state/notes.ts` | `selectedNoteIds` is the source of truth for multi-select. |

## Key decisions
| Decision | Rationale |
|----------|-----------|
| `marked` over `turndown` | Notes are stored as markdown-friendly JSON; `marked` is simpler for this direction. |
| Zip on multi-select, not always | Single-note download as `.md` is cleaner UX. |

## Failed approaches (don't retry without new info)
- Tried `file-saver` for the download trigger. Pulled in a 12kb dep for what's a four-line Blob + anchor pattern. Removed.
- Tried generating markdown server-side. The server doesn't have the note content (client-only state), so it would mean round-tripping. Not worth it.

## Open questions / blockers
- Should exported markdown use ATX (`#`) or setext (`===`) headers? Defaulted to ATX, confirm with user.
- Filename collision when exporting multiple notes with the same title — currently just appends a number. Confirm this is fine.

## References
- Spec: `./docs/export-spec.md`
- Related PR (closed, different approach): #142
