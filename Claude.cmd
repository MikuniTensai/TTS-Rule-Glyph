@echo off
:: Batch script to run Claude Code CLI with Aerolink Gateway
:: Created by Antigravity

echo ==============================================================
echo              LAUNCHING CLAUDE CODE VIA AEROLINK
echo ==============================================================
echo.
:: Set environment variables
@REM Nitedreamworks
@REM set ANTHROPIC_API_KEY=aero_live_1_T-pM-4aKUhTolwgU0zkitvwhtY89iM35-rJBGy8k8
@REM Gfans
@REM set ANTHROPIC_API_KEY=aero_live_0Q2DmNYXr5kyk776b1bCvjgIotUOOu9dRc6Tb-SviOQ
@REM Mikunitoken
@REM set ANTHROPIC_API_KEY=aero_live_NDNZrJ-NUqz95D00Ro5HyK3qdUwopn75NgkZWHNbXnc
set ANTHROPIC_API_KEY=aero_live_qlHjMM-IdwHHqoqfuMF7UY5czqsR7jrewCX8q0al7Bw
set ANTHROPIC_BASE_URL=https://capi.aerolink.lat/
set ANTHROPIC_AUTH_TOKEN=
set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

echo API Key:      %ANTHROPIC_API_KEY:~0,14%... (masked)
echo Base URL:     %ANTHROPIC_BASE_URL%
echo.

:: Ensure npm global bin and hermes node are in PATH
set "PATH=%PATH%;%APPDATA%\npm;%LOCALAPPDATA%\hermes\node"

:: Launch Claude Code
echo Launching Claude CLI...
claude

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Failed to run 'claude'. Make sure Claude Code is installed.
    echo You can install it using: npm install -g @anthropic-ai/claude-code
    echo.
)

pause
