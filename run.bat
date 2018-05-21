@echo off

cd src/bin/

if exist main.obj del main.obj
if exist main.exe del main.exe

ml /c /coff ../main.asm
if errorlevel 1 goto errasm

Link /SUBSYSTEM:CONSOLE /OPT:NOREF main.obj
if errorlevel 1 goto errlink

cls

main.exe
goto end

:errlink
echo _
echo Link error
goto end

:errasm
echo _
echo Assembly Error
goto end

:end
cd ../../
