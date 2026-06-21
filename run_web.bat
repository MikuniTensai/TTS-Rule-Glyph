@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"

set "PORT=%~1"
if "%PORT%"=="" set "PORT=8088"

echo Menjalankan Rule Glyph Lab Web...
echo Folder: %CD%
echo URL: http://127.0.0.1:%PORT%/
echo.
echo Tekan Ctrl+C untuk menghentikan server.
echo.

start "" "http://127.0.0.1:%PORT%/"

set "DART_BIN="
where dart >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  set "DART_BIN=dart"
)

if "%DART_BIN%"=="" (
  if exist "%CD%\rule_glyph_app\android\local.properties" (
    for /f "tokens=1,* delims==" %%A in ('findstr /b /c:"flutter.sdk=" "%CD%\rule_glyph_app\android\local.properties"') do (
      set "FLUTTER_SDK=%%B"
    )
    if defined FLUTTER_SDK (
      set "FLUTTER_SDK=!FLUTTER_SDK:\\=\!"
      if exist "!FLUTTER_SDK!\bin\dart.bat" set "DART_BIN=!FLUTTER_SDK!\bin\dart.bat"
      if "%DART_BIN%"=="" if exist "!FLUTTER_SDK!\bin\cache\dart-sdk\bin\dart.exe" set "DART_BIN=!FLUTTER_SDK!\bin\cache\dart-sdk\bin\dart.exe"
    )
  )
)

if "%DART_BIN%"=="" (
  if exist "C:\flutter\bin\dart.bat" set "DART_BIN=C:\flutter\bin\dart.bat"
  if "%DART_BIN%"=="" if exist "C:\flutter\bin\cache\dart-sdk\bin\dart.exe" set "DART_BIN=C:\flutter\bin\cache\dart-sdk\bin\dart.exe"
)

if not "%DART_BIN%"=="" (
  "%DART_BIN%" tools\web_autosave_server.dart %PORT%
  goto :done
)

echo Dart tidak ditemukan di PATH; autosave JSON Android tidak aktif.
echo Web tetap dijalankan dengan server Python biasa.
echo.

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  py -3 -m http.server %PORT%
  goto :done
)

where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  python -m http.server %PORT%
  goto :done
)

echo Python tidak ditemukan di PATH.
echo Install Python atau jalankan server manual dari folder ini.
pause

:done
endlocal
