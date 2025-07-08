@echo off
setlocal EnableDelayedExpansion

set CONFIG_FILE=mcsconfig.env

:: Check if config already exists
if exist "%CONFIG_FILE%" (
    echo ===============================================================
    echo  Using existing configuration:
    echo ---------------------------------------------------------------
    type "%CONFIG_FILE%"
    echo ===============================================================
    goto :RUN_SETUP
)

echo ===============================================================
echo  MCScripts Config Generator
echo ===============================================================

:: Prompt for PROJECT
:PROJECT_PROMPT
set /p PROJECT=Project (paper, folia, velocity, waterfall) [paper]: 
if "%PROJECT%"=="" set PROJECT=paper

if /I "%PROJECT%"=="paper" goto :PROJECT_OK
if /I "%PROJECT%"=="folia" goto :PROJECT_OK
if /I "%PROJECT%"=="velocity" goto :PROJECT_OK
if /I "%PROJECT%"=="waterfall" goto :PROJECT_OK

echo Invalid project. Please choose: paper, folia, velocity, or waterfall.
goto :PROJECT_PROMPT

:PROJECT_OK

:: Prompt for VERSION
set /p VERSION=Version (latest or specific version) [latest]: 
if "%VERSION%"=="" set VERSION=latest

:: Prompt for MEMORY
:MEMORY_PROMPT
set /p MEMORY=Memory allocation (e.g., 4G or 512M) [1G]: 
if "%MEMORY%"=="" set MEMORY=1G

setlocal EnableDelayedExpansion

:: Separate number and unit
set "MEM_UNIT=!MEMORY:~-1!"
set "MEM_NUMBER=!MEMORY:~0,-1!"

:: Check if MEM_UNIT is M or G (case-insensitive)
if /i not "!MEM_UNIT!"=="M" if /i not "!MEM_UNIT!"=="G" (
    echo Invalid memory unit: must end with M or G.
    endlocal
    goto :MEMORY_PROMPT
)

:: Check if MEM_NUMBER is numeric
set /a TEST_NUM=!MEM_NUMBER! 2>nul
if errorlevel 1 (
    echo Invalid memory value: must be a number before M or G.
    endlocal
    goto :MEMORY_PROMPT
)

endlocal
goto :MEMORY_OK

:MEMORY_OK

:: Prompt for JVM_FLAGS
set /p JVM_INPUT=Optional JVM Flags (empty or custom, "aikar" is replaced) [empty]: 

set AIKAR_FLAGS=-XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true

set JVM_FLAGS=%JVM_INPUT%
echo %JVM_INPUT% | findstr /I "aikar" >nul
if not errorlevel 1 (
    set JVM_FLAGS=!JVM_INPUT:aikar=%AIKAR_FLAGS%!
)

:: Prompt for JAR_FLAGS
set /p JAR_FLAGS=Optional JAR Flags (leave empty to skip): 

:: Write config
(
echo PROJECT=%PROJECT%
echo VERSION=%VERSION%
echo MEMORY=%MEMORY%
echo JVM_FLAGS=%JVM_FLAGS%
echo JAR_FLAGS=%JAR_FLAGS%
) > "%CONFIG_FILE%"

echo.
echo ===============================================================
echo  Configuration saved to %CONFIG_FILE%
echo ---------------------------------------------------------------
type "%CONFIG_FILE%"
echo ===============================================================

:RUN_SETUP

:: Check for Java
where java >nul 2>nul
if errorlevel 1 (
    echo.
    echo Java is not installed or not in PATH. Please install Java.
    echo.
    goto :EOF
)

:: Prepare download of setup.ps1
set SETUP_URL=https://raw.githubusercontent.com/xDec0de/MCScripts/main/setup.ps1
set SETUP_FILE=setup.ps1

echo.
echo ===============================================================
echo Downloading setup.ps1...
echo ===============================================================

:: Try PowerShell Invoke-WebRequest (preferred)
powershell -Command "try { Invoke-WebRequest -Uri '%SETUP_URL%' -OutFile '%SETUP_FILE%' -UseBasicParsing } catch { exit 1 }"
if exist "%SETUP_FILE%" goto :RUN_PS1

:: Fallback to bitsadmin (for older Windows)
bitsadmin /transfer "DownloadSetup" %SETUP_URL% "%SETUP_FILE%"
if exist "%SETUP_FILE%" goto :RUN_PS1

echo.
echo Failed to download setup.ps1. Please download manually from:
echo %SETUP_URL%
goto :EOF

:RUN_PS1

echo.
echo ===============================================================
echo Running setup.ps1...
echo ===============================================================
powershell -ExecutionPolicy Bypass -File "%SETUP_FILE%"

if errorlevel 1 (
    echo.
    echo setup.ps1 failed to execute.
    echo.
    goto :EOF
)

