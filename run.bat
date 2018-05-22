@echo off

cd src/

if exist main.obj del main.obj
if exist main.exe del main.exe

bldall main && main.exe && cls && cd ../
