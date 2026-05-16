---
name: handoff
description: Capture session state at end of a coding session so a future Claude Code session can resume cold, or resume from a prior handoff. Trigger PROACTIVELY when the user signals end of session — "wrapping up", "call it for tonight", "let's stop here", "I need to go", "continue tomorrow", "pick this up later", "save where we are", "done for now" — and also on explicit /handoff. For resume, trigger when user says "resume", "pick up where we left off", "continue from yesterday", "what was I working on", or /handoff resume.
risk: low
source: composite (willseltzer create template + hacktivist123 resume protocol + multi-project index)
---

# Handoff

Capture session state for cold-start resume. Three modes: **create** (default), **resume**, **list**.

## When to use

**Create** — proactively when the user signals end-of-session (see trigger phrases in description) OR on explicit `/handoff`. Confirm in one line before writing: "Writing handoff to `<path>` — proceed?"

**Resume** — when user asks to pick up prior work, OR proactively at start of a fresh session if a HANDOFF.md exists in the current project and is < 14 days old. Surface it with one sentence: "Found handoff from <date> — want me to resume from it?"

**List** — when user asks "what was I working on", "what's hot", "show me my open sessions". Read `~/.claude/handoffs/index.md` and show the last ~10 entries.

## Create mode

### Step 1 — Detect project context

```bash
git rev-parse --show-toplevel 2>/dev/null  # project root if in a repo
git branch --show-current 2>/dev/null
git log -1 --format='%h %s' 2>/dev/null
git status --short 2>/dev/null
```

- If in a git repo: write `<project-root>/HANDOFF.md`.
- If not in a git repo: write `~/.claude/handoffs/sessions/YYYY-MM-DD-HHMM-<slug>.md` where `<slug>` is a 3-5 word kebab summary of the session goal.

### Step 2 — Write HANDOFF.md using this template

```markdown
# Handoff — YYYY-MM-DD HH:MM

**Project:** <absolute path or repo name>
**Branch:** <branch name, or "n/a (not a repo)">
**HEAD:** <short SHA + subject>
**Working tree:** <"clean" or "N modified, M untracked" with brief list>

## Goal
<1-2 sentences: what we set out to do this session and why>

## Status

### DONE
- <concrete deliverable, with file:line refs where useful>

### PARTIAL
- <work started; what specifically remains; which file/function is half-done>

### NOT DONE
- <items from the goal we didn't get to>

## Next step
<The single most-actionable thing to do first when resuming. One sentence. Include the file path or command to start with.>

## Files to know
| Path | Why it matters |
|------|----------------|
| path/to/file.ts | What this file's role is and what we changed/explored |

## Key decisions
| Decision | Rationale |
|----------|-----------|
| Chose X over Y | Because Z |

## Failed approaches (don't retry without new info)
- <Approach tried + why it failed. Saves the next session from re-attempting.>

## Open questions / blockers
- <Unresolved questions, missing credentials, waiting on someone, etc.>

## References
- <PRs, issues, commits, docs, Slack threads — link, don't paraphrase>
```

### Step 3 — Append to central index

Append ONE line to `~/.claude/handoffs/index.md`. Create the file with a header if it doesn't exist:

```markdown
# Handoff Index

One line per handoff, newest at bottom. Use `tail -20` or `ls -lt` of HANDOFF.md mtimes to see what's hot.

```

Then append:

```
- YYYY-MM-DD HH:MM · <project-root-path-or-session-file> · <branch> · Next: <next-step one-liner>
```

### Step 4 — Confirm

Tell the user: "Handoff written to `<path>` and indexed. Next session can resume with `/handoff resume`."

## Resume mode

### Step 1 — Locate the handoff

- If a `HANDOFF.md` exists in the current directory's git root, use it.
- Otherwise read `~/.claude/handoffs/index.md` and show the last 5 entries. Ask which one to resume.

### Step 2 — Read it fully

Read the entire HANDOFF.md. Do not skim. The Failed Approaches and Key Decisions sections are load-bearing — skipping them means re-litigating settled questions.

### Step 3 — Validate against workspace (workspace is ground truth)

```bash
git status --short
git log -5 --format='%h %ad %s' --date=short
git diff <handoff-HEAD>..HEAD --stat 2>/dev/null  # what changed since the handoff
```

For each item in DONE: spot-check the file actually contains the claimed change. If a DONE item's file has since been modified or reverted, **re-classify it as PARTIAL or NOT DONE** and tell the user.

For each item in PARTIAL: verify the half-done state still exists. If it's been finished or abandoned in commits since, update the status.

**Never trust the handoff over the workspace.** A handoff is a frozen snapshot; the repo is current truth.

### Step 4 — Re-state and proceed

Summarize in 3-5 lines:
- Where we left off (the Next step from the handoff)
- What's changed since (commits, working-tree state)
- Any DONE→PARTIAL reclassifications
- The single action you're about to take

Then start from "Next step" — don't re-plan from scratch unless the workspace has drifted enough to invalidate it.

## List mode

Read `~/.claude/handoffs/index.md`. Show last 10 entries with `tail`. If a user has multiple recent handoffs across projects, present them as a small table: date · project · next step. Help them pick.

## Rules

- **One HANDOFF.md per project**, overwritten each time. Historical versions live in git history. Don't create dated copies in the project root.
- **The index is append-only.** Never rewrite it. If an entry is wrong, append a corrected entry; don't edit history.
- **Be concrete in Next step.** "Continue the migration" is useless. "Run `npm run migrate:dev` then edit `prisma/schema.prisma` line 47 to add the `archived` column" is useful.
- **Don't duplicate PRDs/specs/ADRs.** Reference them by path. The handoff is a pointer, not a copy.
- **Capture failure, not just success.** The Failed Approaches section is the highest-value part — it's the thing only the live session knows that a fresh session can't recover from the repo.
- **If working tree is dirty, say so explicitly.** A future session resuming with uncommitted changes needs to know whether to commit, stash, or continue editing.

## Anti-patterns

- ❌ Writing a handoff with vague Next step ("keep going on the feature").
- ❌ Overwriting HANDOFF.md without reading the existing one first — you may lose Failed Approaches the user paid in time to learn.
- ❌ Marking something DONE in resume mode without checking the file.
- ❌ Creating handoffs after trivial sessions (a single typo fix, a one-line commit). Save handoffs for sessions with real in-flight state.
