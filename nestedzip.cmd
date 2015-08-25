@echo off
rem	--------------------------------------------------------------------------
rem	name	nestedzip.cmd
rem	usage	mdaemon nested zip mitigation
rem	owner	iNet, uka
rem	date	150824
rem	depend	%comspec%=cmd.exe
rem			grep.exe
rem			unzip.exe
rem			uud64win.exe
rem
rem         This file is public domain and provided as-is.
rem			There are no guarantees. Use at your own risk.
rem
rem	--------------------------------------------------------------------------

SETLOCAL

rem set your MD base install path
rem
set "MDPATH=D:\Wan\Mdaemon"

rem Assumed you have a special folder for your system logs set it here,
rem otherwise logging is to %TEMP% folder.
rem
if "%LOGS%" EQU "" set "LOGS=%TEMP%"

rem Path to folder with messages to be analysed, this is where messages with
rem zip attachments got moved to by MD. You need a MD rule = "if message has
rem file like *.zip move to this folder and stop processing".
rem You have to create these folders by hand or from within MD.
rem CAVE: The folder must be accessible by MD content filter move rules.
rem I chose \Public Folders\Ziptest
rem                                \Nested
rem                                \Ok
rem 
set "nzPATH=%MDPATH%\Public Folders\Ziptest.IMAP"

set "nzNEST=%nzPATH%\Nested.IMAP"
set "nzISOK=%nzPATH%\Ok.IMAP"

rem Leave this place if there is no work to do
rem
if not exist "%nzPATH%\*.msg" goto :eof

rem Do some logging
rem
echo start %0 %date% %time%>> "%LOGS%\nestedzip.log"

rem Change extensions of files we want to process to be sure MD is done
rem with the move.
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msg"') do ren "%nzPATH%\%%i" *.msz

rem Decompose messages into components, body text, decoded attachments...
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :decompose %%i

rem Analyse the now decoded mail components
rem
for /f "tokens=*" %%i in ('dir /l /b /a:d "%nzPATH%\pd*"') do call :getzip %%i

rem If there are still *.msz in the %nzPATH% after the content has been analysed
rem these are the "good" ones. Move them to the %nzISOK% folder and rename back
rem to .msg.
rem
if exist "%nzPATH%\*.msz" (

	move "%nzPATH%\*.msz" "%nzISOK%\."
	for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzISOK%\*.msz"') do ren "%nzISOK%\%%i" *.msg
	
	)

rem Feed back the messages to the local mail queue of MD.
rem CAVE: If you have changed the MD local queue path from default you have to do it here too.
rem 
if exist "%nzISOK%\*.msg" move "%nzISOK%\*.msg" "%MDPATH%\Queues\Local\."

rem do some more logging
rem
echo stop %0 %date% %time%>> "%LOGS%\nestedzip.log"

goto :eof

:decompose

	set "nzN=%~n1"
	
	mkdir "%nzPATH%\%nzN%"

	uud64win /extract /outdir="%nzPATH%\%nzN%" "%nzPATH%\%1"
	
	goto :eof

:getzip
	
	set "IS_NESTED=N"
	
	for /f "tokens=*" %%j  in ('dir /l /b /s /a:-d "%nzPATH%\%1\*.zip"') do call :listzip "%%j"

	if "%IS_NESTED%" EQU "Y" (
	
		move "%nzPATH%\%1.msz" "%nzNEST%\."
		ren  "%nzNEST%\%1.msz" %1.msg
		
	)
	
	rem Remove temporary folder for decoded message
	rem
	rmdir /s /q "%nzPATH%\%1"
	
	goto :eof

:listzip

	set "dzN=%~n1"
	set "dzPATH=%~dp1"
	
	rem CAVE: unzip must not report back any more info than files contained in the zip.
	rem If it lists the zip name itself grep will always succeed. This is not what we want.
	rem Check that -qql (minus cue cue ell) is understood correctly
	rem
	unzip -qql "%dzPATH%%dzN%.zip" > "%dzPATH%%dzN%.zip.lst"

	grep ".zip" "%dzPATH%%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" set "IS_NESTED=Y"
	
	goto :eof

rem eof nestedzip.cmd 
