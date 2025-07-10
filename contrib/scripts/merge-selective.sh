#!/usr/bin/env bash
# Selective merge script - merges changes from source branch to destination
# while respecting file scope constraints defined in a JSON file

set -euo pipefail

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 --src <source-branch> --dest <destination-branch> --scope <scope-json-file>

Options:
    --src    Source branch to merge from
    --dest   Destination branch to merge to
    --scope  Path to scope.json file containing allowed files

Example:
    $0 --src feature/TASK-0001-errors --dest work --scope .agents/phase-0/TASK-0001/scope.json

Scope file format:
    {
        "files": ["src/main.rs", "src/lib.rs", "tests/integration.rs"]
    }
EOF
    exit 1
}

# Parse command line arguments
SRC_BRANCH=""
DEST_BRANCH=""
SCOPE_FILE=""

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
        --scope)
            SCOPE_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [[ -z "$SRC_BRANCH" || -z "$DEST_BRANCH" || -z "$SCOPE_FILE" ]]; then
    echo "Error: All arguments are required"
    usage
fi

if [[ ! -f "$SCOPE_FILE" ]]; then
    echo "Error: Scope file not found: $SCOPE_FILE"
    exit 1
fi

echo "Selective merge configuration:"
echo "  Source branch: $SRC_BRANCH"
echo "  Destination branch: $DEST_BRANCH"
echo "  Scope file: $SCOPE_FILE"

# Check if jq is available
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required to parse JSON. Please install jq."
    exit 1
fi

# Read allowed files from scope.json
echo "Reading scope file..."
ALLOWED_FILES=$(jq -r '.files[]' "$SCOPE_FILE" 2>/dev/null)
if [[ -z "$ALLOWED_FILES" ]]; then
    echo "Error: No files found in scope.json or invalid JSON format"
    exit 1
fi

echo "Files in scope:"
echo "$ALLOWED_FILES" | sed 's/^/  - /'

# Verify branches exist
if ! git rev-parse --verify "$SRC_BRANCH" >/dev/null 2>&1; then
    echo "Error: Source branch not found: $SRC_BRANCH"
    exit 1
fi

if ! git rev-parse --verify "$DEST_BRANCH" >/dev/null 2>&1; then
    echo "Error: Destination branch not found: $DEST_BRANCH"
    exit 1
fi

# Save current branch
ORIGINAL_BRANCH=$(git branch --show-current)

# Ensure we're on destination branch
echo "Checking out destination branch: $DEST_BRANCH"
git checkout "$DEST_BRANCH"

# Clean working directory and staging area to ensure a clean state
echo "Cleaning working directory..."
git reset --hard HEAD
git clean -fd

# Get list of all files modified in source branch
echo "Analyzing changes in $SRC_BRANCH..."
CHANGED_FILES=$(git diff --name-only "$DEST_BRANCH".."$SRC_BRANCH")

if [[ -z "$CHANGED_FILES" ]]; then
    echo "No changes found between branches"
    exit 0
fi

echo "Changed files:"
echo "$CHANGED_FILES" | sed 's/^/  - /'

# Start merge without committing
echo "Starting merge from $SRC_BRANCH..."
if ! git merge --no-commit --no-ff "$SRC_BRANCH"; then
    # If merge fails, check if it's due to conflicts or other issues
    if git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
        echo "Merge conflicts detected, proceeding with selective merge..."
    else
        echo "Error: Merge failed for reasons other than conflicts"
        git merge --abort 2>/dev/null || true
        exit 1
    fi
fi

# Reset all files to destination branch state
echo "Resetting all files to $DEST_BRANCH state..."
git reset HEAD
git checkout -- . 2>/dev/null || true

# Selectively stage only allowed files
echo "Selectively staging allowed files..."
STAGED_COUNT=0

# Process each changed file
for file in $CHANGED_FILES; do
    if echo "$ALLOWED_FILES" | grep -q "^$file$"; then
        echo "  Processing in-scope file: $file"
        
        # Check if file exists in source branch
        if git show "$SRC_BRANCH:$file" > /dev/null 2>&1; then
            # File exists in source, extract it
            mkdir -p "$(dirname "$file")"
            git show "$SRC_BRANCH:$file" > "$file"
            git add "$file"
            STAGED_COUNT=$(($STAGED_COUNT + 1))
            echo "    Staged: $file"
        else
            # File was deleted in source branch
            if [[ -f "$file" ]]; then
                git rm "$file"
                STAGED_COUNT=$(($STAGED_COUNT + 1))
                echo "    Deleted: $file"
            fi
        fi
    else
        echo "  Skipping (out of scope): $file"
        # Ensure file is at destination branch state
        if git show "$DEST_BRANCH:$file" > /dev/null 2>&1; then
            # File exists in destination, restore it
            git show "$DEST_BRANCH:$file" > "$file"
        else
            # File doesn't exist in destination, remove it
            rm -f "$file"
        fi
    fi
done

if [[ $STAGED_COUNT -eq 0 ]]; then
    echo "No files to merge within scope constraints"
    git merge --abort 2>/dev/null || true
    exit 0
fi

# Commit the selective merge
echo "Committing selective merge ($STAGED_COUNT files)..."
COMMIT_MSG="Selective merge from $SRC_BRANCH to $DEST_BRANCH

Scope: $SCOPE_FILE
Files merged: $STAGED_COUNT"

git commit -m "$COMMIT_MSG"

echo "Selective merge completed successfully!"
echo "Merged $STAGED_COUNT files from $SRC_BRANCH to $DEST_BRANCH"

# Return to original branch if different
if [[ "$ORIGINAL_BRANCH" != "$DEST_BRANCH" ]]; then
    echo "Returning to original branch: $ORIGINAL_BRANCH"
    git checkout "$ORIGINAL_BRANCH"
fi