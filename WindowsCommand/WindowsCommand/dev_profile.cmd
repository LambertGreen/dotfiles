@echo off

goto :main

:setup_color_mode
	if not defined COLOR_MODE (
		set COLOR_MODE=dark
	)
	goto :eof

:setup_clink_color
    if %COLOR_MODE%==light (
		clink set color.input sgr 38;5;100 >nul 2>&1
		clink set color.cmd sgr 1;38;5;239 >nul 2>&1
		clink set color.suggestion sgr 38;5;239 >nul 2>&1
    ) else (
		clink set color.input sgr 38;5;222 >nul 2>&1
		clink set color.cmd sgr 1;38;5;231 >nul 2>&1
		clink set color.suggestion sgr 38;5;231 >nul 2>&1
    )
	goto :eof

:setup_fzf
	set FZF_DEFAULT_OPTS=--ansi
    if %COLOR_MODE%==light (
		REM OneHalfLight theme
		set FZF_DEFAULT_OPTS=%FZF_DEFAULT_OPTS% ^
			--color=fg:-1,bg:-1^
			--color=hl:#c678dd,fg+:#4b5263,bg+:#ffffff,hl+:#d858fe^
			--color=info:#98c379,prompt:#61afef,pointer:#be5046^
			--color=marker:#e5c07b,spinner:#61afef,header:#61afef
    ) else (
		REM OneHalfDark theme
		set FZF_DEFAULT_OPTS=%FZF_DEFAULT_OPTS% ^
			--color=fg:-1,bg:-1^
			--color=hl:#c678dd,fg+:#ffffff,bg+:#4b5263,hl+:#d858fe^
			--color=info:#98c379,prompt:#61afef,pointer:#be5046^
			--color=marker:#e5c07b,spinner:#61afef,header:#61afef
    )
	goto :eof

:setup_bat
    if %COLOR_MODE%==light (
		REM OneHalfLight theme
		set BAT_THEME=OneHalfLight
    ) else (
		REM OneHalfDark theme
		set BAT_THEME=OneHalfDark
    )
	goto :eof

:setup_lua
	set LUA_PATH=%userprofile%\scoop\apps\luarocks\current\lua\?.lua;%userprofile%\scoop\apps\luarocks\current\lua\?\init.lua;%userprofile%\scoop\apps\luarocks\current\?.lua;%userprofile%\scoop\apps\luarocks\current\?\init.lua;%userprofile%\scoop\apps\luarocks\current\..\share\lua\5.4\?.lua;%userprofile%\scoop\apps\luarocks\current\..\share\lua\5.4\?\init.lua;.\?.lua;.\?\init.lua;C:/Users/lambert.green/scoop/apps/luarocks/current/rocks/share/lua/5.4/?.lua;C:/Users/lambert.green/scoop/apps/luarocks/current/rocks/share/lua/5.4/?/init.lua
	set LUA_CPATH=%userprofile%\scoop\apps\lua\current;%userprofile%/scoop/apps/luarocks/current/rocks/lib/lua/5.4/?.dll
	goto :eof

:setup_zoxide
    REM Configure zoxide for better Windows CMD experience
    set _ZO_ECHO=1
    set _ZO_RESOLVE_SYMLINKS=1
    goto :eof

:main
    call :setup_color_mode
    call :setup_fzf
    call :setup_bat
    call :setup_clink_color
    call :setup_lua
    call :setup_zoxide
