@echo off

set nzPATH="d:\Wan\MDaemon\Public Folders\Ziptest.IMAP"

echo start %date% %time%>> %nzPATH%\nestedzip.log

if not exist %nzPATH%\*.msg goto :eof

for /f "tokens=*" %%i in ('dir /l /b /a:-d %nzPATH%\*.msg') do ren %nzPATH%\%%i *.msz

rem für alle existierenden .msz
for /f "tokens=*" %%i in ('dir /l /b /a:-d %nzPATH%\*.msz') do call :decompose %%i
	
rem für alle decomposed mails
for /f "tokens=*" %%i in ('dir /l /b /a:d %nzPATH%\pd*') do call :getzip %%i

move %nzPATH%\*.msz %nzPATH%\Ok.IMAP\.

for /f "tokens=*" %%i in ('dir /l /b /a:-d %nzPATH%\Ok.IMAP\*.msz') do ren %nzPATH%\Ok.IMAP\%%i *.msg

move %nzPATH%\Ok.IMAP\*.msg D:\Wan\MDaemon\Queues\Local\.

echo stop %date% %time%>> %nzPATH%\nestedzip.log

goto :eof

:decompose

	set dzN=%~n1
	set dzPATH=%nzPATH:"=%
	
	rem verzeichnis anlegen aus namen
	mkdir "%dzPATH%\%dzN%"

	rem dorthin decomposen
	uud64win /extract /outdir="%dzPATH%\%dzN%" "%dzPATH%\%1"
	
	goto :eof

:getzip
	
	set IS_NESTED=N
	
	for /f "tokens=*" %%j  in ('dir /l /b /s /a:-d %nzPATH%\%1\*.zip') do call :listzip "%%j"

	if "%IS_NESTED%" EQU "Y" (
	
		move %nzPATH%\%1.msz %nzPATH%\Nested.IMAP\.
		ren  %nzPATH%\Nested.IMAP\%1.msz %1.msg
		
	)
	
	rmdir /s /q %nzPATH%\%1
	
	goto :eof

:listzip

	set dzN=%~n1
	set dzPATH=%~dp1
	
	unzip -qql "%dzPATH%%dzN%.zip" > "%dzPATH%%dzN%.zip.lst"

	grep ".zip" "%dzPATH%%dzN%.zip.lst"
	if "%errorlevel%" EQU "0" set IS_NESTED=Y
	
	goto :eof

:eof
