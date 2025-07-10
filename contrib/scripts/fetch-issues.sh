#!/bin/bash

# GitHub Issues Fetcher
# Uses GitHub GraphQL API to fetch all open issues and save them as markdown files
# Usage: ./github-issues-fetcher.sh [REPO_URL]
# Example: ./github-issues-fetcher.sh https://github.com/da-moon/eibon-rs-codex

set -euo pipefail

# Check if repo URL is provided
if [ $# -eq 0 ]; then
    echo "Error: Repository URL is required" >&2
    echo "Usage: $0 REPO_URL" >&2
    echo "Example: $0 https://github.com/owner/repo" >&2
    exit 1
fi

REPO_URL="$1"

# Customizable output directory via environment variable
OUTPUT_DIR="${GITHUB_ISSUES_OUTPUT_DIR:-.github/issues}"

# Extract owner and repo from URL
if [[ "$REPO_URL" =~ github\.com/([^/]+)/([^/]+)/?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo "Error: Invalid GitHub repository URL format" >&2
    echo "Expected format: https://github.com/owner/repo" >&2
    exit 1
fi

# Check for GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "Error: GITHUB_TOKEN environment variable is not set" >&2
    exit 1
fi

# GraphQL query to fetch all open issues with full details
QUERY=$(cat <<EOF
{
  repository(owner: "$OWNER", name: "$REPO") {
    issues(states: OPEN, first: 100, orderBy: {field: CREATED_AT, direction: DESC}) {
      totalCount
      nodes {
        number
        title
        body
        url
        state
        createdAt
        updatedAt
        closedAt
        author {
          login
          url
        }
        assignees(first: 10) {
          nodes {
            login
            url
          }
        }
        labels(first: 20) {
          nodes {
            name
            color
            description
          }
        }
        milestone {
          title
          description
          url
          dueOn
        }
        comments(first: 100) {
          totalCount
          nodes {
            author {
              login
              url
            }
            body
            createdAt
            updatedAt
            url
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
EOF
)

# Make GraphQL request
echo "Fetching open issues for repository: $REPO_URL"
echo "Repository: $OWNER/$REPO"
echo "Output directory: $OUTPUT_DIR"
echo "----------------------------------------"

RESPONSE=$(curl -s -H "Authorization: bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$(jq -n --arg query "$QUERY" '{query: $query}')" \
  https://api.github.com/graphql)

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' >/dev/null 2>&1; then
    echo "GraphQL Error:" >&2
    echo "$RESPONSE" | jq '.errors' >&2
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Parse and save each issue as a markdown file
echo "$RESPONSE" | jq -c '.data.repository.issues.nodes[]' | while IFS= read -r issue; do
    # Extract issue data
    ISSUE_NUMBER=$(echo "$issue" | jq -r '.number')
    ISSUE_TITLE=$(echo "$issue" | jq -r '.title')
    ISSUE_BODY=$(echo "$issue" | jq -r '.body // ""')
    ISSUE_URL=$(echo "$issue" | jq -r '.url')
    ISSUE_STATE=$(echo "$issue" | jq -r '.state')
    ISSUE_CREATED=$(echo "$issue" | jq -r '.createdAt')
    ISSUE_UPDATED=$(echo "$issue" | jq -r '.updatedAt')
    ISSUE_AUTHOR=$(echo "$issue" | jq -r '.author.login // "unknown"')
    ISSUE_AUTHOR_URL=$(echo "$issue" | jq -r '.author.url // ""')
    
    # Create markdown file
    ISSUE_FILE="$OUTPUT_DIR/${ISSUE_NUMBER}.md"
    
    cat > "$ISSUE_FILE" <<EOF
# $ISSUE_TITLE

**Issue #$ISSUE_NUMBER**

- **State:** $ISSUE_STATE
- **Author:** [$ISSUE_AUTHOR]($ISSUE_AUTHOR_URL)
- **Created:** $ISSUE_CREATED
- **Updated:** $ISSUE_UPDATED
- **URL:** $ISSUE_URL

EOF

    # Add assignees if any
    ASSIGNEES=$(echo "$issue" | jq -r '.assignees.nodes[]? | "- [@\(.login)](\(.url))"')
    if [ -n "$ASSIGNEES" ]; then
        cat >> "$ISSUE_FILE" <<EOF
## Assignees

$ASSIGNEES

EOF
    fi

    # Add labels if any
    LABELS=$(echo "$issue" | jq -r '.labels.nodes[]? | "- **\(.name)** \(if .description then "- \(.description)" else "" end)"')
    if [ -n "$LABELS" ]; then
        cat >> "$ISSUE_FILE" <<EOF
## Labels

$LABELS

EOF
    fi

    # Add milestone if any
    MILESTONE_TITLE=$(echo "$issue" | jq -r '.milestone.title // ""')
    if [ -n "$MILESTONE_TITLE" ] && [ "$MILESTONE_TITLE" != "null" ]; then
        MILESTONE_DESC=$(echo "$issue" | jq -r '.milestone.description // ""')
        MILESTONE_URL=$(echo "$issue" | jq -r '.milestone.url // ""')
        MILESTONE_DUE=$(echo "$issue" | jq -r '.milestone.dueOn // ""')
        
        cat >> "$ISSUE_FILE" <<EOF
## Milestone

**[$MILESTONE_TITLE]($MILESTONE_URL)**

EOF
        if [ -n "$MILESTONE_DESC" ] && [ "$MILESTONE_DESC" != "null" ]; then
            echo "$MILESTONE_DESC" >> "$ISSUE_FILE"
            echo "" >> "$ISSUE_FILE"
        fi
        if [ -n "$MILESTONE_DUE" ] && [ "$MILESTONE_DUE" != "null" ]; then
            echo "**Due:** $MILESTONE_DUE" >> "$ISSUE_FILE"
            echo "" >> "$ISSUE_FILE"
        fi
    fi

    # Add issue body
    if [ -n "$ISSUE_BODY" ] && [ "$ISSUE_BODY" != "null" ]; then
        cat >> "$ISSUE_FILE" <<EOF
## Description

$ISSUE_BODY

EOF
    fi

    # Add comments if any
    COMMENTS_COUNT=$(echo "$issue" | jq -r '.comments.totalCount')
    if [ "$COMMENTS_COUNT" -gt 0 ]; then
        cat >> "$ISSUE_FILE" <<EOF
## Comments ($COMMENTS_COUNT)

EOF
        echo "$issue" | jq -r '.comments.nodes[] | "### [\(.author.login)](\(.author.url // "")) - \(.createdAt)\n\n\(.body)\n\n---\n"' >> "$ISSUE_FILE"
    fi

    echo "Saved issue #$ISSUE_NUMBER: $ISSUE_TITLE"
done

# Summary statistics
TOTAL_ISSUES=$(echo "$RESPONSE" | jq -r '.data.repository.issues.totalCount')
echo "----------------------------------------"
echo "Summary:"
echo "Total open issues: $TOTAL_ISSUES"
echo "Issues saved to: $OUTPUT_DIR/"
echo "Use GITHUB_ISSUES_OUTPUT_DIR environment variable to customize output directory"
