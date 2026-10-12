#!/usr/bin/env bash
set -euo pipefail
set +x

namespace="bird-observation"

if [ "$(kubectl config current-context)" != "bird-observation-dev" ]; then
  echo "Wrong Kubernetes context. Select bird-observation-dev first."
  exit 1
fi

for name in bird-mongodb-secrets bird-backend-secrets; do
  if kubectl -n "$namespace" get secret "$name" >/dev/null 2>&1; then
    echo "$name already exists. Stop here to avoid changing database credentials."
    exit 1
  fi
done

umask 077
secret_dir="$(mktemp -d)"
trap 'rm -rf "$secret_dir"' EXIT

printf '%s' 'mongo-admin' > "$secret_dir/root-username"
printf '%s' "$(openssl rand -hex 32)" > "$secret_dir/root-password"
printf '%s' 'birdapp' > "$secret_dir/app-username"
printf '%s' "$(openssl rand -hex 32)" > "$secret_dir/app-password"
printf '%s' "$(openssl rand -hex 48)" > "$secret_dir/jwt-secret"

printf 'mongodb://birdapp:%s@mongodb:27017/bird_observation_db?authSource=bird_observation_db' \
  "$(cat "$secret_dir/app-password")" > "$secret_dir/mongodb-uri"

kubectl -n "$namespace" create secret generic bird-mongodb-secrets \
  --from-file=MONGO_ROOT_USERNAME="$secret_dir/root-username" \
  --from-file=MONGO_ROOT_PASSWORD="$secret_dir/root-password" \
  --from-file=MONGO_APP_USERNAME="$secret_dir/app-username" \
  --from-file=MONGO_APP_PASSWORD="$secret_dir/app-password"

kubectl -n "$namespace" create secret generic bird-backend-secrets \
  --from-file=MONGODB_URI="$secret_dir/mongodb-uri" \
  --from-file=JWT_SECRET="$secret_dir/jwt-secret"

echo "Application secrets created."
