## CREACION DE DOCKER PRODUCTION (PROD) Y DEVELOPMENT (DEV) 

1. Renombramos mi contenedor original para que sea produccion, para esto usamos el comando:
```bash
docker rename oracle11g-local oracle11g-prod
```

2. Creamos el nuevo contenedor para pruebas y testing (DEVELOPMENT):
```bash
docker run -d \
  --name oracle11g-dev \
  -p 1522:1521 \
  -e ORACLE_PASSWORD="admin123" \
  -v oracle11g_dev_data:/u01/app/oracle/oradata \
  -v "C:/BasesDatosOracle/backup:/backup" \
  gvenzl/oracle-xe:11
```

3. Ahora configuramos esta PC para que cualquiera se pueda conectar a la base de datos Oracle Docker Dev:  
Permitir Oracle en el Firewall de Windows, para esto en la PowerShell, ejecutamos:
```bash
New-NetFirewallRule `
  -DisplayName "Oracle Docker Dev 1522" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 1522 `
  -Action Allow
```

Para probar desde mi propia PC
```bash
Get-NetFirewallRule -DisplayName "Oracle Docker Dev 1522"
```

Y para probar desde otra PC
```bash
Test-NetConnection 192.103.1.90 -Port 1522      # DEVUELVE TRUE
```

4. Desde DBeaver creamos los usuarios/esquemas GXCONTABLE y GXGAM:
```sql

-- GXCONTABLE
CREATE USER GXCONTABLE
IDENTIFIED BY "CONTRASEÑA_GXCONTABLE"  -- seria la contraseña que le quiero poner al esquema que voy a crear
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;

ALTER USER GXCONTABLE
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO GXCONTABLE;
GRANT ALTER SESSION TO GXCONTABLE;

-- PERMISOS 
GRANT CREATE TABLE TO GXCONTABLE;
GRANT CREATE VIEW TO GXCONTABLE;
GRANT CREATE SEQUENCE TO GXCONTABLE;
GRANT CREATE PROCEDURE TO GXCONTABLE;
GRANT CREATE TRIGGER TO GXCONTABLE;
GRANT CREATE TYPE TO GXCONTABLE;
GRANT CREATE SYNONYM TO GXCONTABLE;
GRANT CREATE DATABASE LINK TO GXCONTABLE;
GRANT CREATE JOB TO GXCONTABLE;

-- GXGAM
CREATE USER GXGAM
IDENTIFIED BY "CONTRASEÑA_GXGAM"  -- seria la contraseña que le quiero poner al esquema que voy a crear
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;

ALTER USER GXGAM
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO GXGAM;
GRANT ALTER SESSION TO GXGAM;

-- PERMISOS 
GRANT CREATE TABLE TO GXGAM;
GRANT CREATE VIEW TO GXGAM;
GRANT CREATE SEQUENCE TO GXGAM;
GRANT CREATE PROCEDURE TO GXGAM;
GRANT CREATE TRIGGER TO GXGAM;
GRANT CREATE TYPE TO GXGAM;
GRANT CREATE SYNONYM TO GXGAM;
GRANT CREATE DATABASE LINK TO GXGAM;
GRANT CREATE JOB TO GXGAM;


-- CREAMOS EL DIRECTORIO QUE NOS VA A SERVIR PARA HACER BACKUPS Y RESTORE DE BASES DE DATOS:
CREATE OR REPLACE DIRECTORY BACKUP_DIR AS '/backup';

-- PARA COMPROBAR EJECUTAMOS:
SELECT DIRECTORY_NAME, DIRECTORY_PATH
FROM DBA_DIRECTORIES
WHERE DIRECTORY_NAME = 'BACKUP_DIR';

-- DAMOS PERMISOS AL DIRECTORIO PARA QUE PUEDA TRABAJAR TRANQUILAMENTE CON GXCONTABLE Y GXGAM
GRANT READ, WRITE ON DIRECTORY BACKUP_DIR TO GXCONTABLE;
GRANT READ, WRITE ON DIRECTORY BACKUP_DIR TO GXGAM;
```

5. Dentro del contenedor **oracle11g-prod** realizamos los **BACKUPS** con los comandos:
```bash
expdp system@XE \
  schemas=GXCONTABLE \
  directory=BACKUP_DIR \
  dumpfile=GXCONTABLE_backup.dmp \
  logfile=GXCONTABLE_backup.log
```

```bash
expdp system@XE \
  schemas=GXGAM \
  directory=BACKUP_DIR \
  dumpfile=GXGAM_backup.dmp \
  logfile=GXGAM_backup.log
```

6. Ahora en el contenedor **oracle11g-dev** realizamos el **RESTORE**, para esto en nuestro contenedor ejecutamos:

