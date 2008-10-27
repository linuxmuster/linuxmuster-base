@echo off
set SERVER=@@servername@@
C:
if "%OS%"=="Windows_NT" goto winnt

REM *******************************************************
REM *       Windows 9x/ME-spezifische Anweisungen         *
REM *******************************************************
goto mapping

:winnt
REM *******************************************************
REM *      Windows NT/2K/XP-spezifische Anweisungen       *
REM *******************************************************
set NUOPT=/PERSISTENT:NO
echo Trenne alle Netzwerkfreigaben
net use * /DELETE /YES
\\%SERVER%\netlogon\sleep 1000

:mapping
REM *******************************************************
REM *             Verbinde Netzwerkfreigaben              *
REM *******************************************************
if "%1"=="" goto time

for %%i in (%1) do set DRIVE=%%i
shift
for %%i in (%1) do set SHARE=%%i

if not exist %DRIVE% goto connect
echo Trenne Laufwerk %DRIVE%
net use %DRIVE% /DELETE /YES > NUL

:connect
echo Verbinde %DRIVE% mit \\%SERVER%\%SHARE%
net use %DRIVE% \\%SERVER%\%SHARE% /YES %NUOPT% > NUL

shift
goto mapping

:time
REM *******************************************************
REM *         Uhrzeit mit Server synchronisieren          *
REM *******************************************************
echo Synchronisiere Uhrzeit mit Server
net time \\%SERVER% /SET /YES > NUL

REM *******************************************************
REM *                 Sonstige Anpassungen                *
REM *******************************************************
if exist \\%SERVER%\netlogon\common.bat call \\%SERVER%\netlogon\common.bat
rem pause
