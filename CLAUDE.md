# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical only)
- **Version Control**: Git with trunk-based development
- **Build System**: Godot Export Templates
- **Asset Pipeline**: Godot Import System + Aseprite + RetroDiffusion

> **Note**: Use Godot-specialist agents: `godot-specialist`, `godot-gdscript-specialist`,
> `godot-shader-specialist`, `godot-gdextension-specialist`.
> Always cross-reference `docs/engine-reference/godot/` before suggesting API calls —
> Godot 4.4/4.5/4.6 introduced breaking changes beyond LLM training data.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Knowledge Persistence (Mycelium)

Notes on files, directories, and commits persist across sessions via mycelium.
Notes sync to GitHub via the git remote — `git push` pushes notes, `git fetch` pulls them.

**Agents MUST follow the arrival and departure protocol defined below.**

Quick reference:
- On session start: `mycelium.sh find constraint && mycelium.sh find warning`
- On file work: `mycelium/scripts/context-workflow.sh <file>`
- On departure: `mycelium.sh note HEAD -k context -m "..."` + file notes
- Full primer: `mycelium.sh prime`

@.claude/rules/mycelium.md

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
