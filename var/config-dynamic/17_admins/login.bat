@echo off

if NOT "%OS%"=="Windows_NT" goto win9x

:winnt
rem call \\@@servername@@\netlogon\logon.bat H: %USERNAME% K: pgm M: pgmw R: cdrom
call \\@@servername@@\netlogon\logon.bat H: %USERNAME% K: pgm R: cdrom
goto ende

:win9x
call \\@@servername@@\netlogon\logon.bat H: homes K: pgm R: cdrom

:ende
rem pause
