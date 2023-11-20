@echo off
rem setlocal enabledelayedexpansion

:: Initialize if COLOR_MODE not set
if not defined COLOR_MODE (
    set COLOR_MODE=dark
)

:: Branch to appropriate mode based on argument
if /i "%~1"=="light" (
    goto light
) else if /i "%~1"=="dark" (
    goto dark
) else if /i "%~1"=="toggle" (
    if "%COLOR_MODE%"=="light" (
        goto dark
    ) else (
        goto light
    )
) else (
    echo Invalid argument. Use light, dark, or toggle.
    goto end
)

:light
:: Set your environment variables for light mode here
set FZF_DEFAULT_OPTS=--color=fg:-1,bg:-1^
    --color=hl:#c678dd,fg+:#4b5263,bg+:#ffffff,hl+:#d858fe^
    --color=info:#98c379,prompt:#61afef,pointer:#be5046^
    --color=marker:#e5c07b,spinner:#61afef,header:#61afef
set BAT_THEME=OneHalfLight
set COLOR_MODE=light
clink set color.input sgr 38;5;100 >nul 2>&1
clink set color.cmd sgr 1;38;5;239 >nul 2>&1
clink set color.suggestion sgr 38;5;239 >nul 2>&1
goto end

:dark
:: Set your environment variables for dark mode here
set FZF_DEFAULT_OPTS=--color=fg:-1,bg:-1^
    --color=hl:#c678dd,fg+:#ffffff,bg+:#4b5263,hl+:#d858fe^
    --color=info:#98c379,prompt:#61afef,pointer:#be5046^
    --color=marker:#e5c07b,spinner:#61afef,header:#61afef
set BAT_THEME=OneHalfDark
set COLOR_MODE=dark
clink set color.input sgr 38;5;222 >nul 2>&1
clink set color.cmd sgr 1;38;5;231 >nul 2>&1
clink set color.suggestion sgr 38;5;231 >nul 2>&1
goto end

:end
:: Print current mode
echo Current mode: %COLOR_MODE%
