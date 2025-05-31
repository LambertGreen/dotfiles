@echo off

:: Start up clink and configure environment
"c:\ProgramData\scoop\apps\clink\current\clink_x64.exe" inject ^
  && "%userprofile%\WindowsCommand\dev_profile.cmd" ^
  && doskey /macrofile="%userprofile%\WindowsCommand\doskey_macros.txt" ^
  && fastfetch
