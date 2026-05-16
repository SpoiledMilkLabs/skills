# SpoiledMilk Skills

Hi, I'm Melqui. I'm a copywriter who somehow ended up writing code.

A year ago I couldn't tell you what a git branch was. Today I'm shipping AI agents to production for the companies I work with. The thing that closed that gap, more than any course or tutorial, was Claude Code, and the small library of skills I've built up to make it work the way I think.

This repo is that library.

I'm not a software engineer and I won't pretend to be one. I'm a freelancer who needs the work to actually ship. These are the skills that get me from "I have an idea" to "it's live" without burning a day on stuff I shouldn't have to remember.

I'm publishing them because they're realistically useful to me. If they're useful to you too, great. If they're not, no hard feelings. Claude Code is flexible enough that everyone ends up with their own setup, and that's the point.

## What's a skill?

A skill is a `SKILL.md` file Claude Code loads on demand. Drop one in `~/.claude/skills/<name>/SKILL.md` and Claude can invoke it when relevant, or you can call it explicitly with `/<name>`. [Anthropic's skill docs →](https://docs.anthropic.com/en/docs/claude-code/skills)

## Install

Clone and run the installer:

```bash
git clone https://github.com/SpoiledMilkLabs/skills.git
cd skills
./install.sh
```

The installer copies each skill into `~/.claude/skills/`. It asks before overwriting anything you already have.

Or just grab one:

```bash
cp -r skills/handoff ~/.claude/skills/
```

Restart Claude Code after installing so it picks up the new skills.

## Skills

| Skill | What it does |
|-------|--------------|
| [handoff](skills/handoff) | Capture session state at the end of a coding session so a future Claude Code session can resume cold. Writes a per-project `HANDOFF.md` plus a one-line entry to a central index, so you can see at a glance which project you left in the hottest state. |

More coming as I make them.

## Credits

These skills stand on work others did first. Specifically:

- [willseltzer/claude-handoff](https://github.com/willseltzer/claude-handoff) for the create-side template structure (Files-to-Know, Failed Approaches, Key Decisions)
- [hacktivist123/agent-session-resume](https://github.com/hacktivist123/agent-session-resume) for the resume-side DONE/PARTIAL/NOT DONE protocol with workspace-as-truth validation
- [ykdojo/claude-code-tips](https://github.com/ykdojo/claude-code-tips) for the "What Didn't Work" section pattern
- [mattpocock/skills](https://github.com/mattpocock/skills) for the monorepo layout convention

The multi-project index is the part I added on top, because none of the existing skills handled switching between projects, which is half my workweek.

## License

MIT. Use these however you want. If you ship something with them, I'd love to hear about it.
