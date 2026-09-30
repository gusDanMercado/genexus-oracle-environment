@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM CONFIGURACION
REM ============================================================

set "CONTAINER=oracle11g-local"
set "BACKUP_HOST=C:\GustavoMercado\genexus-oracle-environment\backup"
set "PASSWORD_FILE=C:\GustavoMercado\genexus-oracle-environment\scripts\oracle_backup_password.txt"
set "RETENTION_DAYS=30"

REM ============================================================
REM VALIDACIONES
REM ============================================================

if not exist "%PASSWORD_FILE%" (
    echo ERROR: No existe el archivo de password:
    echo %PASSWORD_FILE%
    exit /b 1
)

if not exist "%BACKUP_HOST%" (
    echo ERROR: No existe la carpeta de backup:
    echo %BACKUP_HOST%
    exit /b 1
)

for /f "usebackq delims=" %%P in ("%PASSWORD_FILE%") do (
    set "ORACLE_PASSWORD=%%P"
)

if "%ORACLE_PASSWORD%"=="" (
    echo ERROR: El archivo de password esta vacio.
    exit /b 1
)

REM ============================================================
REM FECHA Y HORA
REM ============================================================

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "FECHA=%%I"

set "GENERAL_LOG=%BACKUP_HOST%\backup_general_%FECHA%.log"

echo ============================================================ > "%GENERAL_LOG%"
echo BACKUP ORACLE - %DATE% %TIME% >> "%GENERAL_LOG%"
echo ============================================================ >> "%GENERAL_LOG%"
echo. >> "%GENERAL_LOG%"

REM ============================================================
REM VERIFICAR QUE EL CONTENEDOR ESTE CORRIENDO
REM ============================================================

docker inspect -f "{{.State.Running}}" %CONTAINER% 2>nul | findstr /I "true" >nul

if errorlevel 1 (
    echo ERROR: El contenedor %CONTAINER% no esta ejecutandose. >> "%GENERAL_LOG%"
    echo ERROR: El contenedor %CONTAINER% no esta ejecutandose.
    exit /b 1
)

echo Contenedor %CONTAINER% OK. >> "%GENERAL_LOG%"

REM ============================================================
REM BACKUP GXCONTABLE
REM ============================================================

echo.
echo Exportando GXCONTABLE...
echo Exportando GXCONTABLE... >> "%GENERAL_LOG%"

docker exec %CONTAINER% bash -c ^
"expdp system/%ORACLE_PASSWORD%@XE schemas=GXCONTABLE directory=BACKUP_DIR dumpfile=GXCONTABLE_%FECHA%.dmp logfile=GXCONTABLE_%FECHA%.log"

if errorlevel 1 (
    echo ERROR: Fallo el backup de GXCONTABLE. >> "%GENERAL_LOG%"
    echo ERROR: Fallo el backup de GXCONTABLE.
    set "ERROR_BACKUP=1"
) else (
    echo GXCONTABLE exportado correctamente. >> "%GENERAL_LOG%"
    echo GXCONTABLE exportado correctamente.
)

REM ============================================================
REM BACKUP GXGAM
REM ============================================================

echo.
echo Exportando GXGAM...
echo Exportando GXGAM... >> "%GENERAL_LOG%"

docker exec %CONTAINER% bash -c ^
"expdp system/%ORACLE_PASSWORD%@XE schemas=GXGAM directory=BACKUP_DIR dumpfile=GXGAM_%FECHA%.dmp logfile=GXGAM_%FECHA%.log"

if errorlevel 1 (
    echo ERROR: Fallo el backup de GXGAM. >> "%GENERAL_LOG%"
    echo ERROR: Fallo el backup de GXGAM.
    set "ERROR_BACKUP=1"
) else (
    echo GXGAM exportado correctamente. >> "%GENERAL_LOG%"
    echo GXGAM exportado correctamente.
)

REM ============================================================
REM ELIMINAR BACKUPS ANTIGUOS
REM ============================================================

echo.
echo Eliminando backups con mas de %RETENTION_DAYS% dias...
echo Eliminando backups con mas de %RETENTION_DAYS% dias... >> "%GENERAL_LOG%"

forfiles /p "%BACKUP_HOST%" /m "GXCONTABLE_*.dmp" /d -%RETENTION_DAYS% /c "cmd /c del /q @path" 2>nul
forfiles /p "%BACKUP_HOST%" /m "GXCONTABLE_*.log" /d -%RETENTION_DAYS% /c "cmd /c del /q @path" 2>nul

forfiles /p "%BACKUP_HOST%" /m "GXGAM_*.dmp" /d -%RETENTION_DAYS% /c "cmd /c del /q @path" 2>nul
forfiles /p "%BACKUP_HOST%" /m "GXGAM_*.log" /d -%RETENTION_DAYS% /c "cmd /c del /q @path" 2>nul

forfiles /p "%BACKUP_HOST%" /m "backup_general_*.log" /d -%RETENTION_DAYS% /c "cmd /c del /q @path" 2>nul

REM ============================================================
REM RESULTADO FINAL
REM ============================================================

echo. >> "%GENERAL_LOG%"
echo ============================================================ >> "%GENERAL_LOG%"

if defined ERROR_BACKUP (
    echo BACKUP FINALIZADO CON ERRORES. >> "%GENERAL_LOG%"
    echo BACKUP FINALIZADO CON ERRORES.
    echo Revisar: %GENERAL_LOG%
    exit /b 1
)

echo BACKUP FINALIZADO CORRECTAMENTE. >> "%GENERAL_LOG%"
echo BACKUP FINALIZADO CORRECTAMENTE.
echo Log general:
echo %GENERAL_LOG%

exit /b 0