@echo off
REM Batch file to spawn Windows Terminal with CLEAN Windows environment
REM This breaks the MSYS2 environment inheritance chain
REM
REM Usage:
REM   spawn_wt_clean.bat <title> <shell> <command...>
REM
REM Example:
REM   spawn_wt_clean.bat "MyTab" "pwsh.exe" "-NoExit" "-Command" "scoop --version"
REM
REM Note: bash no longer auto-execs to zsh by default.
REM Set DOTFILES_BASH_EXEC_ZSH=1 if you want bash to exec zsh.

setlocal EnableDelayedExpansion

REM First arg is title
set "WT_TITLE=%~1"
shift

REM Second arg is shell (pwsh.exe, cmd.exe, etc)
set "SHELL=%~1"
shift

REM Remaining args are the shell arguments
set "SHELL_ARGS="
:loop
if "%~1"=="" goto endloop
if defined SHELL_ARGS (
    set "SHELL_ARGS=!SHELL_ARGS! %1"
) else (
    set "SHELL_ARGS=%1"
)
shift
goto loop
:endloop

REM Spawn Windows Terminal
REM The batch file reads environment from Windows registry (no MSYS2 pollution)
REM Find wt.exe dynamically (Windows Terminal can be in different locations)
where wt.exe >nul 2>&1
if errorlevel 1 goto :try_fallback
wt.exe -w 0 nt --title "%WT_TITLE%" %SHELL% %SHELL_ARGS%
goto :end_spawn

:try_fallback
REM Fallback: try common locations
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" (
    "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" -w 0 nt --title "%WT_TITLE%" %SHELL% %SHELL_ARGS%
) else (
    echo ERROR: Windows Terminal (wt.exe) not found
    exit /b 1
)

:end_spawn