```bash
impdp system@XE \
DIRECTORY=BACKUP_DIR \
DUMPFILE=GXCONTABLE_backup.dmp \
LOGFILE=verificacion_import.log \
SQLFILE=verificacion_import.sql
```

```bash
impdp system@XE \
DIRECTORY=BACKUP_DIR \
DUMPFILE=GXGAM_backup.dmp \
LOGFILE=verificacion_import.log \
SQLFILE=verificacion_import.sql
```

Luego ejecutamos: 
```bash
grep -o 'TABLESPACE "[^"]*"' /backup/verificacion_import.sql | sort -u
```
Este nos da: TABLESPACE "TABLASMIGRACION" --> que es el que se usa en REMAP_TABLESPACE
del comando que sigue despues de este.

Y por ultimo podemos hacer el **RESTORE** de las bases de datos con los comandos:

```bash
impdp system@XE \
DIRECTORY=BACKUP_DIR \
DUMPFILE=GXCONTABLE_backup.dmp \
LOGFILE=GXCONTABLE_backup.log \
SCHEMAS=GXCONTABLE \
REMAP_TABLESPACE=TABLASMIGRACION:USERS
```

```bash
impdp system@XE \
DIRECTORY=BACKUP_DIR \
DUMPFILE=GXGAM_backup.dmp \
LOGFILE=GXGAM_backup.log \
SCHEMAS=GXGAM \
REMAP_TABLESPACE=TABLASMIGRACION:USERS
```

## Database Link (DBLink) en el contenedor oracle11g-dev

Necesito crear un **DBLink** de **Oracle 11g** a **SQL Server 2005**  
Para esto realizamos:  
Primero revisamos si tenemos instalado **dg4odbc** en nuesto contenedor, para esto ejecutamos:

```bash
echo $ORACLE_HOME
```

Esto nos confirma qu estamos usando Oracle Database 11g XE y para verificar si tenemos instalado/configurado **dg4odbc** buscamos los siguientes directorios:

```bash
ls -l /u01/app/oracle/product/11.2.0/xe/bin/dg4odbc  -- OK!!!
ls -l /u01/app/oracle/product/11.2.0/xe/hs/admin     -- OK!!!
ls -ld /u01/app/oracle/product/11.2.0/xe/hs          -- OK!!!
uname -m                                             -- OK!!! (nos devolvio x86_64)
cat /etc/os-release                                  -- ERROR
odbcinst -j                                          -- ERROR
file /u01/app/oracle/product/11.2.0/xe/bin/dg4odbc   -- ERROR
which dnf                                            -- ERROR
which yum                                            -- ERROR
dnf repolist                                         -- ERROR
tsql -C                                              -- ERROR
```

Ahora vamos a ver los repositorios que tenemos habilitados:

```bash
microdnf repolist
```

Esto nos confirma que tenemos el repositorio estandar de Oracle Linux 8 (ol8_appstream, ol8_baseos_latest)

Instalamos **unixODBC**

```bash
microdnf install -y unixODBC
odbcinst -j                  -- para verificar si se instalo bien
isql --version               -- nos dice la version que tenemos de unixODBC
rpm -qa | grep -i odbc       -- nos devuelve unixODBC-2.3.7-2.el8_10.x86_64
```

Ahora instalamos **FreeTDS** que es el Driver que se encarga de hablar con **SQL Server 2005**.  
Pero para hacer esto primero tenemos que habilitar el repositorio **EPEL**

```bash
microdnf install -y oracle-epel-release-el8
microdnf repolist                               -- para verificar el listado de paquetes
```

Ahora si podemos instalar **FreeTDS** con el comando

```bash
microdnf install -y freetds
```

para probar la coneccion:

```bash
TDSVER=7.0 tsql -H 172.16.109.7 -p 3750 -U america
```

Entonces el problema era la version del **TDS** (Tabular Data Stream) que es el protocolo que usan los clientes para habla con SQL server 2005.  
Para actualizarla utilizamos como root:

```bash
microdnf install nano       # instalar nano
nano /etc/freetds.conf
```

y cambiamos el TDS a la version 7.0

```ini
[MSSQL2005]
    host = 172.16.109.7
    port = 3750
    tds version = 7.0
    client charset = UTF-8
```

Una vez actualizado salimos del usuario root y reiniciamos el contenedor, volvemos al contenedor y ejecutamos:

