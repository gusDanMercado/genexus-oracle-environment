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