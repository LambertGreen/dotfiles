@echo off

REM FIXME: Don't set environment variables here for the following reasons:
REM  - the paths are system dependant
REM  - these are like profile env vars and better to be set in the user env, so rather
REM		have a script that sets up things and validates health of user env and this way
REM		the shell startup is always fast and fluid.
REM
REM SET LUA_PATH=C:\Users\lambert.green\scoop\apps\luarocks\current\lua\?.lua;C:\Users\lambert.green\scoop\apps\luarocks\current\lua\?\init.lua;C:\Users\lambert.green\scoop\apps\luarocks\current\?.lua;C:\Users\lambert.green\scoop\apps\luarocks\current\?\init.lua;C:\Users\lambert.green\scoop\apps\luarocks\current\..\share\lua\5.4\?.lua;C:\Users\lambert.green\scoop\apps\luarocks\current\..\share\lua\5.4\?\init.lua;.\?.lua;.\?\init.lua;C:/Users/lambert.green/scoop/apps/luarocks/current/rocks/share/lua/5.4/?.lua;C:/Users/lambert.green/scoop/apps/luarocks/current/rocks/share/lua/5.4/?/init.lua
REM SET LUA_CPATH=C:\Users\lambert.green\scoop\apps\lua\current;C:/Users/lambert.green/scoop/apps/luarocks/current/rocks/lib/lua/5.4/?.dll
REM set _ZL_LOG_NAME=C:\Users\lambert.green\z.lua.log

"c:\ProgramData\scoop\apps\clink\current\clink_x64.exe" inject  && doskey /macrofile=%userprofile%\WindowsCommand\doskey_macros.txt

