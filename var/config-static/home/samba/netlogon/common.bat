REM Windows logon script common stuff, called by logon.bat
REM thomas@linuxmuster.net
REM 28.10.2014

@echo off

REM Do not for Windows version prior to Win2K.
if NOT "%OS%"=="Windows_NT" goto common_end

REM Extract servername from unc path.
set UNC=%0%
for /f "tokens=1 delims=\" %%i in ("%UNC%") do set SERVER=%%i
if "%SERVER%"=="" goto common_end

REM Create personal folders in homedir. Comment it out if you don't want.
for %%i in (Bilder Einstellungen Dokumente Downloads Musik Videos) do if not exist "H:\%%i" md "H:\%%i"


REM ### Add your custom stuff here - begin ###

REM ### Custom stuff - end ###


REM ### Default user profile stuff - begin ###

REM Set name for template user.
set TEMPLATE=pgmadmin

REM Do not for template user.
if "%USERNAME%"=="%TEMPLATE%" goto profile_end

REM Do not if user profile does not exist.
if NOT exist "%USERPROFILE%" goto profile_end

REM Replace template user paths in registry.
cd "%USERPROFILE%"

reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" %USERNAME%.reg /y
cscript \\%SERVER%\netlogon\replace.vbs \\"%TEMPLATE%"\\ \\"%USERNAME%"\\ %USERNAME%.reg
reg import %USERNAME%.reg

reg export "HKCU\Control Panel\Desktop" %USERNAME%.reg /y
cscript \\%SERVER%\netlogon\replace.vbs \\"%TEMPLATE%"\\ \\"%USERNAME%"\\ %USERNAME%.reg
reg import %USERNAME%.reg

reg export "HKCU\Software\Microsoft\GDIPlus" %USERNAME%.reg /y
cscript \\%SERVER%\netlogon\replace.vbs \\"%TEMPLATE%"\\ \\"%USERNAME%"\\ %USERNAME%.reg
reg import %USERNAME%.reg

reg export "HKCU\Software\Microsoft\MediaPlayer\Preferences" %USERNAME%.reg /y
cscript \\%SERVER%\netlogon\replace.vbs \\"%TEMPLATE%"\\ \\"%USERNAME%"\\ %USERNAME%.reg
reg import %USERNAME%.reg

reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes" %USERNAME%.reg /y
cscript \\%SERVER%\netlogon\replace.vbs \\"%TEMPLATE%"\\ \\"%USERNAME%"\\ %USERNAME%.reg
reg import %USERNAME%.reg

reg export "HKCU\Software\Microsoft\Windows Media\WMSDK\Namespace" %USERNAME%.reg /y
cscript \\%SERVER%\netlogon\replace.vbs \\"%TEMPLATE%"\\ \\"%USERNAME%"\\ %USERNAME%.reg
reg import %USERNAME%.reg

del %USERNAME%.reg

:profile_end

REM ### Default user profile stuff - end ###


REM End of script
:common_end

