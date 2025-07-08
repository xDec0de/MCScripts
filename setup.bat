@echo off
setlocal EnableDelayedExpansion

echo ===========================================
echo Loading variables from mcsconfig.env...
echo ===========================================

if not exist mcsconfig.env (
    echo ERROR: mcsconfig.env not found.
    goto end
)

for /f "usebackq tokens=1,* delims==" %%a in ("mcsconfig.env") do (
    set "%%a=%%b"
)

if not defined PROJECT (
    echo ERROR: Variable PROJECT is not defined in mcsconfig.env
    goto end
)

echo PROJECT = %PROJECT%
echo VERSION = %VERSION%
echo MEMORY = %MEMORY%

echo ===========================================
echo Attempting to run bash script...
echo ===========================================

where bash >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo bash is available. Trying to run setup.sh...
    if exist setup.sh (
        bash setup.sh
        set "bashExitCode=!ERRORLEVEL!"
        echo Bash script exited with code !bashExitCode!
        if !bashExitCode! equ 0 (
            echo setup.sh ran successfully.
            goto end
        ) else (
            echo setup.sh failed. Will try setup.ps1...
        )
    ) else (
        echo setup.sh not found. Skipping to setup.ps1...
    )
) else (
    echo bash not found. Skipping to setup.ps1...
)

echo ===========================================
echo Attempting to run powershell script...
echo ===========================================

if exist setup.ps1 (
    powershell -ExecutionPolicy Bypass -File setup.ps1
    set "psExitCode=!ERRORLEVEL!"
    echo PowerShell script exited with code !psExitCode!
    if !psExitCode! equ 0 (
        echo setup.ps1 ran successfully.
        goto end
    ) else (
        echo setup.ps1 failed. Will attempt to run jar directly...
    )
) else (
    echo setup.ps1 not found. Will attempt to run jar directly...
)

echo ===========================================
echo Attempting to run %PROJECT%.jar directly...
echo ===========================================

if exist "%PROJECT%.jar" (
    echo Running: java -jar "%PROJECT%.jar"
    java -jar "%PROJECT%.jar"
    echo Jar execution finished with code %ERRORLEVEL%
) else (
    echo ERROR: File %PROJECT%.jar not found.
)

:end
echo ===========================================
echo Script finished. Press any key to exit.
echo ===========================================
pause
endlocal
