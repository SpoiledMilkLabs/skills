---
name: handoff
version: 1.3.0
description: Capture session state at end of a coding session so a future Claude Code session can resume cold, or resume from a prior handoff. Trigger PROACTIVELY when the user signals end of session — "wrapping up", "call it for tonight", "let's stop here", "I need to go", "continue tomorrow", "pick this up later", "save where we are", "done for now" — and also on explicit /handoff. For resume, trigger when user says "resume", "pick up where we left off", "continue from yesterday", "what was I working on", or /handoff resume.
risk: low
source: composite (willseltzer create template + hacktivist123 resume protocol + multi-project index)
repo: https://github.com/SpoiledMilkLabs/skills
---

# Handoff

Capture session state for cold-start resume. Three modes: **create** (default), **resume**, **list**.

## What this skill does NOT do

**It does not relieve in-session context pressure.** The conversation transcript is already in the prompt cache when `/handoff create` runs. Writing the handoff is a *write*-side op for the **next** session. After Create completes, the skill tells you to `/clear` (or close the session) — continuing in the same conversation will still hit compact and the handoff buys you nothing until you start fresh.

## Configuration

The skill reads `~/.claude/handoffs/config.json` on every invocation. If the file doesn't exist, use these defaults and write the file on first run so the user can edit it:

```json
{
  "retention": "archive",
  "max_versions": 10,
  "history_path": "sessions/.history/",
  "auto_obsidian_log": true,
  "update_check": {
    "enabled": true,
    "repo": "SpoiledMilkLabs/skills",
    "throttle_days": 7
  }
}
```

- `retention`: `"archive"` (default) keeps a single archived copy of an orphaned handoff. `"version-history"` keeps the last `max_versions` of each handoff under `history_path`. See **Retention modes** below.
- `max_versions`: cap for `version-history` mode. Older versions get pruned.
- `history_path`: relative to `~/.claude/handoffs/`. Folder structure: `<history_path>/<slug>/vN.md`.
- `auto_obsidian_log`: append archive events to `~/knowledge/wiki/log.md` if the vault exists. Off = silent archival.
- `update_check.enabled`: see **Update check** at the bottom. Now only fires on `list` mode, throttled to `throttle_days` (default weekly).

If the JSON is malformed, fall back to defaults and tell the user to fix the file — don't silently proceed.

## Core invariant — one handoff per project key

A **project key** is:
- For a git repo: the absolute path of the git root (e.g. `/Users/melqui/base44-migration`)
- For a non-repo session: a stable kebab-case slug (e.g. `linkedin-profile-ai-pivot`) — NOT timestamped

