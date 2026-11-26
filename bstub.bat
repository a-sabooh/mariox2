@echo off
rem Solo test build, stub.asm replaces Person 2 code. Run inside DOSBox.
nasm mario.asm -f bin -o mario.com -dUSE_STUB
if errorlevel 1 goto fail
echo OK - mario.com is ready
goto end
:fail
echo BUILD FAILED - read the error lines above
:end
