@ECHO OFF

REM Use this if there are any changes to resources.rc.
REM resources\RC\rc.exe resources\resources.rc

dub.exe build --quiet --arch=x86_64
REM dub.exe build --build=release --quiet --arch=x86_64

IF %ERRORLEVEL% NEQ 0 GOTO END

    ECHO Running...

    PUSHD bin
    START "SQLPlusX Build" /B SQLPlusX.exe
    POPD

IF %ERRORLEVEL% NEQ 0 GOTO END

    dub.exe test --quiet --arch=x86_64

:END

PAUSE
