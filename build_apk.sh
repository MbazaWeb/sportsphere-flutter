#!/usr/bin/env bash
set -euo pipefail
echo "Building release APK with Supabase config..."
flutter build apk --release --dart-define-from-file=dart_defines.json
echo ""
echo "APK built successfully!"
echo "Location: build/app/outputs/flutter-apk/app-release.apk"