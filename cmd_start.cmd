:: To use this file, one must add a registry entry under:
::  Computer\HKEY_CURRENT_USER\Software\Microsoft\Command Processor
::  Called AutoRun
:: Note: It is best not put any complex stuff here because AutoRun is run
:: for every cmd.exe and cause performance issues.
:: Further the script must be very careful to not write to std out since
:: this can have strange after effects.
::
:: Rather than use this file at all it is recommended to use Powershell,
:: which has better support for loading user config.
@echo off

set scriptDir=%~dp0
