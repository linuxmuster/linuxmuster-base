:winnt
if NOT "%OS%"=="Windows_NT" goto winnt_ende

rem for /f "delims=- tokens=1" %%i in ("%COMPUTERNAME%") do set ROOM=%%i

if "%ROOM%"=="" set ROOM=Default
if exist K:\Patches\%ROOM%.reg regedit /s K:\Patches\%ROOM%.reg 
if exist K:\Patches\%COMPUTERNAME%.reg regedit /s K:\Patches\%COMPUTERNAME%.reg 
REM if exist K:\Patches\%USERNAME%.reg regedit /s K:\Patches\%USERNAME%.reg 
:winnt_ende
