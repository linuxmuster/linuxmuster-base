REM ****************************
REM * tschmitt@linuxmuster.net *
REM * 14.12.2014               *
REM ****************************

@echo off

if not exist S: goto connect
echo Trenne Laufwerk S:
net use S: /DELETE /YES > NUL

:connect
echo Verbinde S: mit \\@@servername@@\students
start /B net use S: \\@@servername@@\students /YES /PERSISTENT:NO > NUL

