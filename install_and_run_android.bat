@echo off
setlocal enabledelayedexpansion

:: Detect directories
set "PROJECT_DIR=%~dp0"
if exist "%PROJECT_DIR%rule_glyph_app\pubspec.yaml" (
    set "FLUTTER_DIR=%PROJECT_DIR%rule_glyph_app"
) else if exist "%PROJECT_DIR%pubspec.yaml" (
    set "FLUTTER_DIR=%PROJECT_DIR%"
) else (
    echo [ERROR] pubspec.yaml not found! Make sure you run this script from the project folder.
    pause
    exit /b 1
)

echo [INFO] Project directory: %PROJECT_DIR%
echo [INFO] Flutter project directory: %FLUTTER_DIR%

:: Resolve ADB path
set "ADB_PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if exist "%ADB_PATH%" (
    set "ADB=%ADB_PATH%"
) else (
    where adb >nul 2>&1
    if !errorlevel! equ 0 (
        set "ADB=adb"
    ) else (
        echo [ERROR] ADB not found in "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" or system PATH.
        echo Please ensure Android SDK platform-tools are installed.
        pause
        exit /b 1
    )
)

:: Resolve Flutter path
set "FLUTTER=flutter"
where flutter >nul 2>&1
if !errorlevel! neq 0 (
    if exist "C:\flutter\bin\flutter.bat" (
        set "FLUTTER=C:\flutter\bin\flutter.bat"
    ) else (
        echo [WARNING] Flutter executable not found in system PATH or C:\flutter\bin\flutter.bat.
        echo Will try default 'flutter' command.
    )
)

echo [INFO] Using ADB: %ADB%
echo [INFO] Using Flutter: %FLUTTER%

:: Check connected devices
echo [INFO] Checking connected Android devices...
"%ADB%" devices

:: Verify APK existence and optionally rebuild
set "APK_FILE=%FLUTTER_DIR%\build\app\outputs\flutter-apk\app-release.apk"
set "REBUILD=N"
if not exist "%APK_FILE%" (
    echo [INFO] Release APK not found. Rebuild is required.
    set "REBUILD=Y"
) else (
    set /p REBUILD_CHOICE="Apakah Anda ingin mem-build ulang APK terbaru? (Y/N, default N): "
    if /i "!REBUILD_CHOICE!"=="Y" set "REBUILD=Y"
)

if /i "!REBUILD!"=="Y" (
    echo [INFO] Building release APK...
    cd /d "%FLUTTER_DIR%"
    call "%FLUTTER%" build apk --release
    if !errorlevel! neq 0 (
        echo [ERROR] Flutter build failed!
        pause
        exit /b 1
    )
)

:: Install on device
echo [INFO] Installing app-release.apk to connected device...
cd /d "%FLUTTER_DIR%"
call "%FLUTTER%" install
if !errorlevel! neq 0 (
    echo [INFO] Falling back to manual adb install...
    "%ADB%" install -r "%APK_FILE%"
    if !errorlevel! neq 0 (
        echo [ERROR] Installation failed! Make sure your device is connected and USB debugging is enabled.
        pause
        exit /b 1
    )
)

:: Launch app
echo [INFO] Launching io.dreamworks.tts on device...
"%ADB%" shell am start -n io.dreamworks.tts/io.dreamworks.tts.MainActivity

if %errorlevel% equ 0 (
    echo [SUCCESS] App successfully installed and launched!
) else (
    echo [WARNING] Installation succeeded, but failed to launch automatically.
)

pause
