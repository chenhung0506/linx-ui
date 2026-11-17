#!/bin/bash
# Deploy linx-ui to linode-server: pull origin/main, rebuild and recreate the container.
#
#   ./deploy.sh        deploy
#   ./deploy.sh -n     dry run: run the local checks and print the remote steps without running them
#
# It deploys what is on origin/main, so merge and push first.
set -euo pipefail

HOST=linode-server
URL=https://linx-ui.linch.uk/flashcard.html
COMPOSE=/usr/local/bin/docker-compose

dry=false
while getopts 'n' opt; do
  case $opt in
    n) dry=true ;;
    *) echo "usage: $0 [-n]" >&2; exit 2 ;;
  esac
done

cd "$(dirname "${BASH_SOURCE[0]}")"

# ---- local checks: deploy only what is committed and pushed ----
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != main ]; then
  echo "on branch '$branch', not main: the server deploys origin/main" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "uncommitted changes (they would not be deployed):" >&2
  git status --short >&2
  exit 1
fi
git fetch -q origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "local main and origin/main differ: git push (or git pull) first" >&2
  exit 1
fi
commit=$(git rev-parse --short HEAD)

# ---- remote: pull, rebuild, recreate ----
remote="set -e
cd ~/linx-ui
git pull --ff-only
# The container belongs to the compose project in ~/reverse-proxy/docker (image only, no build), so build the
# image here under the same tag and recreate the container from there; a compose up in ~/linx-ui would clash on the name.
docker build -q -t ghcr.io/chenhung0506/linx-ui:latest .
cd ~/reverse-proxy/docker
$COMPOSE up -d --force-recreate --pull never linx-ui
sleep 3
docker ps --filter name=^linx-ui\$ --format '{{.Names}} {{.Status}}'
docker image prune -f >/dev/null || true"

echo "== deploying $commit to $HOST"
if $dry; then
  echo "[dry run] ssh $HOST"
  echo "$remote" | sed 's/^/    /'
  echo "[dry run] curl $URL"
  exit 0
fi
ssh -o BatchMode=yes "$HOST" "$remote" 2> >(grep -v 'bashrc' >&2)

# ---- check it from the outside ----
echo "== $URL"
for _ in 1 2 3 4 5; do
  if curl -fsS --max-time 5 "$URL" | grep -q 'og:description'; then
    echo "deployed $commit"
    exit 0
  fi
  sleep 2
done
echo "deployed $commit, but $URL did not serve the new page: check 'ssh $HOST docker logs linx-ui'" >&2
exit 1
