#!/usr/bin/env bash
set -e

EC2="ubuntu@100.77.243.73"
FLUTTER="/home/artur/flutter/bin/flutter"
# Absolute Pfade — die Funktionen wechseln per cd das Verzeichnis,
# relative dirname-Pfade zeigen danach ins Leere.
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/app"
BACKEND_DIR="$ROOT_DIR/backend"
FIREBASE_APP_ID="1:373278842318:android:d367c4663a3807513cdf9f"
GOOGLE_APPLICATION_CREDENTIALS="/home/artur/.config/gamodi/firebase-service-account.json"

# Argumente: deploy.sh [web|android|backend|all] [release_notes]
MODE="${1:-web}"
NOTES="${2:-Build $(date +%Y-%m-%d)}"

# ── Web Deploy ────────────────────────────────────────────────────────────────
deploy_web() {
  echo "=== Flutter Web Build ==="
  cd "$APP_DIR"
  $FLUTTER build web --release --no-web-resources-cdn

  echo "=== Service Worker deaktivieren ==="
  cd "$ROOT_DIR"
  python3 patch_sw.py

  echo "=== Flutter Web → EC2 ==="
  rsync -az --delete "$APP_DIR/build/web/" "$EC2:/home/ubuntu/socialheadmap-web/"

  ssh "$EC2" "
    sudo docker cp /home/ubuntu/socialheadmap-web/. socialheadmap-api:/app/web/
    sudo docker restart socialheadmap-api
    sleep 3
    sudo docker logs socialheadmap-api --tail=4
  "
  echo "Web: https://shm.13-61-179-136.nip.io"
}

# ── Android Deploy ────────────────────────────────────────────────────────────
deploy_android() {
  echo "=== Android APK Build ==="
  cd "$APP_DIR"
  JAVA_HOME=/home/artur/tools/jdk17 \
  ANDROID_SDK_ROOT=/home/artur/tools/android-sdk \
  $FLUTTER build apk --debug

  APK="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
  VERSION=$(grep '^version:' "$APP_DIR/pubspec.yaml" | sed 's/version: //')

  echo "=== Firebase App Distribution → Upload ==="
  GOOGLE_APPLICATION_CREDENTIALS="$GOOGLE_APPLICATION_CREDENTIALS" \
    firebase appdistribution:distribute "$APK" \
    --app "$FIREBASE_APP_ID" \
    --testers "shachnev.artur@googlemail.com" \
    --release-notes "v${VERSION} — ${NOTES}"

  echo "Firebase Console: https://console.firebase.google.com/project/gamodi/appdistribution/app/android:de.socialheadmap.socialheadmap/releases"
}

# ── Backend Deploy ────────────────────────────────────────────────────────────
deploy_backend() {
  echo "=== Backend → EC2 ==="
  scp "$BACKEND_DIR/app/schemas.py"            "$EC2:/tmp/shm_schemas.py"
  scp "$BACKEND_DIR/app/routers/stats.py"      "$EC2:/tmp/shm_stats.py"
  scp "$BACKEND_DIR/app/routers/votes.py"      "$EC2:/tmp/shm_votes.py"
  scp "$BACKEND_DIR/app/routers/auth.py"       "$EC2:/tmp/shm_auth.py"
  scp "$BACKEND_DIR/app/routers/questions.py"  "$EC2:/tmp/shm_questions.py"
  scp "$BACKEND_DIR/app/main.py"               "$EC2:/tmp/shm_main.py"
  scp "$BACKEND_DIR/app/admin.html"            "$EC2:/tmp/shm_admin.html"

  ssh "$EC2" "
    sudo docker cp /tmp/shm_schemas.py    socialheadmap-api:/app/app/schemas.py
    sudo docker cp /tmp/shm_stats.py      socialheadmap-api:/app/app/routers/stats.py
    sudo docker cp /tmp/shm_votes.py      socialheadmap-api:/app/app/routers/votes.py
    sudo docker cp /tmp/shm_auth.py       socialheadmap-api:/app/app/routers/auth.py
    sudo docker cp /tmp/shm_questions.py  socialheadmap-api:/app/app/routers/questions.py
    sudo docker cp /tmp/shm_main.py       socialheadmap-api:/app/app/main.py
    sudo docker cp /tmp/shm_admin.html    socialheadmap-api:/app/app/admin.html
    sudo docker restart socialheadmap-api
    sleep 3
    sudo docker logs socialheadmap-api --tail=4
  "
  echo "API: https://shm.13-61-179-136.nip.io"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$MODE" in
  web)     deploy_web ;;
  android) deploy_android ;;
  backend) deploy_backend ;;
  all)     deploy_web; deploy_android; deploy_backend ;;
  *)
    echo "Usage: deploy.sh [web|android|backend|all] [release_notes]"
    echo "  web      — Flutter Web Build + EC2 Deploy (default)"
    echo "  android  — APK Build + Firebase App Distribution"
    echo "  backend  — FastAPI files → EC2 Docker"
    echo "  all      — alles"
    exit 1
    ;;
esac

echo ""
echo "=== Deploy abgeschlossen: $MODE ==="
