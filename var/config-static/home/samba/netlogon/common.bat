REM Windows logon script common stuff, called by logon.bat
REM thomas@linuxmuster.net
REM 30.10.2014

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

REM Patch drive names

REM pgm
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\##%SERVER%#pgm /v _LabelFromReg /t REG_SZ /f /d "Programme"

REM cdrom
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\##%SERVER%#cdrom /v _LabelFromReg /t REG_SZ /f /d "CDs"

REM share
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\##%SERVER%#shares /v _LabelFromReg /t REG_SZ /f /d "Tauschen"

REM tasks
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\##%SERVER%#tasks /v _LabelFromReg /t REG_SZ /f /d "Vorlagen"

REM students
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\##%SERVER%#students /v _LabelFromReg /t REG_SZ /f /d "Schuelerhomes"

REM home
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\##%SERVER%#%USERNAME% /v _LabelFromReg /t REG_SZ /f /d "Home von %USERNAME%"

:profile_end

REM ### Default user profile stuff - end ###


REM End of script
:common_end

