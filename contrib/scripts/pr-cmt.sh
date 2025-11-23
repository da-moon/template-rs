#!/bin/bash

# GitHub PR Comments Fetcher with Nested Replies - Enhanced Version
# Features:
#   - Human-readable output by default with clear visual structure
#   - JSON output available with --json flag
#   - Include/exclude specific authors
#   - Filter resolved/closed threads
#
# Usage: 
#   ./pr-cmt-enhanced.sh [PR_URL] [OPTIONS]
#   ./pr-cmt-enhanced.sh https://github.com/owner/repo/pull/123
#   ./pr-cmt-enhanced.sh https://github.com/owner/repo/pull/123 --json
#
# Options:
#   --include-author AUTHOR  Keep only comments from this author
#   --filter-author AUTHOR   Alias for --include-author
#   --exclude-author AUTHOR  Remove comments from this author
#   --active-only           Filter out resolved review threads
#   --json                  Output full JSON instead of human-readable format
#   --output FILE          Write to file instead of stdout
#   --help                 Show this help message

set -euo pipefail

# Initialize variables
PR_URL=""
EXCLUDE_AUTHORS=()
INCLUDE_AUTHORS=()
JSON_MODE=false
ACTIVE_ONLY=false
OUTPUT_FILE=""
SHOW_HELP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --exclude-author)
            if [[ -n "$2" ]] && [[ ! "$2" =~ ^-- ]]; then
                EXCLUDE_AUTHORS+=("$2")
                shift 2
            else
                echo "Error: --exclude-author requires an argument" >&2
                exit 1
            fi
            ;;
        --include-author|--filter-author)
            if [[ -n "$2" ]] && [[ ! "$2" =~ ^-- ]]; then
                INCLUDE_AUTHORS+=("$2")
                shift 2
            else
                echo "Error: --include-author requires an argument" >&2
                exit 1
            fi
            ;;
        --json)
            JSON_MODE=true
            shift
            ;;
        --active-only)
            ACTIVE_ONLY=true
            shift
            ;;
        --output)
            if [[ -n "$2" ]] && [[ ! "$2" =~ ^-- ]]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                echo "Error: --output requires an argument" >&2
                exit 1
            fi
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            if [[ -z "$PR_URL" ]] && [[ "$1" =~ ^https://github.com/ ]]; then
                PR_URL="$1"
            else
                echo "Unknown option: $1" >&2
                SHOW_HELP=true
            fi
            shift
            ;;
    esac
done

# Show help if requested or if there's an error
if $SHOW_HELP; then
    echo "GitHub PR Comments Fetcher - Enhanced Version"
    echo ""
    echo "Usage:"
    echo "  $0 [PR_URL] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --include-author AUTHOR  Keep only comments from this author"
    echo "  --filter-author AUTHOR   Alias for --include-author (kept for compatibility)"
    echo "  --exclude-author AUTHOR  Remove comments from this author"
    echo "                          All above can be used multiple times"
    echo "  --active-only          Filter out resolved review threads"
    echo "  --json                 Output full JSON instead of human-readable format"
    echo "  --output FILE         Write to file instead of stdout"
    echo "  --help, -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Basic usage - human-readable output"
    echo "  $0 https://github.com/owner/repo/pull/123"
    echo ""
    echo "  # Get full JSON output"
    echo "  $0 https://github.com/owner/repo/pull/123 --json"
    echo ""
    echo "  # Keep only bot comments (e.g., to review AI suggestions)"
    echo "  $0 https://github.com/owner/repo/pull/123 --include-author sourcery-ai"
    echo ""
    echo "  # Exclude bot comments (keep only human comments)"
    echo "  $0 https://github.com/owner/repo/pull/123 --exclude-author sourcery-ai --exclude-author dependabot"
    echo ""
    echo "  # Human-readable output, exclude bots and resolved threads"
    echo "  $0 https://github.com/owner/repo/pull/123 --exclude-author sourcery-ai --active-only"
    echo ""
    echo "  # JSON output with filters"
    echo "  $0 https://github.com/owner/repo/pull/123 --json --include-author user1"
    exit 0
fi

# Default PR URL if not provided
PR_URL="${PR_URL:-https://github.com/da-moon/gitlab-mr-analyzer/pull/4}"

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
      state
      merged
      mergeable
      
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
          minimizedReason
          isMinimized
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
          isOutdated
          isCollapsed
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
              minimizedReason
              isMinimized
              outdated
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
              outdated
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
echo "Fetching comments for PR: $PR_URL" >&2
echo "Repository: $OWNER/$REPO, PR: #$PR_NUMBER" >&2
echo "----------------------------------------" >&2

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

# Extract PR data
PR_DATA=$(echo "$RESPONSE" | jq '.data.repository.pullRequest')

# Build jq filter based on options
JQ_FILTER='.'

# Include only specific authors if specified
if [ ${#INCLUDE_AUTHORS[@]} -gt 0 ]; then
    # Create a jq array from bash array
    INCLUDE_JSON=$(printf '%s\n' "${INCLUDE_AUTHORS[@]}" | jq -R . | jq -s .)
    
    # Filter general comments - keep only from included authors
    JQ_FILTER="$JQ_FILTER | .comments.nodes |= map(select(.author.login as \$author | $INCLUDE_JSON | index(\$author) | . != null))"
    
    # Filter review threads - keep threads where at least one comment is from included authors
    JQ_FILTER="$JQ_FILTER | .reviewThreads.nodes |= map(
        select(
            .comments.nodes | 
            map(.author.login) | 
            map(. as \$author | $INCLUDE_JSON | index(\$author) | . != null) | 
            any
        )
    )"
    
    # Within kept threads, filter to show only comments from included authors
    JQ_FILTER="$JQ_FILTER | .reviewThreads.nodes[].comments.nodes |= map(select(.author.login as \$author | $INCLUDE_JSON | index(\$author) | . != null))"
    
    # Filter reviews - keep only from included authors
    JQ_FILTER="$JQ_FILTER | .reviews.nodes |= map(select(.author.login as \$author | $INCLUDE_JSON | index(\$author) | . != null))"
fi

# Exclude specific authors if specified
if [ ${#EXCLUDE_AUTHORS[@]} -gt 0 ]; then
    # Create a jq array from bash array
    EXCLUDE_JSON=$(printf '%s\n' "${EXCLUDE_AUTHORS[@]}" | jq -R . | jq -s .)
    
    # Filter general comments - remove from excluded authors
    JQ_FILTER="$JQ_FILTER | .comments.nodes |= map(select(.author.login as \$author | $EXCLUDE_JSON | index(\$author) | not))"
    
    # Filter review threads - remove threads where ALL comments are from excluded authors
    JQ_FILTER="$JQ_FILTER | .reviewThreads.nodes |= map(
        select(
            .comments.nodes | 
            map(.author.login) | 
            unique | 
            map(. as \$author | $EXCLUDE_JSON | index(\$author) | not) | 
            any
        )
    )"
    
    # Filter reviews - remove from excluded authors
    JQ_FILTER="$JQ_FILTER | .reviews.nodes |= map(select(.author.login as \$author | $EXCLUDE_JSON | index(\$author) | not))"
fi

# Filter resolved threads if active-only
if $ACTIVE_ONLY; then
    JQ_FILTER="$JQ_FILTER | .reviewThreads.nodes |= map(select(.isResolved | not))"
fi

# Apply filters
FILTERED_DATA=$(echo "$PR_DATA" | jq "$JQ_FILTER")

# Format output based on mode
if $JSON_MODE; then
    # Output as JSON
    OUTPUT="$FILTERED_DATA"
else
    # Create human-readable output
    OUTPUT=$(echo "$FILTERED_DATA" | jq -r '
    def format_date:
        . | split("T")[0] + " " + (. | split("T")[1] | split("Z")[0]);
    
    def draw_line($width):
        "═" * $width;
    
    def draw_box_top($label):
        "┌─ " + $label + " " + ("─" * (76 - ($label | length)));
    
    def draw_box_bottom:
        "└" + ("─" * 78);
    
    # Header
    draw_line(79) + "\n" +
    "PR: " + .title + "\n" +
    "URL: " + .url + "\n" +
    "Author: " + .author.login + " | Created: " + (.createdAt | format_date) + "\n" +
    "Status: " + .state + " | Merged: " + (.merged | tostring) + "\n" +
    draw_line(79) + "\n\n" +
    
    # Review Threads
    if (.reviewThreads.nodes | length) > 0 then
        (.reviewThreads.nodes | to_entries | map(
            . as $thread |
            draw_line(79) + "\n" +
            "REVIEW THREAD #" + (($thread.key + 1) | tostring) + " - " + $thread.value.path + 
            (if $thread.value.line then ":" + ($thread.value.line | tostring) else "" end) +
            (if $thread.value.startLine and $thread.value.startLine != $thread.value.line then "-" + ($thread.value.startLine | tostring) else "" end) + "\n" +
            "Status: " + (if $thread.value.isResolved then "RESOLVED" else "UNRESOLVED" end) + 
            (if $thread.value.resolvedBy then " by @" + $thread.value.resolvedBy.login else "" end) + "\n" +
            draw_line(79) + "\n\n" +
            
            ($thread.value.comments.nodes | to_entries | map(
                . as $comment |
                draw_box_top("Comment " + (($thread.key + 1) | tostring) + "." + (($comment.key + 1) | tostring)) + "\n" +
                "│ Author: @" + $comment.value.author.login + "\n" +
                "│ Date: " + ($comment.value.createdAt | format_date) + "\n" +
                "│ Type: " + (if $comment.key == 0 then "Thread starter" 
                    elif $comment.value.replyTo then "Reply to comment ID: " + $comment.value.replyTo.id
                    else "Reply" end) + "\n" +
                (if $comment.value.state then "│ State: " + $comment.value.state + "\n" else "" end) +
                (if $comment.value.position then "│ Position: " + ($comment.value.position | tostring) + "\n" else "" end) +
                draw_box_bottom + "\n\n" +
                $comment.value.body + "\n\n"
            ) | join("")) +
            (if ($thread.value.comments.nodes | length) == 1 then
                "Note: This thread currently has only one comment. Replies may appear here when added.\n\n"
            else "" end)
        ) | join("\n"))
    else "" end +
    
    # General PR Comments
    if (.comments.nodes | length) > 0 then
        "\n" + 
        (.comments.nodes | to_entries | map(
            draw_line(79) + "\n" +
            "PR COMMENT #" + ((.key + 1) | tostring) + "\n" +
            draw_line(79) + "\n\n" +
            
            draw_box_top("Metadata") + "\n" +
            "│ Author: @" + .value.author.login + "\n" +
            "│ Date: " + (.value.createdAt | format_date) + "\n" +
            "│ Type: General PR comment" + "\n" +
            draw_box_bottom + "\n\n" +
            .value.body + "\n\n"
        ) | join(""))
    else "" end +
    
    # Reviews
    if (.reviews.nodes | length) > 0 then
        "\n" +
        (.reviews.nodes | to_entries | map(
            draw_line(79) + "\n" +
            "REVIEW #" + ((.key + 1) | tostring) + " - " + .value.state + "\n" +
            draw_line(79) + "\n\n" +
            
            draw_box_top("Metadata") + "\n" +
            "│ Author: @" + .value.author.login + "\n" +
            "│ Date: " + (.value.createdAt | format_date) + "\n" +
            "│ Type: Pull Request Review" + "\n" +
            "│ State: " + .value.state + "\n" +
            draw_box_bottom + "\n\n" +
            (if .value.body and .value.body != "" then .value.body + "\n\n" else "" end) +
            
            (if (.value.comments.nodes | length) > 0 then
                "Review includes inline code comments:\n\n" +
                (.value.comments.nodes | to_entries | map(
                    . as $comment |
                    draw_box_top("Review Comment " + ((.key + 1) | tostring)) + "\n" +
                    "│ File: " + $comment.value.path + "\n" +
                    (if $comment.value.position then "│ Position: " + ($comment.value.position | tostring) + "\n" else "" end) +
                    draw_box_bottom + "\n\n" +
                    $comment.value.body + "\n\n"
                ) | join(""))
            else "" end)
        ) | join("\n"))
    else "" end
    ')
fi

# Output to file or stdout
if [ -n "$OUTPUT_FILE" ]; then
    echo "$OUTPUT" > "$OUTPUT_FILE"
    echo "Output written to: $OUTPUT_FILE" >&2
else
    echo "$OUTPUT"
fi

# Show summary statistics on stderr
echo "" >&2
echo "=== SUMMARY ===" >&2
echo "$FILTERED_DATA" | jq -r '
  "Total general comments: \(.comments.totalCount // 0)
Filtered general comments: \(.comments.nodes | length)
Total review threads: \(.reviewThreads.totalCount // 0)
Filtered review threads: \(.reviewThreads.nodes | length)
Active review threads: \(.reviewThreads.nodes | map(select(.isResolved | not)) | length)
Total reviews: \(.reviews.totalCount // 0)
Filtered reviews: \(.reviews.nodes | length)"' >&2
