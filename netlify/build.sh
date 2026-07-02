#!/usr/bin/env bash
# Netlify build-time script: installs Flutter (pinned version, prebuilt SDK
# archive) and produces a fresh production web build.
#
# WHY THIS EXISTS:
# Previously netlify.toml had no [build] command, so Netlify just published
# whatever build/web/ happened to be committed to git. That is fragile --
# if someone runs a plain `flutter build web --release` locally (without
# --pwa-strategy=none) and commits the result, the deployed site silently
# ships with Flutter's service worker enabled. That service worker races
# the Firebase JS SDK's initialization handshake in release/dart2js builds
# and causes a blank white screen with:
#   PlatformException(channel-error, Unable to establish connection on channel.)
# thrown inside FirebaseCoreHostApi.initializeCore during Firebase.initializeApp().
# (See firebase/flutterfire#10195 -- "works on localhost, fails once deployed".)
#
# This script makes the deploy self-contained: Netlify always builds from
# source with the correct flag, so a stale/incorrect committed build/web can
# never be what actually ends up live.

set -euo pipefail

FLUTTER_VERSION="3.35.4"
FLUTTER_DIR="$HOME/flutter-sdk"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Downloading Flutter $FLUTTER_VERSION SDK..."
  mkdir -p "$FLUTTER_DIR"
  curl -fsSL "$ARCHIVE_URL" -o /tmp/flutter_sdk.tar.xz
  tar -xJf /tmp/flutter_sdk.tar.xz -C "$(dirname "$FLUTTER_DIR")"
  mv "$(dirname "$FLUTTER_DIR")/flutter" "$FLUTTER_DIR" 2>/dev/null || true
  rm -f /tmp/flutter_sdk.tar.xz
else
  echo "==> Using cached Flutter SDK at $FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web --no-analytics
flutter pub get

echo "==> Building production web bundle (--pwa-strategy=none is REQUIRED, do not remove)"
flutter build web --release --pwa-strategy=none

echo "==> Build complete: build/web"
