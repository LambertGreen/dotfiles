@echo off
REM Batch file to spawn Windows Terminal with CLEAN Windows environment
REM This breaks the MSYS2 environment inheritance chain
REM
REM Usage:
REM   spawn_wt_clean.bat <title> <shell> <command...>
REM
REM Example:
REM   spawn_wt_clean.bat "MyTab" "pwsh.exe" "-NoExit" "-Command" "scoop --version"

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
"C:\Users\lgreen\AppData\Local\Microsoft\WindowsApps\wt.exe" -w 0 nt --title "%WT_TITLE%" %SHELL% %SHELL_ARGS%
