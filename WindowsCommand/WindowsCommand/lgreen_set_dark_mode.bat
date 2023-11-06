@echo off
rem setlocal enabledelayedexpansion

:: Initialize if MODE_VAR not set
if not defined MODE_VAR (
    set MODE_VAR=light
)

:: Branch to appropriate mode based on argument
if /i "%~1"=="light" (
    goto light
) else if /i "%~1"=="dark" (
    goto dark
) else if /i "%~1"=="toggle" (
    if "%MODE_VAR%"=="light" (
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
set MODE_VAR=light
goto end

:dark
:: Set your environment variables for dark mode here
set FZF_DEFAULT_OPTS=--color=fg:-1,bg:-1^
    --color=hl:#c678dd,fg+:#ffffff,bg+:#4b5263,hl+:#d858fe^
    --color=info:#98c379,prompt:#61afef,pointer:#be5046^
    --color=marker:#e5c07b,spinner:#61afef,header:#61afef
set BAT_THEME=OneHalfDark
set MODE_VAR=dark
goto end

:end
:: Print current mode
echo Current mode: %MODE_VAR%
