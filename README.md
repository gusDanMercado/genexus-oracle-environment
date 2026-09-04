# DOCKER - ORACLE 11g 

## Intalacion Docker
Instalar "Docker Desktop Installer.exe"
   * Aqui solo pongo siguiente a todo y lo dejo como esta
   * Abrir Docker Desktop desde el acceso directo en el escritorio
   * Aqui no me logueo ni creo ninguna cuenta ni nada, pongo SKIP 
   * Siempre que se quiera utilizar Docker tenemos que Ejecutar Docker Desktop ya que no vamos a tener Docker habilitado para utilizarlo
   * Siempre que se trabaje con Docker dejar este programa abierto

## Creacion Contenedor Oracle 11g
Una vez que tengamos nuestro archivo .yml creado con todas las configuraciones necesarias ejecutamos:

```bash
docker compose -f docker-compose.oracle11g.yml up -d
```

Para ver si se creo correctamente:
```bash
docker ps
```

Para ingresar al contendor utilizamos:
```bash
docker exec -it oracle11g-local bash
```

y para salir del contenedor utilizamos: exit

## Primera coneccion a nuestra Base de Datos Oracle
Como este contenedor es de una Base de Datos Oracle voy a usar **Dbeaver** para conectarme al contenedor y trabajar de manera mas comoda.  
Y aqui hacemos nuestra primera coneccion (ver imagen primeraConeccionOracle) utilizando el usuario SYSTEM que es uno de los usuarios administradores de Oracle por defecto

Características de SYSTEM
* Viene creado automáticamente al instalar Oracle. 
* Tiene el rol de DBA asignado por defecto.
* Permite crear otros usuarios, tablas y gestionar la seguridad, aunque no debe usarse para tareas del núcleo que le corresponden a SYS.

y aqui ejecutamos:
```sql
-- CREAMOS EL DIRECTORIO
CREATE OR REPLACE DIRECTORY BACKUP_DIR AS '/backup';

-- PARA COMPROBAR EJECUTAMOS:
SELECT DIRECTORY_NAME, DIRECTORY_PATH
FROM DBA_DIRECTORIES
WHERE DIRECTORY_NAME = 'BACKUP_DIR';

CREATE USER GXCONTABLE
IDENTIFIED BY "TU_PASSWORD_LOCAL"  -- seria la contraseña que le quiero poner al esquema que voy a crear
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
```

Reiniciamos nuestro contenedor

## Restore de la Base de Datos Oracle
Para subir el Backup de nuestra base de datos gxcontableDP20260901.dmp tenemos que guardarlo en la carpeta backup de nuestro contenedor.   
Para saber donde se encuentra ejecutamos:
```bash
docker inspect oracle11g-local --format '{{range .Mounts}}{{println .Type .Source "->" .Destination}}{{end}}'
```

y en nuestro caso esto nos devuelve:
```bash
volume /var/lib/docker/volumes/oracle11g_local_data/_data -> /u01/app/oracle/oradata
bind /run/desktop/mnt/host/c/GustavoMercado/genexus-oracle-environment/backup -> /backup
```

Esto quiere decir, que tenemos que pegar nuestro archivo .dmp en:
```bash
C:\GustavoMercado\genexus-oracle-environment\backup
```

Una vez que el archivo este en la carpeta backup, entramos a nuestro contenedor y ejecutamos:
```bash
impdp system@XE \
DIRECTORY=BACKUP_DIR \
DUMPFILE=gxcontableDP20260901.dmp \
LOGFILE=verificacion_import.log \
SQLFILE=verificacion_import.sql
```

Luego ejecutamos: 
```bash
grep -o 'TABLESPACE "[^"]*"' /backup/verificacion_import.sql | sort -u
```
Este nos da: TABLESPACE "TABLASMIGRACION" --> que es el que se usa en REMAP_TABLESPACE
del comando que sigue despues de este.

