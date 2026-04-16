#!/bin/bash
# Claude Code SessionStart hook: Load project context at session start
# Outputs context information that Claude sees when a session begins
#
# Input schema (SessionStart): No stdin input

echo "=== Claude Code Game Studios — Session Context ==="

# Current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
    echo "Branch: $BRANCH"

    # Recent commits
    echo ""
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "  $line"
    done
fi

# Current sprint (find most recent sprint file)
LATEST_SPRINT=$(ls -t production/sprints/sprint-*.md 2>/dev/null | head -1)
if [ -n "$LATEST_SPRINT" ]; then
    echo ""
    echo "Active sprint: $(basename "$LATEST_SPRINT" .md)"
fi

# Current milestone
LATEST_MILESTONE=$(ls -t production/milestones/*.md 2>/dev/null | head -1)
if [ -n "$LATEST_MILESTONE" ]; then
    echo "Active milestone: $(basename "$LATEST_MILESTONE" .md)"
fi

# Open bug count
BUG_COUNT=0
for dir in tests/playtest production; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "BUG-*.md" 2>/dev/null | wc -l)
        BUG_COUNT=$((BUG_COUNT + count))
    fi
done
if [ "$BUG_COUNT" -gt 0 ]; then
    echo "Open bugs: $BUG_COUNT"
fi

# Code health quick check
if [ -d "src" ]; then
    TODO_COUNT=$(grep -r "TODO" src/ 2>/dev/null | wc -l)
    FIXME_COUNT=$(grep -r "FIXME" src/ 2>/dev/null | wc -l)
    if [ "$TODO_COUNT" -gt 0 ] || [ "$FIXME_COUNT" -gt 0 ]; then
        echo ""
        echo "Code health: ${TODO_COUNT} TODOs, ${FIXME_COUNT} FIXMEs in src/"
    fi
fi

# --- Renderer guard: warn if wrong renderer for project type ---
if [ -f "project.godot" ]; then
    RENDERER=$(grep -E '^renderer/rendering_method=' project.godot 2>/dev/null | sed 's/.*=//' | tr -d '"')
    if [ -z "$RENDERER" ]; then
        echo ""
        echo "⚠️  RENDERER: project.godot has no renderer/rendering_method set."
        echo "   Godot defaults to forward_plus (3D). For a 2D game, use gl_compatibility."
        echo "   Add: renderer/rendering_method=\"gl_compatibility\" under [rendering]"
    elif [ "$RENDERER" = "forward_plus" ] && [ "$CLAUDE_CODE_PROJECT_TYPE" = "game" ]; then
        # Check if this is a 2D-only project (no 3D nodes in scenes)
        HAS_3D=$(grep -rl 'type=".*3D"' . --include="*.tscn" 2>/dev/null | head -1)
        if [ -z "$HAS_3D" ]; then
            echo ""
            echo "⚠️  RENDERER: forward_plus renderer detected for 2D-only project."
            echo "   Consider switching to gl_compatibility for better performance."
        fi
    fi
fi

# --- Active session state recovery ---
STATE_FILE="production/session-state/active.md"
if [ -f "$STATE_FILE" ]; then
    echo ""
    echo "=== ACTIVE SESSION STATE DETECTED ==="
    echo "A previous session left state at: $STATE_FILE"
    echo "Read this file to recover context and continue where you left off."
    echo ""
    echo "Quick summary:"
    head -20 "$STATE_FILE" 2>/dev/null
    TOTAL_LINES=$(wc -l < "$STATE_FILE" 2>/dev/null)
    if [ "$TOTAL_LINES" -gt 20 ]; then
        echo "  ... ($TOTAL_LINES total lines — read the full file to continue)"
    fi
    echo "=== END SESSION STATE PREVIEW ==="
fi

# --- Mycelium: surface constraints and warnings ---
if command -v mycelium.sh &>/dev/null && git notes --ref=mycelium list &>/dev/null 2>&1; then
    NOTE_COUNT=$(git notes --ref=mycelium list 2>/dev/null | wc -l | tr -d ' ')
    echo ""
    echo "=== Mycelium Notes ($NOTE_COUNT annotated objects) ==="
    echo "Constraints:"
    mycelium.sh find constraint 2>/dev/null | head -40 || true
    echo ""
    echo "Warnings:"
    mycelium.sh find warning 2>/dev/null | head -40 || true
    echo ""
    # Graph health
    DOCTOR=$(mycelium.sh doctor 2>/dev/null)
    if [ -n "$DOCTOR" ]; then
        STALE_COUNT=$(echo "$DOCTOR" | grep -oE 'stale:[0-9]+' | grep -oE '[0-9]+')
        if [ -n "$STALE_COUNT" ] && [ "$STALE_COUNT" -gt 0 ]; then
            echo "Stale notes: $STALE_COUNT (run: mycelium/scripts/compost-workflow.sh --dry-run)"
        fi
    fi
    echo ""
    echo "Run: mycelium/scripts/context-workflow.sh <file> for file-specific context"
    echo "Run: mycelium.sh prime for full agent primer"
    echo "==================================="
fi

echo "==================================="
exit 0
