#!/usr/bin/env bash
# Generate patch file showing differences between two branches

set -euo pipefail

# Function to display usage
usage() {
    cat << EOF
Usage: $0 --src <source-branch> --dest <destination-branch> --output <patch-file> [--exclude <scope-file>]

Options:
    --src     Source branch with changes
    --dest    Destination branch (base)
    --output  Output patch file path
    --exclude Path to scope.json file - only include changes to files NOT in scope

Examples:
    # All changes
    $0 --src feature/TASK-0001-errors --dest work --output .agents/phase-0/TASK-0001/errors/fix.patch
    
    # Out-of-scope changes only
    $0 --src feature/TASK-0001-errors --dest work --output .agents/phase-0/TASK-0001/errors/fix.patch --exclude .agents/phase-0/TASK-0001/scope.json

Description:
    Generates a patch file containing changes from destination to source branch.
    The patch can be applied to destination branch to incorporate source changes.
    Use --exclude to generate patches with only out-of-scope changes.
EOF
    exit 1
}

# Parse command line arguments
SRC_BRANCH=""
DEST_BRANCH=""
OUTPUT_FILE=""
EXCLUDE_SCOPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --src)
            SRC_BRANCH="$2"
            shift 2
            ;;
        --dest)
            DEST_BRANCH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_SCOPE="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [[ -z "$SRC_BRANCH" || -z "$DEST_BRANCH" || -z "$OUTPUT_FILE" ]]; then
    echo "Error: All arguments are required"
    usage
fi

echo "Patch generation configuration:"
echo "  Source branch: $SRC_BRANCH"
echo "  Destination branch: $DEST_BRANCH"
echo "  Output file: $OUTPUT_FILE"
if [[ -n "$EXCLUDE_SCOPE" ]]; then
    echo "  Exclude scope: $EXCLUDE_SCOPE"
fi

# Verify branches exist
if ! git rev-parse --verify "$SRC_BRANCH" >/dev/null 2>&1; then
    echo "Error: Source branch not found: $SRC_BRANCH"
    exit 1
fi

if ! git rev-parse --verify "$DEST_BRANCH" >/dev/null 2>&1; then
    echo "Error: Destination branch not found: $DEST_BRANCH"
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Generate patch
echo "Generating patch..."

if [[ -n "$EXCLUDE_SCOPE" ]]; then
    # Validate exclude scope file exists
    if [[ ! -f "$EXCLUDE_SCOPE" ]]; then
        echo "Error: Exclude scope file not found: $EXCLUDE_SCOPE"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required to parse JSON scope file. Please install jq."
        exit 1
    fi
    
    # Read files to exclude from scope.json
    EXCLUDED_FILES=$(jq -r '.files[]' "$EXCLUDE_SCOPE" 2>/dev/null)
    if [[ -z "$EXCLUDED_FILES" ]]; then
        echo "Warning: No files found in exclude scope or invalid JSON format"
        # Fall back to generating all changes
        git diff "$DEST_BRANCH".."$SRC_BRANCH" > "$OUTPUT_FILE"
    else
        echo "Excluding files from patch:"
        echo "$EXCLUDED_FILES" | sed 's/^/  - /'
        
        # Get all changed files
        ALL_CHANGED_FILES=$(git diff --name-only "$DEST_BRANCH".."$SRC_BRANCH")
        
        # Filter out excluded files
        INCLUDED_FILES=""
        for file in $ALL_CHANGED_FILES; do
            if ! echo "$EXCLUDED_FILES" | grep -q "^$file$"; then
                INCLUDED_FILES="$INCLUDED_FILES $file"
            fi
        done
        
        if [[ -z "$INCLUDED_FILES" ]]; then
            echo "Warning: No files to include in patch after exclusions"
            # Create empty patch file
            touch "$OUTPUT_FILE"
        else
            echo "Including files in patch:"
            echo "$INCLUDED_FILES" | tr ' ' '\n' | sed 's/^/  + /'
            
            # Generate patch for only included files
            git diff "$DEST_BRANCH".."$SRC_BRANCH" -- $INCLUDED_FILES > "$OUTPUT_FILE"
        fi
    fi
else
    # Generate patch for all changes
    git diff "$DEST_BRANCH".."$SRC_BRANCH" > "$OUTPUT_FILE"
fi

# Check if patch is empty
if [[ ! -s "$OUTPUT_FILE" ]]; then
    echo "Warning: No differences found between branches"
    rm "$OUTPUT_FILE"
    exit 0
fi

# Get patch statistics
PATCH_STATS=$(git diff --stat "$DEST_BRANCH".."$SRC_BRANCH")
LINE_COUNT=$(wc -l < "$OUTPUT_FILE")

echo "Patch generated successfully!"
echo "  File: $OUTPUT_FILE"
echo "  Size: $(wc -c < "$OUTPUT_FILE") bytes"
echo "  Lines: $LINE_COUNT"
echo ""
echo "Changes summary:"
echo "$PATCH_STATS"
echo ""
echo "To apply this patch:"
echo "  git checkout $DEST_BRANCH"
echo "  git apply $OUTPUT_FILE"
echo ""
echo "To apply with 3-way merge:"
echo "  git checkout $DEST_BRANCH"
echo "  git apply --3way $OUTPUT_FILE"