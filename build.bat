@echo off
rem Real build (needs Person 2 file logic.asm in this folder). Run inside DOSBox.
nasm mario.asm -f bin -o mario.com
if errorlevel 1 goto fail
echo OK - mario.com is ready
goto end
:fail
echo BUILD FAILED - read the error lines above
:end
