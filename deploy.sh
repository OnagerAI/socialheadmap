#!/usr/bin/env bash
set -e

EC2="ubuntu@100.77.243.73"
FLUTTER="/home/artur/flutter/bin/flutter"
APP_DIR="$(dirname "$0")/app"
BACKEND_DIR="$(dirname "$0")/backend"

echo "=== 1/4 Flutter Web Build ==="
cd "$APP_DIR"
$FLUTTER build web --release --no-web-resources-cdn

echo "=== 2/4 Service Worker deaktivieren ==="
cd "$(dirname "$0")"
python3 patch_sw.py

echo "=== 3/4 Flutter Web → EC2 ==="
rsync -az --delete "$APP_DIR/build/web/" "$EC2:/home/ubuntu/socialheadmap-web/"

echo "=== 4/4 Backend → EC2 ==="
scp "$BACKEND_DIR/app/schemas.py"          "$EC2:/tmp/shm_schemas.py"
scp "$BACKEND_DIR/app/routers/stats.py"   "$EC2:/tmp/shm_stats.py"
scp "$BACKEND_DIR/app/routers/votes.py"   "$EC2:/tmp/shm_votes.py"
scp "$BACKEND_DIR/app/routers/auth.py"    "$EC2:/tmp/shm_auth.py"
scp "$BACKEND_DIR/app/routers/questions.py" "$EC2:/tmp/shm_questions.py"
scp "$BACKEND_DIR/app/main.py"            "$EC2:/tmp/shm_main.py"

ssh "$EC2" "
  sudo docker cp /tmp/shm_schemas.py    socialheadmap-api:/app/app/schemas.py
  sudo docker cp /tmp/shm_stats.py      socialheadmap-api:/app/app/routers/stats.py
  sudo docker cp /tmp/shm_votes.py      socialheadmap-api:/app/app/routers/votes.py
  sudo docker cp /tmp/shm_auth.py       socialheadmap-api:/app/app/routers/auth.py
  sudo docker cp /tmp/shm_questions.py  socialheadmap-api:/app/app/routers/questions.py
  sudo docker cp /tmp/shm_main.py       socialheadmap-api:/app/app/main.py
  sudo docker restart socialheadmap-api
  sleep 3
  sudo docker logs socialheadmap-api --tail=4
"

echo ""
echo "=== Deploy abgeschlossen ==="
echo "URL: https://shm.13-61-179-136.nip.io"
echo "Normaler Browser-Tab + F5 reicht — kein Inkognito mehr nötig."