Y por ultimo podemos hacer el **RESTORE** de la base de datos con el comando:
```bash
impdp system@XE \
DIRECTORY=BACKUP_DIR \
DUMPFILE=gxcontableDP20260901.dmp \
LOGFILE=gxcontable_import.log \
SCHEMAS=GXCONTABLE \
REMAP_TABLESPACE=TABLASMIGRACION:USERS
```

Este comando demora un poco y en caso de querer ver el log generado ejecutamos:
```bash
grep -i "ORA-" /backup/gxcontable_import.log
```

Y cuando ejecutemos los comandos anteriores y nos pidan las credenciales utilizamos la contraseña: **ORACLE_PASSWORD** --> que es la contraseña que configure en mi archivo .yml

## Database Link (DBLink)
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

Como los ultimos comandos anteriores no dieron errores de "command not found" salimos del contenedor y se logeamos como **root** (-u 0 --> sale el signo # en lugar del signo $) con el comando:
```bash
docker exec -u 0 -it oracle11g-local bash
```

Aqui ejecutamos los comandos:
```bash
id                      -- uid=0(root) gid=0(root) groups=0(root)
command -v microdnf     -- OK!!!
command -v rpm          -- OK!!!
command -v dnf          -- VACIO (ES DECIR, NO LO TENGO INSTALADO)
command -v yum          -- VACIO (ES DECIR, NO LO TENGO INSTALADO)
ls -l /usr/bin/microdnf /usr/bin/rpm /usr/bin/dnf /usr/bin/yum 2>/dev/null      -- OK!!!
rpm -qa | grep -Ei 'odbc|freetds'                                               -- VACIO (ES DECIR, NO LO TENGO INSTALADO)
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

Ultimo control de los paquetes instalados, me tiene que dar:  
![imagen](img\DBLink.png)

Asta aqui ya tenemos todos los paquetes necesarios para comunicarse con SQL Server 2005.

Ahora salimos del usuario root y reiniciamos el contenedor y ya no utilizamos el usuario root.  

Para probar la coneccion ingremos nuevamente a nuestro contenedor y ejecutamos:
```bash
tsql -H 172.16.109.7 -p 3750 -U america

TDSVER=7.2 tsql -H 172.16.109.7 -p 3750 -U america

timeout 5 bash -c 'cat < /dev/null > /dev/tcp/172.16.109.7/3750' && echo "PUERTO OK" || echo "PUERTO NO ACCESIBLE"

TDSDUMP=/tmp/tds.log TDSVER=7.2 tsql -H 172.16.109.7 -p 3750 -U america

LANG=C.UTF-8 TDSVER=7.2 tsql -H 172.16.109.7 -p 3750 -U america

LANG=en_US.UTF-8 TDSVER=7.2 tsql -H 172.16.109.7 -p 3750 -U america
```

No se conecto con ninguno de estos comandos ya que esta deshabilitando TLS 1.0 y TLS 1.1  
Para solucionar esto nos volvemos a logear como root y ejecutamos:
```bash
update-crypto-policies --show                    -- ERROR
cat /etc/freetds.conf                            -- EJECUTAMOS ESTE E IGNORAMOS EL ANTERIOR ES CASO DE QUE EL ANTERIOR DE ERROR
cp /etc/freetds.conf /etc/freetds.conf.bak       -- HACEMOS UNA COPIA DEL ARHIVO freetds.conf  

-- AGREGAMOS LA CONECCION AL FINAL DEL ARCHIVO freetds.conf  
cat >> /etc/freetds.conf <<'EOF'

[MSSQL2005]
    host = 172.16.109.7
    port = 3750
    tds version = 7.2
    client charset = UTF-8
    enable tls v1 = yes
EOF

tail -n 10 /etc/freetds.conf            -- PARA VER SI SE AGREGO CORRECTAMENTE LA CONECCION
```

Ahora salimos del root, reiniciamos nuestro contenedor y volvemos a ingresar como root parA ejecutar:
```bash
microdnf install -y crypto-policies-scripts 
update-crypto-policies --show                   -- DEVUELVE DEFAULT
microdnf install -y nano                        -- INTALAMOS NANO
nano /etc/freetds.conf                          -- PARA VER EL ARCHIVO (Y VER SI NO ERA UN PROBLEMA DE SINTAXIS)
```

Ingresamos sin root y ejecutamos:
```bash
tsql -S MSSQL2005 -U america                                -- PARA PROBAR LA CONECCION
TDSVER=7.0 tsql -H 172.16.109.7 -p 3750 -U america          -- PARA PROBAR LA CONECCION CON OTRA VERSION DE TDS (Y CON ESTA FUNCIONO DE 10)
```

Entonces el problema era la version del **TDS** (Tabular Data Stream) que es el protocolo que usan los clientes para habla con SQL server 2005.  
Para actualizarla utilizamos como root:
```bash
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

Luego de esto ejecutamos:
```bash
odbcinst -q -s          -- ESTO DEVUELVE MSSQL
odbcinst -j             -- NO DEVUELVE: 
                        #unixODBC 2.3.7
                        #DRIVERS............: /etc/odbcinst.ini
                        #SYSTEM DATA SOURCES: /etc/odbc.ini
                        #FILE DATA SOURCES..: /etc/ODBCDataSources
                        #USER DATA SOURCES..: /root/.odbc.ini
                        #SQLULEN Size.......: 8
                        #SQLLEN Size........: 8
                        #SQLSETPOSIROW Size.: 8
```

Ahora salimos del root y nos logeamos normalmente para probar la coneccion:
```bash
isql -v MSSQL america 'TU_PASSWORD'
```

Ahora podemos probar las conexion:  (luego para salir usar **quit**)
```bash
bash-4.4# isql -v MSSQL america 'TU_PASSWORD'
+---------------------------------------+
| Connected!                            |
|                                       |
| sql-statement                         |
| help [tablename]                      |
| quit                                  |
|                                       |
+---------------------------------------+
SQL> SELECT @@VERSION
+----------------------------------------
|                                                                                                                                                                                                                                                                                                             |
+--------------------------------------------------------------------+
| Microsoft SQL Server 2005 - 9.00.2047.00 (X64) 
        Apr 14 2006 01:11:53 
        Copyright (c) 1988-2005 Microsoft Corporation
        Standard Edition (64-bit) on Windows NT 5.2 (Build 3790: Service Pack 1)
                                                                                                            |
+--------------------------------------------------------------------------------------+
SQLRowCount returns 1
1 rows fetched
SQL> SELECT TOP 5 * FROM dbo.NUEVAS_LOCALIDADES;
+----------------+-----------------------------------------------------------------------------------------------------+
| codigo         | descrip                                                                                             |
+----------------+-----------------------------------------------------------------------------------------------------+
| LOCAL00        | TOTAL                                                                                               |
| LOCAL10        | TOTAL Capital                                                                                       |
| LOCAL90        | TOTAL Rº de la Frontera                                                                            |
| LOCAL11        | CAPITAL                                                                                             |
| LOCAL11        | CAPITAL                                                                                             |
+----------------+-----------------------------------------------------------------------------------------------------+
SQLRowCount returns 5
5 rows fetched
SQL> 
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
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC_FOR_XE))
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

Por fin puedo crear el **Database Link**. En Dbeaver loguado como GXCONTABLE ejecuto: 
```sql
CREATE DATABASE LINK MSSQL
CONNECT TO "america"
IDENTIFIED BY "TU_PASSWORD"
USING 'MSSQL';

-- PARA SABER SI SE CREO CORRECTAMENTE
SELECT DB_LINK, USERNAME, HOST
FROM USER_DB_LINKS;
```

Ejemplos de consutas:
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