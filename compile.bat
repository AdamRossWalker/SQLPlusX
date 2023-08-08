@ECHO OFF

REM Use this if there are any changes to resources.rc.
REM resources\RC\rc.exe resources\resources.rc

dub.exe build --quiet --arch=x86_64 2> compiler_output.txt
REM dub.exe build --build=release --quiet --arch=x86_64

IF %ERRORLEVEL% NEQ 0 GOTO ERRORS

    ECHO Running...

    PUSHD bin
    START "SQLPlusX Build" /B SQLPlusX.exe 2> compiler_output.txt
    POPD

IF %ERRORLEVEL% NEQ 0 GOTO ERRORS

    dub.exe test --quiet --arch=x86_64 2> compiler_output.txt

IF %ERRORLEVEL% NEQ 0 GOTO ERRORS

REM Clear the output.
TYPE NUL > compiler_output.txt

GOTO END

:ERRORS

compiler_output.txt

:END
