#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG_ENV="$(pwd)/config.env"
SECRETS_ENC="$(pwd)/secrets.env"
SECRETS_TMP="$(mktemp --tmpdir="$(pwd)" .secrets.env.XXXXXX)"
chmod 600 "$SECRETS_TMP"
trap 'rm -f "$SECRETS_TMP"' EXIT

echo "==> Decrypting secrets..."
sops --decrypt --input-type dotenv --output-type dotenv "$SECRETS_ENC" > "$SECRETS_TMP"

echo "==> Pulling images..."
docker compose --env-file "$CONFIG_ENV" --env-file "$SECRETS_TMP" pull --quiet

echo "==> Starting services..."
docker compose --env-file "$CONFIG_ENV" --env-file "$SECRETS_TMP" up -d --remove-orphans

echo "==> Cleaning up old images..."
docker image prune -f

echo "==> Deploy complete"
