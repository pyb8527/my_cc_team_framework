@echo off
setlocal enabledelayedexpansion

echo Installing my_cc_team_framework agents and skills...
echo.

set CLAUDE_DIR=%USERPROFILE%\.claude
set AGENTS_DIR=%CLAUDE_DIR%\agents
set SKILLS_DIR=%CLAUDE_DIR%\skills

:: Create target directories if they don't exist
if not exist "%AGENTS_DIR%" mkdir "%AGENTS_DIR%"
if not exist "%SKILLS_DIR%" mkdir "%SKILLS_DIR%"

:: ─── Install Agents ───────────────────────────────────────────────
echo [Agents]
for /d %%P in (plugins\*) do (
    for %%F in ("%%P\agents\*.md") do (
        copy /Y "%%F" "%AGENTS_DIR%\" >nul
        echo   + %%~nxF
    )
)

echo.

:: ─── Install Skills ───────────────────────────────────────────────
echo [Skills]
for /d %%P in (plugins\*) do (
    for /d %%S in ("%%P\skills\*") do (
        set SKILL_NAME=%%~nxS
        if exist "%%S\SKILL.md" (
            copy /Y "%%S\SKILL.md" "%SKILLS_DIR%\!SKILL_NAME!.md" >nul
            echo   + !SKILL_NAME!.md
        )
    )
)

echo.
echo Done! Restart Claude Code to use:
echo   Agents  : /agent-name  (e.g. /backend-developer)
echo   Skills  : /skill-name  (e.g. /java-springboot)
pause
