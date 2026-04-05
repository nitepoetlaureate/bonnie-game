# Mycelium Note-Writing Discipline

Mycelium is the project's persistent knowledge layer — structured notes attached
to git objects (files, directories, commits) via `refs/notes/mycelium`. Agents
read it on arrival and write to it after meaningful work.

The full protocol and command reference is at `./mycelium/SKILL.md`.

## Mandatory Arrival Protocol

At the start of any session working on a specific file or system:

```bash
mycelium.sh find constraint     # project-wide constraints — READ FIRST
mycelium.sh find warning        # known fragile things — READ FIRST
mycelium/scripts/context-workflow.sh <file>   # file + parent dirs + commit context
```

If `context-workflow.sh` is unavailable, do this manually:

```bash
mycelium.sh read <file>         # note on this exact file version
mycelium.sh read HEAD           # note on current commit
```

## Mandatory Departure Protocol

After any meaningful work (design decision, code change, architectural discovery):

```bash
# Note on the commit (context — why this change exists)
mycelium.sh note HEAD -k context -m "What you did and why."

# Note on changed files (summary — what future agents should know)
mycelium.sh note <changed-file> -k summary -m "What this file does now."

# If you found something fragile or dangerous
mycelium.sh note <file> -k warning -m "What to watch out for."

# If you made an architectural decision
mycelium.sh note <file> -k decision -t "Short label" -m "Decision and rationale."
```

## When to Write Which Kind

| Kind | When to use |
|------|-------------|
| `constraint` | A rule that must not be broken (e.g., "pixel art must render nearest-neighbor") |
| `warning` | Something fragile or dangerous that future agents must know |
| `decision` | An architectural or design choice with rationale |
| `summary` | What a file or directory does — current state |
| `context` | Why a change was made — commit-level reasoning |
| `observation` | Neutral finding — not a decision, not a warning, but worth recording |
| `todo` | Explicit deferred work |
| `value` | Project-level principle (attach to `.`) |

## Target Selection

| Target | Use when |
|--------|----------|
| `path/to/file` | Note is about this file (stable, findable even as file changes) |
| `HEAD` | Note is about this commit (why this change exists) |
| `.` | Note applies to the whole project |
| `src/dir/` | Note is about this subsystem |

Default: use paths. Use `HEAD` for commit context. Use `.` for project principles.

## Noise Discipline

**Do NOT write notes for:**
- Trivial edits (typos, formatting, renaming)
- Information self-evident from reading the code
- Information that will be stale within this session

**DO write notes for:**
- Non-obvious decisions (why X instead of Y)
- Constraints that cannot be derived from reading the code
- Warnings about known-fragile paths or API gotchas
- Cross-session context that saves the next agent 15+ minutes of archaeology

## Workflow Scripts

```bash
mycelium/scripts/context-workflow.sh <path>   # arrival workflow
mycelium/scripts/path-history.sh <path>       # historical notes via git
mycelium/scripts/note-history.sh <target>     # overwrite history for one note
```

## Full Reference

Read `./mycelium/SKILL.md` for the complete protocol, patterns, edge types,
slot usage, and jj colocated repo guidance.
