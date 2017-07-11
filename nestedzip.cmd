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
rem	This file is public domain and provided as-is.
rem	There are no guarantees. Use at your own risk.
rem
rem	170322	major overhaul
rem 		send alert message to receiving user, more logging
rem		semaphores for processing status
rem	--------------------------------------------------------------------------

SETLOCAL

set "debug=rem"
rem set "debug="

rem set your MD base install path
rem
set "MDPATH=D:\Wan\Mdaemon"

rem Assumed you have a special folder for your system logs set it here,
rem otherwise logging is to %TEMP% folder.
rem
if "%LOGS%" EQU "" set "LOGS=%TEMP%"
set "nzLOG=%LOGS%\nestedzip.log"

rem Path to folder with messages to be analysed, this is where messages with
rem zip attachments got moved to by MD. You need a MD rule = "if message has
rem file like *.zip move to this folder and stop processing".
rem You have to create these folders by hand or from within MD.
rem CAVEAT: The folder must be accessible by MD content filter move rules.
rem I chose \Public Folders\Ziptest
rem                                \Nested
rem                                \Ok
rem 
set "nzPATH=%MDPATH%\Public Folders\Ziptest.IMAP"
set "nzNEST=%nzPATH%\Nested.IMAP"
set "nzISOK=%nzPATH%\Ok.IMAP"
set "nzLOCK=%nzPATH%\nestedzip.lck"

rem we are alive
rem
echo %date% %time%> "%LOGS%\nestedzip.run"

rem Leave this place if there is no work to do
rem
if not exist "%nzPATH%\*.msg" goto :eof

rem Leave this place if we are busy already
rem
if exist "%nzLOCK%" goto :eof
echo.>   "%nzLOCK%"

rem Do some logging
rem
echo start %0 %date% %time%>> "%nzLOG%"

rem Change extensions of files we want to process to be sure MD is done with the move
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msg"') do ren "%nzPATH%\%%i" *.msz

rem Prepare folders
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :makefolder %%i

rem Check for whitelisted senders
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :whitelist %%i

rem Get mail meta data
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :metadata %%i

rem Decompose messages into components, body text, decoded attachments...
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :decompose %%i

rem Analyse the now decoded mail components
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :getzip %%i

rem Any other blacklisted attachments...
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :blacklist %%i

rem Move tainted mails to Nested folder
rem
for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzPATH%\*.msz"') do call :movenest %%i

rem If there are still *.msz in the %nzPATH% after the content has been analysed
rem these are the "good" ones. Move them to the %nzISOK% folder and rename back
rem to .msg.
rem
if exist "%nzPATH%\*.msz" (

	move "%nzPATH%\*.msz" "%nzISOK%\."
	for /f "tokens=*" %%i in ('dir /l /b /a:-d "%nzISOK%\*.msz"') do ren "%nzISOK%\%%i" *.msg
	
)

rem Feed back the messages to the local mail queue of MD.
rem CAVEAT: If you have changed the MD local queue path from default you have to do it here too.
rem 
if exist "%nzISOK%\*.msg" move "%nzISOK%\*.msg" "%MDPATH%\Queues\Local\."

rem Remove folders and meta data files
rem
rem for /f "tokens=*" %%i in ('dir /l /b /a:d "%nzPATH%\pd*"') do call :delfolder %%i

rem do some more logging
rem
echo stop %0 %date% %time%>> "%nzLOG%"
if exist "%nzLOCK%" del "%nzLOCK%"

goto :eof

rem ############################################################################################

:makefolder

	set "nzN=%~n1"
	
	mkdir "%nzPATH%\%nzN%"
	
	%debug% pause

goto :eof

rem ############################################################################################

:delfolder

	rmdir /s /q "%nzPATH%\%1"
	
	%debug% pause

goto :eof

rem ############################################################################################

:whitelist

	set "nzN=%~n1"

	grep -i "x-return-path" "%nzPATH%\%1" | grep -i "@onedomain.com" 
	if "%errorlevel%" EQU "0" echo. > "%nzPATH%\%nzN%\WHITELIST"

	grep -i "x-return-path" "%nzPATH%\%1" | grep -i "@seconddomain.com"
	if "%errorlevel%" EQU "0" echo. > "%nzPATH%\%nzN%\WHITELIST"

	%debug% pause

	goto :eof

rem ############################################################################################

