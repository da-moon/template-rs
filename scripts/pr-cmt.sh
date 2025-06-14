#!/bin/bash

# GitHub PR Comments Fetcher with Nested Replies
# Uses GitHub GraphQL API to fetch all comments including nested conversations
# Usage: ./github-pr-comments-graphql.sh [PR_URL]
# Example: ./github-pr-comments-graphql.sh https://github.com/da-moon/gitlab-mr-analyzer/pull/4

set -euo pipefail

# Default PR URL if not provided
PR_URL="${1:-https://github.com/da-moon/gitlab-mr-analyzer/pull/4}"

# Extract owner, repo, and PR number from URL
if [[ "$PR_URL" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    PR_NUMBER="${BASH_REMATCH[3]}"
else
    echo "Error: Invalid GitHub PR URL format" >&2
    echo "Expected format: https://github.com/owner/repo/pull/number" >&2
    exit 1
fi

# Check for GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "Error: GITHUB_TOKEN environment variable is not set" >&2
    exit 1
fi

# GraphQL query to fetch PR comments with nested replies
QUERY=$(cat <<EOF
{
  repository(owner: "$OWNER", name: "$REPO") {
    pullRequest(number: $PR_NUMBER) {
      title
      url
      author {
        login
      }
      createdAt
      
      # Issue comments (general PR comments)
      comments(first: 100) {
        totalCount
        nodes {
          id
          author {
            login
          }
          body
          createdAt
          updatedAt
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
      
      # Review threads (code review comments with replies)
      reviewThreads(first: 100) {
        totalCount
        nodes {
          id
          path
          line
          startLine
          diffSide
          isResolved
          resolvedBy {
            login
          }
          
          # All comments in this thread (including replies)
          comments(first: 100) {
            nodes {
              id
              author {
                login
              }
              body
              createdAt
              updatedAt
              state
              path
              position
              originalPosition
              diffHunk
              replyTo {
                id
              }
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
      
      # Pull request reviews
      reviews(first: 100) {
        totalCount
        nodes {
          id
          author {
            login
          }
          body
          state
          createdAt
          updatedAt
          
          # Review-level comments
          comments(first: 100) {
            nodes {
              id
              author {
                login
              }
              body
              path
              position
              createdAt
              updatedAt
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
}
EOF
)

# Make GraphQL request
echo "Fetching comments for PR: $PR_URL"
echo "Repository: $OWNER/$REPO, PR: #$PR_NUMBER"
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

# Parse and display results
echo "$RESPONSE" | jq -r '
  .data.repository.pullRequest |
  "PR Title: \(.title)\n" +
  "Author: \(.author.login)\n" +
  "Created: \(.createdAt)\n" +
  "URL: \(.url)\n" +
  "\n=== GENERAL COMMENTS (\(.comments.totalCount) total) ===\n" +
  (.comments.nodes[] | 
    "\n[\(.createdAt)] \(.author.login):\n\(.body)\n---"
  ) +
  "\n\n=== REVIEW THREADS (\(.reviewThreads.totalCount) total) ===\n" +
  (.reviewThreads.nodes[] |
    "\nThread in \(.path)" +
    if .line then " (line \(.line))" else "" end +
    if .isResolved then " [RESOLVED by \(.resolvedBy.login)]" else " [OPEN]" end +
    "\n" +
    (.comments.nodes[] |
      "  [\(.createdAt)] \(.author.login):\n" +
      "  \(.body | split("\n") | map("  " + .) | join("\n"))\n"
    ) +
    "---"
  ) +
  "\n\n=== REVIEWS (\(.reviews.totalCount) total) ===\n" +
  (.reviews.nodes[] |
    "\n[\(.createdAt)] \(.author.login) - \(.state):\n\(.body)\n" +
    if (.comments.nodes | length) > 0 then
      "Review comments:\n" +
      (.comments.nodes[] |
        "  In \(.path):\n  \(.body)\n"
      )
    else "" end +
    "---"
  )'

# Save raw JSON response for further processing
OUTPUT_FILE="pr-${PR_NUMBER}-comments.json"
echo "$RESPONSE" | jq '.data.repository.pullRequest' > "$OUTPUT_FILE"
echo -e "\n\nRaw JSON response saved to: $OUTPUT_FILE"

# Summary statistics
echo -e "\n\n=== SUMMARY ==="
echo "$RESPONSE" | jq -r '
  .data.repository.pullRequest |
  "Total general comments: \(.comments.totalCount)\n" +
  "Total review threads: \(.reviewThreads.totalCount)\n" +
  "Total reviews: \(.reviews.totalCount)\n" +
  "Total thread comments: \([.reviewThreads.nodes[].comments.nodes[]] | length)"'