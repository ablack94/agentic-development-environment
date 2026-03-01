#!/bin/sh
set -e

# --- Start Gitea in the background via the original entrypoint ---
/usr/local/bin/docker-entrypoint.sh &
GITEA_PID=$!

# Forward signals to the Gitea process
trap "kill -TERM $GITEA_PID 2>/dev/null" TERM INT QUIT

# --- Wait for Gitea to become healthy ---
echo "[setup] Waiting for Gitea to start..."
retries=0
max_retries=60
until curl -sf http://localhost:3000/api/healthz > /dev/null 2>&1; do
  retries=$((retries + 1))
  if [ "$retries" -ge "$max_retries" ]; then
    echo "[setup] ERROR: Gitea did not become healthy after ${max_retries}s"
    exit 1
  fi
  sleep 1
done
echo "[setup] Gitea is healthy."

# --- Create admin user (idempotent) ---
echo "[setup] Creating admin user '${GITEA_ADMIN_USER}'..."
gitea admin user create \
  --admin \
  --username "${GITEA_ADMIN_USER}" \
  --password "${GITEA_ADMIN_PASSWORD}" \
  --email "${GITEA_ADMIN_EMAIL}" \
  --must-change-password=false 2>&1 || {
    # Exit code 1 with "user already exists" is fine
    echo "[setup] Admin user already exists, skipping."
  }

# --- Create API token (idempotent) ---
TOKEN_NAME="auto-setup"
echo "[setup] Creating API token '${TOKEN_NAME}'..."

# Check if token already exists by listing tokens
EXISTING=$(curl -sf \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
  "http://localhost:3000/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
  | grep -o "\"${TOKEN_NAME}\"" || true)

if [ -n "$EXISTING" ]; then
  echo "[setup] Token '${TOKEN_NAME}' already exists."
  # If we already wrote the token file previously, keep it
  if [ -f /shared/gitea-token ]; then
    TOKEN=$(cat /shared/gitea-token)
    echo "[setup] Using existing token from /shared/gitea-token"
  else
    echo "[setup] WARNING: Token exists but /shared/gitea-token is missing."
    echo "[setup] Deleting old token and recreating..."
    curl -sf -X DELETE \
      -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
      "http://localhost:3000/api/v1/users/${GITEA_ADMIN_USER}/tokens/${TOKEN_NAME}"
    EXISTING=""
  fi
fi

if [ -z "$EXISTING" ]; then
  RESPONSE=$(curl -sf \
    -X POST \
    -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${TOKEN_NAME}\", \"scopes\": [\"all\"]}" \
    "http://localhost:3000/api/v1/users/${GITEA_ADMIN_USER}/tokens")

  TOKEN=$(echo "$RESPONSE" | sed 's/.*"sha1":"\([^"]*\)".*/\1/')
  # If sha1 didn't match, try the newer token format
  if [ "$TOKEN" = "$RESPONSE" ]; then
    TOKEN=$(echo "$RESPONSE" | sed 's/.*"token":"\([^"]*\)".*/\1/')
  fi

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "$RESPONSE" ]; then
    echo "[setup] ERROR: Failed to extract token from response: $RESPONSE"
    exit 1
  fi

  echo "$TOKEN" > /shared/gitea-token
  echo "[setup] API token created and saved to /shared/gitea-token"
fi

# --- Create sample repository (idempotent) ---
REPO_NAME="sample-repo"
echo "[setup] Creating sample repository '${REPO_NAME}'..."

REPO_CHECK=$(curl -sf \
  -H "Authorization: token ${TOKEN}" \
  "http://localhost:3000/api/v1/repos/${GITEA_ADMIN_USER}/${REPO_NAME}" 2>/dev/null) || true

if echo "$REPO_CHECK" | grep -q "\"name\":\"${REPO_NAME}\""; then
  echo "[setup] Repository '${REPO_NAME}' already exists, skipping."
else
  curl -sf \
    -X POST \
    -H "Authorization: token ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${REPO_NAME}\", \"auto_init\": true, \"default_branch\": \"main\"}" \
    "http://localhost:3000/api/v1/user/repos" > /dev/null
  echo "[setup] Repository '${REPO_NAME}' created."
fi

echo "[setup] =========================================="
echo "[setup] Setup complete!"
echo "[setup] Gitea URL: http://gitea:3000"
echo "[setup] Admin user: ${GITEA_ADMIN_USER}"
echo "[setup] API token: ${TOKEN}"
echo "[setup] Sample repo: http://gitea:3000/${GITEA_ADMIN_USER}/${REPO_NAME}.git"
echo "[setup] =========================================="

# --- Wait on the Gitea process ---
wait $GITEA_PID
