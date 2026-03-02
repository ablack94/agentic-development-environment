#!/usr/bin/env bash

gitea_host="${GITEA_HOST}"
gitea_access_token="${GITEA_ACCESS_TOKEN}"
if [[ -z "${gitea_access_token}" && ! -z "${GITEA_ACCESS_TOKEN_PATH}" ]]; then
    gitea_access_token="$(cat "${GITEA_ACCESS_TOKEN_PATH}")"
fi

if [[ -z "${gitea_host}" || -z "${gitea_access_token}" ]]; then
    echo "GITEA_HOST and GITEA_ACCESS_TOKEN/GITEA_ACCESS_TOKEN_PATH must both be set!">&2
    exit 1
fi

/usr/local/bin/claude mcp add \
    --transport stdio \
    --scope user \
    gitea \
    --env GITEA_HOST="${gitea_host}" \
    --env GITEA_ACCESS_TOKEN="${gitea_access_token}" \
    -- /usr/local/bin/gitea-mcp -t stdio

# Make the user-level CLAUDE.md file
cat /etc/agent/prompts/*.md > ~/.claude/CLAUDE.md

exec "$@"