```bash
$ docker exec -it oracle11g-local bash
bash-4.4$ tsql -S MSSQL2005 -U america
Password:
locale is "C"
locale charset is "ANSI_X3.4-1968"
using default charset "UTF-8"
1> USE COSAYSA_PRESU
2> GO
1> SELECT TOP 5 * FROM dbo.NUEVAS_LOCALIDADES
2> GO
codigo  descrip
LOCAL00 TOTAL
LOCAL10 TOTAL Capital
LOCAL90 TOTAL Rº de la Frontera
LOCAL11 CAPITAL
LOCAL11 CAPITAL
(5 rows affected)
1>
```

Donde si pude conectarme y traer las tabla tabla que yo queria.  
Todo lo que hicimos hasta ahora era una coneccion **tsql** para ver si se podian comunicar.  
Ahora tenemos que convertir esta conexion en una conexion **ODBC formal** para que despues la pueda usar oracle mediante **dg4odbc**.

Para esto nos logueamos como root y realizamos:

```bash
nano /etc/odbcinst.ini                              -- LO REVISE Y YA TIENE AGREGADO FreeTDS
odbcinst -q -d                                      -- OK!!! YA QUE SE ENCUENTRA FreeTDS EN SU LISTADO
nano /etc/odbc.ini                                  -- CONFIGURAMOS ESTE ARCHIVO
```

Y en este archivo odbc.ini agregamos:

```ini
[MSSQL]
Description = SQL Server 2005 COSAYSA_PRESU
Driver = FreeTDS
Server = 172.16.109.7
Port = 3750
Database = COSAYSA_PRESU
TDS_Version = 7.0
ClientCharset = UTF-8
```

Ahora si empieza la parte **Oracle** &rarr; **ODBC**  
Vamos a crear el archivo gateway:

```bash
nano /u01/app/oracle/product/11.2.0/xe/hs/admin/initMSSQL.ora       # CREAMOS ESTE ARCHIVO
```

Y aqui ponemos:

```bash
HS_FDS_CONNECT_INFO = MSSQL     #Hace referencia al DNS [MSSQL] que creamos anteriormente
HS_FDS_TRACE_LEVEL = DEBUG
HS_FDS_SHAREABLE_NAME = /usr/lib64/libodbc.so
HS_NLS_NCHAR = UCS2

set ODBCSYSINI=/etc
set ODBCINI=/etc/odbc.ini
```

Ahora seguimos con el listener de Oracle:

```bash
nano /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora
cp /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora.bak     # Hacemos una copia del listener
```

Actualizar el archivo listener.ora y reemplazar su contenido por:

```bash
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (SID_NAME = PLSExtProc)
      (ORACLE_HOME = /u01/app/oracle/product/11.2.0/xe)
      (PROGRAM = extproc)
    )

    (SID_DESC =
      (SID_NAME = MSSQL)
      (ORACLE_HOME = /u01/app/oracle/product/11.2.0/xe)
      (PROGRAM = dg4odbc)
    )
  )

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
    )
  )

DEFAULT_SERVICE_LISTENER = (XE)

```

Luego de modificar el archivo reiniciamos completamente el listener:

```bash
lsnrctl stop
lsnrctl start
lsnrctl reload      # reinicimos
lsnrctl status
```

Ahora pasamos al archivo tnsnames.ora

```bash
nano /u01/app/oracle/product/11.2.0/xe/network/admin/tnsnames.ora
cp /u01/app/oracle/product/11.2.0/xe/network/admin/tnsnames.ora /u01/app/oracle/product/11.2.0/xe/network/admin/tnsnames.ora.bak    # hacemos una copia
```

Y al final de este archivo agregamos:

```bash
MSSQL =
  (DESCRIPTION =
    (ADDRESS =
      (PROTOCOL = TCP)
      (HOST = 127.0.0.1)
      (PORT = 1521)
    )
    (CONNECT_DATA =
      (SID = MSSQL)
    )
    (HS = OK)
  )
```

Luego de modificar el archivo ejecutamos:

```bash
tnsping MSSQL       # ME DEVUELVE OK
```

Con esto estaria todo listo, y en este caso no haria falta crear el **Database Link** ya que se incluyo cuando realizamos el restore de GXCONTABLE. Ahora en Dbeaver loguado como GXCONTABLE puedo realizar las siguientes consultas:

```sql
-- SINTAXIS PARA HACER ALGUNOS SELECT
SELECT *
FROM "dbo"."NUEVAS_LOCALIDADES"@MSSQL
WHERE ROWNUM <= 5;

SELECT * FROM "auxiliares"@MSSQL;

SELECT *
FROM "auxiliares"@MSSQL
WHERE UPPER("auxi_tipo") LIKE '%LOCAL%';
```

Ahora para hacer que el contenedor se inicialice automaticamente cada vez que se prende o reinicia el servidor ejecutamos los comandos:
```bash
docker update --restart unless-stopped oracle11g-prod
docker update --restart unless-stopped oracle11g-dev
```