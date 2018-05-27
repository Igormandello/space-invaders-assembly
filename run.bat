@echo off

if not exist bin mkdir bin

cd bin

rc /v ../src/rsrc.rc
cvtres /machine:ix86 ../src/rsrc.res

if exist main.obj del main.obj
if exist main.exe del main.exe

ml /c /coff ../src/main.asm
if errorlevel 1 goto errasm

if not exist ../src/rsrc.obj goto nores

Link /SUBSYSTEM:WINDOWS /OPT:NOREF main.obj ../src/rsrc.obj
if errorlevel 1 goto errlink

main.exe
cls
goto TheEnd

:errlink
echo _
echo Link error
goto TheEnd

:errasm
echo _
echo Assembly Error
goto TheEnd

:TheEnd
cd ../
