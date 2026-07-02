#!/bin/bash
# Paralegal Quest - Production Web Build Script
#
# IMPORTANT: The --pwa-strategy=none flag is REQUIRED.
#
# Without it, Flutter's default service worker registration races with the
# Firebase JS SDK's interop handshake in release (minified/dart2js) builds,
# causing a blank white screen with:
#   PlatformException(channel-error, Unable to establish connection on channel.)
# thrown inside FirebaseCoreHostApi.initializeCore during Firebase.initializeApp().
#
# This does NOT happen in `flutter run` debug mode, only in release web builds
# served as static files (e.g. on Netlify). See firebase/flutterfire#10195 for
# the matching upstream issue ("works on localhost, fails after deployed to
# production").
#
# DO NOT remove --pwa-strategy=none unless this root cause is fixed upstream
# or a different mitigation (e.g. custom service worker timing) is verified.

set -e
cd "$(dirname "$0")"

echo "Building Paralegal Quest for production (web)..."
flutter build web --release --pwa-strategy=none

echo ""
echo "Build complete: build/web"
echo "Serve locally with: python3 -m http.server 5060 --directory build/web --bind 0.0.0.0"
