REM ****************************
REM * tschmitt@linuxmuster.net *
REM * 18.12.2014               *
REM ****************************

@echo off

if NOT "%OS%"=="Windows_NT" goto win9x

:winnt
call \\@@servername@@\netlogon\logon.bat H: %USERNAME% K: pgm R: cdrom T: shares V: tasks
goto ende

:win9x
call \\@@servername@@\netlogon\logon.bat H: homes K: pgm R: cdrom T: shares V: tasks

:ende
REM *******************************************************
REM *             Schülerhomes für Lehrkräfte             *
REM *******************************************************
if exist \\@@servername@@\students call \\@@servername@@\netlogon\teachers.bat
rem pause
