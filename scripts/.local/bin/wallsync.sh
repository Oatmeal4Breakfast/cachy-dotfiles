#!/bin/bash

set -eou pipefail

LOCAL_WALLPAPERS="$HOME/Pictures/wallpapers/"
DESTINATION_SERVER="thoughts-server.tail53451c.ts.net"
DESTINATION="thoughts@$DESTINATION_SERVER:~/wallpapers"

echo "Syncing directories"

if ! tailscale ping "$DESTINATION_SERVER" >/dev/null 2>&1; then
  echo "Destination unreachable"
  exit 1
fi

LOCKFILE="/tmp/wall-sync.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "already running"
  exit 1
fi

rsync -az "$LOCAL_WALLPAPERS" "$DESTINATION"
rsync -az "$DESTINATION/" "$LOCAL_WALLPAPERS"
