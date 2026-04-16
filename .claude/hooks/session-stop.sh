#!/bin/bash
# Claude Code Stop hook: Log session summary when Claude finishes
# Records what was worked on for audit trail and sprint tracking

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_LOG_DIR="production/session-logs"

mkdir -p "$SESSION_LOG_DIR" 2>/dev/null

# Log recent git activity from this session (check up to 8 hours for long sessions)
RECENT_COMMITS=$(git log --oneline --since="8 hours ago" 2>/dev/null)
MODIFIED_FILES=$(git diff --name-only 2>/dev/null)

# --- Clean up active session state on normal shutdown ---
STATE_FILE="production/session-state/active.md"
if [ -f "$STATE_FILE" ]; then
    # Archive to session log before removing
    {
        echo "## Archived Session State: $TIMESTAMP"
        cat "$STATE_FILE"
        echo "---"
        echo ""
    } >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
    rm "$STATE_FILE" 2>/dev/null
fi

if [ -n "$RECENT_COMMITS" ] || [ -n "$MODIFIED_FILES" ]; then
    {
        echo "## Session End: $TIMESTAMP"
        if [ -n "$RECENT_COMMITS" ]; then
            echo "### Commits"
            echo "$RECENT_COMMITS"
        fi
        if [ -n "$MODIFIED_FILES" ]; then
            echo "### Uncommitted Changes"
            echo "$MODIFIED_FILES"
        fi
        echo "---"
        echo ""
    } >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
fi

# --- Mycelium: departure protocol ---
if command -v mycelium.sh &>/dev/null && git notes --ref=mycelium list &>/dev/null 2>&1; then
    TRACKING_FILE="production/session-state/.mycelium-touched"

    # Report files that were touched but may lack departure notes
    if [ -f "$TRACKING_FILE" ]; then
        TOUCHED_FILES=$(sort -u "$TRACKING_FILE" 2>/dev/null)
        UNANNOTATED=""
        while IFS= read -r filepath; do
            [ -z "$filepath" ] && continue
            # Check if the file has a current-version blob note
            BLOB_OID=$(git rev-parse "HEAD:${filepath}" 2>/dev/null) || continue
            HAS_NOTE=$(git notes --ref=mycelium show "$BLOB_OID" 2>/dev/null)
            if [ -z "$HAS_NOTE" ]; then
                UNANNOTATED="$UNANNOTATED  $filepath\n"
            fi
        done <<< "$TOUCHED_FILES"

        if [ -n "$UNANNOTATED" ]; then
            {
                echo ""
                echo "## Mycelium — Un-annotated Files"
                echo "These files were edited this session but have no mycelium note on their current blob:"
                printf "%b" "$UNANNOTATED"
                echo "Next session should annotate these."
            } >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
        fi

        # Reset tracking file for next session
        rm -f "$TRACKING_FILE" 2>/dev/null
    fi

    # Report stale note count for awareness
    DOCTOR_OUTPUT=$(mycelium.sh doctor 2>/dev/null)
    if [ -n "$DOCTOR_OUTPUT" ]; then
        echo "" >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
        echo "## Mycelium Doctor" >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
        echo "$DOCTOR_OUTPUT" >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
    fi
fi

exit 0