Every project key maps to **exactly one** handoff file and **exactly one** line in the index. New handoffs overwrite — they do not accumulate. Historical state lives in git for repos; for non-repos, the file is overwritten and the previous version is gone (move to archive only if it's being orphaned by a different slug taking its spot — see "Retention modes" below).

## When to use

**Create** — proactively when the user signals end-of-session (see trigger phrases in description) OR on explicit `/handoff`. Confirm in one line before writing: "Writing handoff to `<path>` — proceed?"

**Resume** — when user asks to pick up prior work, OR proactively at start of a fresh session if a HANDOFF.md exists in the current project and is < 14 days old. Surface with: "Found handoff from <date> — want me to resume from it?"

**List** — when user asks "what was I working on", "what's hot", "show me my open sessions". Read `~/.claude/handoffs/index.md` and show the top entries (newest first).

## Create mode

### Step 1 — Determine the project key and target path

```bash
git rev-parse --show-toplevel 2>/dev/null  # if set, this is the project key (git mode)
git branch --show-current 2>/dev/null
git log -1 --format='%h %s' 2>/dev/null
git status --short 2>/dev/null
```

- **Git mode** (in a repo): target = `<project-root>/HANDOFF.md`, key = `<project-root>`.
- **Non-git mode**: target = `~/.claude/handoffs/sessions/<slug>.md`, key = `<slug>`.
  - If you resumed an existing session earlier in this conversation, **reuse that exact slug** — never invent a new one.
  - Otherwise, check `~/.claude/handoffs/.active.json` for an entry whose key matches the current absolute cwd.
    - **Ambiguous-cwd guard:** if cwd is exactly `$HOME` or `/`, the pin is too coarse to silently trust. Surface a one-line confirm: "Reuse pinned slug `<slug>` (pinned <date>), or start a new session?" Wait for the answer before proceeding. Without this guard, every unrelated session started from `$HOME` would silently overwrite the same handoff.
    - Otherwise, if the entry's `updated` field is < 7 days old, **silently reuse that `slug`**. This is the post-`/clear` recovery path: in-conversation slug memory is wiped when context is cleared, but the disk pin survives — without it, the next `/handoff` would invent a fresh slug, displace the old one from the index, and (under `retention: archive`) move the old file into `sessions/archive/`, effectively deleting the user's saved state.
  - For a brand-new non-git session, propose a slug (3-5 word kebab) and ask: "Use slug `<slug>`, or continue an existing session?" If `<slug>.md` already exists in `sessions/`, also ask before overwriting.

### Step 2 — Write the handoff using this template

The template has two parts: **Digest** (always read on resume — keep it tight) and **Appendix** (consulted only when the Next step actually touches it). Resume mode burns ~70% fewer tokens because of the split.

```markdown
# Handoff — YYYY-MM-DD HH:MM

**Project:** <absolute path or repo name>
**Branch:** <branch name, or "n/a (not a repo)">
**HEAD:** <short SHA + subject>
**Working tree:** <"clean" or "N modified, M untracked" with brief list>

## Digest

### Goal
<1-2 sentences: what we set out to do this session and why.>

### Status (totals only — full lists in Appendix)
- DONE: <N>
- PARTIAL: <N>
- NOT DONE: <N>

### Next step
<The single most-actionable thing to do first when resuming. One sentence. Include the file path or command to start with.>

---

## Appendix

### DONE
- <concrete deliverable, with file:line refs where useful>

### PARTIAL
- <work started; what specifically remains; which file/function is half-done>

### NOT DONE
- <items from the goal we didn't get to>

### Files to know
- `path/to/file.ts` — what this file's role is and what we changed/explored
- `path/to/other.ts` — …

### Key decisions
- **Chose X over Y** — because Z
- …

### Failed approaches (don't retry without new info)
- <Approach tried + why it failed. Saves the next session from re-attempting.>

### Open questions / blockers
- <Unresolved questions, missing credentials, waiting on someone, etc.>

### References
- <PRs, issues, commits, docs, Slack threads — link, don't paraphrase>
```

**Secrets discipline:** Never inline API keys, tokens, `.env` contents, passwords, or PII into the handoff. Reference by path (e.g. ``"key in `.env.local` under `STRIPE_SECRET_KEY`"``) — never the value. Handoffs live under `~/.claude/handoffs/` and are read by any future model invocation; treat the file as quotable in front of anyone with home-dir access.

### Step 3 — Upsert the index (NOT append)

Read `~/.claude/handoffs/index.md`. Drop any existing line whose project key matches the one you're writing. Prepend the new line at the top (newest first). Create the file with a header if it doesn't exist:

```markdown
# Handoff Index

One line per project key. Newest on top. Lines are replaced in place when the same project gets a new handoff — never appended blindly.

Format: `- YYYY-MM-DD HH:MM · <project-path-or-session-file> · <branch> · Next: <one-liner>`

```

The matching rule: a line matches if its second `·`-separated field (project-path or session-file path) equals the new entry's. Be exact — don't fuzzy-match.

### Step 4 — Pin the active slug (non-git mode only)

For non-git handoffs, update `~/.claude/handoffs/.active.json`:
- Read it (start with `{}` if absent or malformed).
- Set `data[<absolute-cwd>] = { "slug": "<slug>", "updated": "<ISO-8601 timestamp>" }`.
- Write atomically: dump JSON to `.active.json.tmp` then `mv` over the original.

This pin survives `/clear`, so the next conversation in the same cwd reuses the slug instead of orphaning the existing handoff file. (See Step 1's ambiguous-cwd guard for the `$HOME`/`/` carve-out.)

Skip for git-mode handoffs — the project key is the git root, which is already deterministic from `git rev-parse --show-toplevel`.

### Step 5 — Confirm and prompt the user to clear

Tell the user, in this exact shape:

> Handoff written to `<path>` and indexed.
>
> **Context note:** this session's transcript is still cached. Run `/clear` (or close this window) before resuming — staying in this conversation will still hit compact, and `/handoff resume` from a fresh session is ~500 tokens vs the full transcript.
>
> Resume command: `/handoff resume`

Skip the context note only if the conversation is obviously short (e.g. fewer than ~5 tool calls so far) — in that case the carryover is negligible.

## Resume mode

### Step 1 — Locate the handoff

- If a `HANDOFF.md` exists in the current directory's git root, use it.
- Otherwise read `~/.claude/handoffs/index.md` and show the top 5 entries (it's already deduped, so 5 = 5 distinct projects). Ask which one to resume.

### Step 2 — Remember the source path for this conversation

**Critical for the overwrite contract.** Once you've located the handoff file, treat its path as the "active handoff path" for the rest of this conversation. When a subsequent `create` invocation happens in the same session, **silently overwrite that exact file** — do not generate a new slug, do not ask, do not add a new index line. The index line for that project key gets updated in place per Create Step 3.

For non-git mode, also **pin the slug to disk**: update `~/.claude/handoffs/.active.json[<absolute-cwd>] = { "slug": "<slug>", "updated": "<ISO timestamp>" }` (atomic write). This survives `/clear` so the next conversation in this cwd silently reuses the slug instead of inventing a new one and archiving the old file.

### Step 3 — Read the Digest, defer the Appendix

Read the handoff file. **Focus on the Digest** (Goal, Status totals, Next step) — that's enough to start the next action.

**Don't paraphrase the Appendix into working memory by default.** Each Appendix sub-section is a lookup table: consult it only when the current action actually needs it.
- About to touch a file → consult Files to know.
- About to revisit an approach → consult Failed approaches.
- About to revisit a tradeoff → consult Key decisions.

This is the load-bearing efficiency change in v1.3.0. Reading the whole file is fine; *re-stating* the whole file in your response is what burns tokens. Keep your re-statement digest-only.

**Backward compatibility:** old handoffs (pre-v1.3.0) have no `## Digest`/`## Appendix` split — DONE/PARTIAL/NOT DONE are top-level. Treat those files as one big Digest and continue normally.

### Step 4 — Validate against workspace (workspace is ground truth)

```bash
git status --short
git log -5 --format='%h %ad %s' --date=short
```

Parse the handoff's `**HEAD:**` line for the short SHA. Compare to current `HEAD`:
- **SHAs equal** → skip the diff entirely; just note "workspace at the same HEAD as the handoff."
- **SHAs differ** → run `git diff <handoff-HEAD>..HEAD --stat 2>/dev/null`. If the command errors (e.g. the SHA was force-pushed away), say so and fall back to `git status` only.

For each Appendix DONE item: spot-check the file actually contains the claimed change *only if* its file appears in `git status` or recent commits. If a DONE item's file has since been modified or reverted, **re-classify it as PARTIAL or NOT DONE** and tell the user.

For each Appendix PARTIAL item: verify the half-done state still exists. If it's been finished or abandoned in commits since, update the status.

**Never trust the handoff over the workspace.** A handoff is a frozen snapshot; the repo is current truth.

### Step 5 — Re-state and proceed

Summarize in 3-5 lines:
- Where we left off (the Next step from the Digest)
- What's changed since (commits, working-tree state)
- Any DONE→PARTIAL reclassifications
- The single action you're about to take

Then start from "Next step" — don't re-plan from scratch unless the workspace has drifted enough to invalidate it.

## List mode

Read `~/.claude/handoffs/index.md` and show the top entries (newest first — `head`, not `tail`, since the index is now deduped and sorted newest-first). Present as a small table: date · project · next step. Help them pick.

## Retention modes

Branch on `config.retention` before writing a handoff that would replace an existing one.

### Mode A — `archive` (default)

Same-slug overwrites just overwrite. No version is kept.

Only when an old slug is being *displaced* (dropped from the index because a different project takes its slot, or a non-repo session became a git repo), do this BEFORE writing the new entry:

1. `mkdir -p ~/.claude/handoffs/sessions/archive/`
2. Move the orphaned `sessions/<slug>.md` into `sessions/archive/<slug>.md` (overwrite-safe — re-archiving the same slug is fine).
3. If `config.auto_obsidian_log` is true AND `~/knowledge/wiki/log.md` exists, append:

   ```
   ## YYYY-MM-DD — Handoff archived: <slug>
   - **File:** `~/.claude/handoffs/sessions/archive/<slug>.md`
   - **Type:** handoff-archive
   - **Last next-step:** <one-liner from the dropped index line>
   - **Reason:** <"superseded by <new-slug>" or "project moved into git repo at <path>" or "manual archive">
   ```

   If the vault doesn't exist, skip silently — don't error.

4. Git-repo `HANDOFF.md` files are *never* archived — they're overwritten in place and git history holds the past.

### Mode B — `version-history`

Every overwrite is preserved as a numbered version.

For non-repo handoffs:

1. Before writing, if `sessions/<slug>.md` exists, find the highest `vN.md` under `<history_path>/<slug>/` (start at v1 if folder is empty).
2. Move the current `sessions/<slug>.md` to `<history_path>/<slug>/v<N+1>.md`.
3. Write the new handoff to `sessions/<slug>.md`.
4. Prune `<history_path>/<slug>/v*.md` files to the most recent `config.max_versions`. Delete the oldest ones.

For git-repo handoffs in `version-history` mode:

1. Before overwriting `<project-root>/HANDOFF.md`, copy it to `<project-root>/.handoff-history/v<N+1>.md` (create the dir + add to repo's `.gitignore` automatically if not already there — these are local-only, not committed).
2. Prune as above.
3. Then overwrite `HANDOFF.md`.

When listing in resume mode, mention prior versions: `"Resuming linkedin-profile-ai-pivot.md (retention: version-history, 3 prior versions kept)"`.

If `config.retention` is anything other than `"archive"` or `"version-history"`, log a warning and fall back to `archive`.

## Rules

- **One handoff per project key, overwritten each time.** No timestamped filenames in `sessions/`. No multiple lines per project in the index.
- **The index is upserted, not appended.** Same project key → replace the existing line. New project key → prepend. Sort newest-first.
- **Resume → Create silently overwrites the resumed file** within the same conversation. No new file, no confirmation prompt.
- **Be concrete in Next step.** "Continue the migration" is useless. "Run `npm run migrate:dev` then edit `prisma/schema.prisma` line 47" is useful.
- **Don't duplicate PRDs/specs/ADRs.** Reference them by path. The handoff is a pointer, not a copy.
- **Capture failure, not just success.** The Failed Approaches section is the highest-value part — it's the thing only the live session knows that a fresh session can't recover from the repo.
- **If working tree is dirty, say so explicitly.** A future session resuming with uncommitted changes needs to know whether to commit, stash, or continue editing.
- **Never inline secrets, tokens, or PII.** Reference by path; never by value.

## Update check

When **list mode** is invoked (not resume — too latency-sensitive, not create — too noisy), check whether a newer release exists:

1. Skip the check entirely if `config.update_check.enabled` is false.
2. Read `~/.claude/skills/handoff/.update-check.json` if it exists. If its `date` field is within the last `config.update_check.throttle_days` days (default 7), skip — already checked recently.
3. Otherwise, fetch the latest release tag from `config.update_check.repo`:
   ```bash
   curl -s -m 3 "https://api.github.com/repos/$REPO/releases/latest" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))"
   ```
   Tight 3-second timeout. If the request times out, returns no JSON, or you have no network, just skip — never block list on this.
4. Compare to the local `version:` from this file's frontmatter. If the remote is strictly newer (semver compare), print ONE line at the top of the list output:

   ```
   Handoff skill v<remote> available (you have v<local>). Update with: cd <clone> && git pull && ./install.sh
   ```

5. Write `~/.claude/skills/handoff/.update-check.json` with `{"date": "YYYY-MM-DD", "latest_tag": "<tag>"}` so we throttle correctly.

Never auto-pull — surfacing the notice is enough. Resume mode never blocks on this; the user can run `/handoff list` to force a check.

## Anti-patterns

- Writing a handoff with vague Next step ("keep going on the feature").
- Generating a timestamped slug (`2026-05-20-1700-foo.md`) for a non-repo session — slugs are stable, not dated.
- Appending a new index line for a project that already has one. Replace, don't accumulate.
- After resume, writing the next handoff to a *new* path. Reuse the resumed path.
- Overwriting HANDOFF.md without reading the existing one first — you may lose Failed Approaches the user paid in time to learn.
- Marking something DONE in resume mode without checking the file.
- Creating handoffs after trivial sessions (a single typo fix, a one-line commit). Save handoffs for sessions with real in-flight state.
- Paraphrasing the entire Appendix into working memory on resume. Read it, then defer to it — don't re-state it.
- Inlining a secret, token, `.env` value, or PII into any field. Reference by path; never by value.
- Telling the user the handoff has freed their context. It hasn't. Always recommend `/clear` after Create.
