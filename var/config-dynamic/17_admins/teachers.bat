REM ****************************
REM * tschmitt@linuxmuster.net *
REM * 18.12.2014               *
REM ****************************

@echo off

if not exist S: goto connect
echo Trenne Laufwerk S:
net use S: /DELETE /YES > NUL

:connect
echo Verbinde S: mit \\@@servername@@\students
net use S: \\@@servername@@\students /YES /PERSISTENT:NO > NUL
