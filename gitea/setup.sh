#!/bin/sh

# --- Start Gitea in the background via the original entrypoint ---
/usr/local/bin/docker-entrypoint.sh &
GITEA_PID=$!

# Forward signals to the Gitea process
trap "kill -TERM $GITEA_PID 2>/dev/null" TERM INT QUIT

# Wait for gitea to be up
until curl -fsS "${GITEA__server__ROOT_URL}api/healthz" >/dev/null; do
  sleep 1
done
echo "Gitea is up"

# --- Create admin user (idempotent) ---
admin_user="${GITEA_ADMIN_USER:-admin}"
echo "[setup] Creating admin user '${admin_user}'..."
gitea admin user create \
  --admin \
  --username "${admin_user}" \
  --password "${GITEA_ADMIN_PASSWORD:-admin}" \
  --email "${GITEA_ADMIN_EMAIL:-admin@localhost}" \
  --must-change-password=false 2>&1
rc="$?"
echo "rc=${rc}"
case $? in
  0)
    echo "[setup] Created admin user."
    ;;
  1)
    echo "[setup] Admin already exists."
    ;;
  *)
    echo "[setup] Failed to create admin!"
    exit 1
    ;;
esac

# --- Create mark user
echo "[setup] Creating 'mark' ..."
gitea admin user create \
  --username mark \
  --password 79f725c5adf1dc6631e99125aa17fbbe5e722c331c55cb723362fcb67af330fd \
  --email mark@localhost \
  --must-change-password=false

# TODO: Not very durable, but good enough for ephemeral steups. Use REST API with curl for more durability
mark_pat=$(gitea admin user generate-access-token \
  --username mark \
  --token-name mark-access-token \
  --scopes all \
  --raw)
if [[ ! -z "${mark_pat}" ]]; then
  echo -n "${mark_pat}" > /shared/gitea-token-mark
fi


wait $GITEA_PID