:metadata

	set "nzN=%~n1"

 	for /f "tokens=*" %%i in ('grep -i "X-MDArrival-Date:" "%nzPATH%\%1"') do set "_dat=%%i"
	for /f "tokens=*" %%i in ('grep -i "X-Return-Path:" "%nzPATH%\%1"') do set "_snd=%%i"
	for /f "tokens=*" %%i in ('grep -i "X-MDaemon-Deliver-To:" "%nzPATH%\%1"') do set "_rec=%%i"
	for /f "tokens=*" %%i in ('grep -i "Subject:" "%nzPATH%\%1"') do set "_sub=%%i"
	rem this is a hack: relying on the last occurrence of subject: is the right one
	
	set "_dat=%_dat:~18%"
	set "_snd=%_snd:~15%"
	set "_rec=%_rec:~22%"
	set "_sub=%_sub:~9%"

	if "%_dat%" EQU "" set "_dat=unknown"
	if "%_snd%" EQU "" set "_snd=unknown"
	if "%_rec%" EQU "" set "_rec=unknown"
	if "%_sub%" EQU "" set "_sub=unknown"

	echo Date:     %_dat% >>  "%nzPATH%\%nzN%\%nzN%.meta"
	echo From:     %_snd% >>  "%nzPATH%\%nzN%\%nzN%.meta"
	echo To:       %_rec% >>  "%nzPATH%\%nzN%\%nzN%.meta"
	echo Subject: "%_sub%" >> "%nzPATH%\%nzN%\%nzN%.meta"

	echo header date: "%_dat%" from: "%_snd%" to: "%_rec%" sub: "%_sub%" >> "%nzLOG%"

	%debug% pause

	goto :eof

rem ############################################################################################

:decompose

	set "nzN=%~n1"

	uud64win /extract /outdir="%nzPATH%\%nzN%" "%nzPATH%\%1"

	echo. >> "%nzPATH%\%nzN%\%nzN%.meta"
	dir /b "%nzPATH%\%nzN%" >> "%nzPATH%\%nzN%\%nzN%.meta"
	rem type "%nzPATH%\%nzN%\*lst" >> "%nzPATH%\%nzN%\%nzN%.meta"
	
	%debug% pause

	goto :eof

rem ############################################################################################

:getzip
	
	set "nzN=%~n1"

	rem List content of any existing zip file and check for blacklisted attachments
	rem
	for /f "tokens=*" %%j  in ('dir /l /b /s /a:-d "%nzPATH%\%nzN%\*.zip"') do call :listzip "%%j"

	%debug% pause

	goto :eof

rem ############################################################################################

:listzip

	set "dzN=%~n1"
	set "dzPATH=%~dp1"

	rem cut trailing backslash
	set "dzPATH=%dzPath:~0,-1%"
	
	rem CAVEAT: unzip must not report back any more info than files contained in the zip.
	rem If it lists the zip name itself grep will always succeed. This is not what we want.
	rem Check that -qql (minus cue cue ell) is understood correctly
	rem
	unzip -qql "%dzPATH%\%dzN%.zip" > "%dzPATH%\%dzN%.zip.lst"

	grep -i ".zip" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"

	grep -i ".rar" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"

	grep -i ".rtf" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"

	grep -i ".js" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"

	grep -i ".dom" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"
	grep -i ".docm" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"

	grep -i ".xlm" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"
	grep -i ".xlsm" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"

	grep -i ".ppm" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"
	grep -i ".pptm" "%dzPATH%\%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" echo. > "%dzPATH%\IS_NESTED"
	
	%debug% pause

	goto :eof

rem ############################################################################################

:blacklist

	set "nzN=%~n1"

	rem Other blacklisted attachments (beside zip content)
	rem
	for /f "tokens=*" %%j in ('dir /l /b /s /a:-d "%nzPATH%\%nzN%\*.arj"') do echo. > "%nzPATH%\%nzN%\IS_NESTED"
	for /f "tokens=*" %%j in ('dir /l /b /s /a:-d "%nzPATH%\%nzN%\*.7z"')  do echo. > "%nzPATH%\%nzN%\IS_NESTED"
	for /f "tokens=*" %%j in ('dir /l /b /s /a:-d "%nzPATH%\%nzN%\*.rar"') do echo. > "%nzPATH%\%nzN%\IS_NESTED"

	%debug% pause

	goto :eof
	
rem ############################################################################################

:movenest

	set "nzN=%~n1"

	if exist "%nzPATH%\%nzN%\WHITELIST" goto :eof
	
	if exist "%nzPATH%\%nzN%\IS_NESTED" (
	
		move "%nzPATH%\%nzN%.msz" "%nzNEST%\."
		ren  "%nzNEST%\%nzN%.msz" %nzN%.msg
		call %scripts%\mail-alert.cmd "%nzPATH%\%nzN%\%nzN%.meta"
		
	)

	%debug% pause

	goto :eof

rem ############################################################################################

:eof
rem eof nestedzip.cmd 
