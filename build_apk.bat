@echo off
echo Building release APK with Supabase config...
flutter build apk --release --dart-define-from-file=dart_defines.json
if %ERRORLEVEL% EQU 0 (
    echo.
    echo APK built successfully!
    echo Location: build\app\outputs\flutter-apk\app-release.apk
) else (
    echo.
    echo Build FAILED with error code %ERRORLEVEL%
)
pause