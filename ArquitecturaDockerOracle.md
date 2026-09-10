# Arquitectura Docker Oracle

Primero vamos a ver cuanto espacio ocupa nuestro contenedor, para esto vamos a ejecutar:
```bash
docker inspect oracle11g-local --format='{{json .Mounts}}'
docker system df -v
```

Esto me devuelve:
```bash
Imagen Oracle 11g
gvenzl/oracle-xe:11
SIZE: 1.01 GB

Contenedor oracle11g-local
SIZE: 883 MB

Volumen oracle11g_local_data
SIZE: 1.232 GB

Host:
./backup
   ↓
Contenedor:
/backup

Docker Volume:
oracle11g_local_data
   ↓
/u01/app/oracle/oradata
# Este Volume quiere decir que los archivos reales de la Base de Datos estan persistidos en un volumen docker
```

Sumando todos esto valores tenemos:  
```bash
Imagen Oracle              1.010 GB
Cambios del contenedor     0.883 GB
Datos Oracle               1.232 GB
                          ----------
TOTAL aprox.               3.125 GB
```

La estructura actual de mi contenedor Docker es:
```bash
PC Windows
│
├── Docker
│   │
│   ├── Imagen gvenzl/oracle-xe:11
│   │      ≈ 1.01 GB
│   │
│   ├── Contenedor oracle11g-local
│   │      ≈ 883 MB
│   │      │
│   │      ├── Oracle 11g
│   │      ├── dg4odbc
│   │      ├── unixODBC
│   │      ├── FreeTDS
│   │      ├── initMSSQL.ora
│   │      ├── odbc.ini
│   │      └── configuración DBLink
│   │
│   └── Volume oracle11g_local_data
│          ≈ 1.232 GB
│          │
│          └── /u01/app/oracle/oradata
│                 └── archivos de la BD
│
└── genexus-oracle-environment/
    │
    └── backup/
         ↕
       /backup
```

Lo bueno de esto es que si borro y recreo solamente el contenedor manteniendo **oracle11g_local_data**, los datos Oracle siguen existiendo.  
Para ver todo el espacio que se ocupa y quien ocupa ese espacio ejecutamos dentro del contenedor:
```bash
du -h -d 1 / 2>/dev/null | sort -h
du -h -d 1 /u01 2>/dev/null | sort -h
du -h -d 1 /var 2>/dev/null | sort -h
du -h -d 2 /var/cache 2>/dev/null | sort -h
ls -lah /var/cache
```

Ahora como **root eliminamos la cache**:
```bash
rm -rf /var/cache/yum/*
```

## Subir a "Produccion" para poder realizar pruebas
En este caso voy a pasar lo que hice en esta PC a otra, para esto voy a realizar:

1. Para guardar esta **imagen** en nuestra PC ejecutamos:
```bash
docker commit oracle11g-local oracle11g-dblink:1.0
docker save -o oracle11g-dblink-1.0.tar oracle11g-dblink:1.0   # EN ESTE CASO TENEMOS QUE ESTAR PARADOS DONDE QUEREMOS GUARDAR ESTA IMAGEN
```
Donde:
* esta imagen no contendra el contenido del **volumen**
* y este oracle11g-dblink-1.0.tar es el archivo que llevaremos a la otra PC
* de ahora en adelante todas los pasos seran en **la otra PC**

2. Para que esta imagen sea reconocida por docker ejecutamos:
```bash
docker load -i oracle11g-dblink-1.0.tar
docker images                                  # LISTADO DE IMAGENES
```

3. Creamos un nuevo volumen para que se guarden los datos, para esto ejecutamos el comando:
```bash
docker volume create oracle11g_local_data
docker volume ls                             # LISTADO DE VOLUMENES
```

4. Una vez que tenemos la imagen y el volumen, creamos el contenedor con el comando: (el backup despende donde tengamos guardado el archivo .tar)
```bash
docker run -d \
  --name oracle11g-local \
  -p 1521:1521 \
  -e ORACLE_PASSWORD="TU_CLAVE" \
  -v oracle11g_local_data:/u01/app/oracle/oradata \
  -v "C:/BasesDatosOracle/backup:/backup" \
  gvenzl/oracle-xe:11
```
en este caso mi clave es: admin123

5. Vamos a realizar el backup de la base de datos que tenemos en la PC original, para esto realizamos:  
Entramos al contenedor y luego entramos con el usuario **SYSTEM**

```bash
sqlplus system@XE
```

Y luego aqui ejecutamos:
```bash
CREATE OR REPLACE DIRECTORY BACKUP_DIR AS '/backup';
GRANT READ, WRITE ON DIRECTORY BACKUP_DIR TO GXCONTABLE;

# PARA COMPROBAR QUE LO ANTERIOR QUEDO CREADO CORRECTAMENTE
SELECT DIRECTORY_NAME, DIRECTORY_PATH
FROM DBA_DIRECTORIES
WHERE DIRECTORY_NAME = 'BACKUP_DIR';

EXIT;    # SALIMOS DEL USUARIO SYSTEM
```

Y todavia dentro del contenedor hacemos el backup con el comando:
```bash
expdp GXCONTABLE@XE \
  schemas=GXCONTABLE \
  directory=BACKUP_DIR \
  dumpfile=GXCONTABLE_backup.dmp \
  logfile=GXCONTABLE_backup.log
```
y esto nos pedira la contraseña del **GXCONTABLE**

6. Ahora configuramos esta PC para que cualquiera se pueda conectar a la base de datos Oracle Docker:  
Permitir Oracle en el Firewall de Windows, para esto en la PowerShell, ejecutamos:
```bash
New-NetFirewallRule `
  -DisplayName "Oracle Docker 1521" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 1521 `
  -Action Allow
```

Para probar desde mi propia PC
```bash
Get-NetFirewallRule -DisplayName "Oracle Docker 1521"
```

Y para probar desde otra PC
```bash
Test-NetConnection 192.103.1.90 -Port 1521      # DEVUELVE TRUE
```
Y tambien probamos desde **DBeaver** (Ver imagen primeraConeccionOracle.png y cambiar localhost por la IP).

7. Ahora configuramos el DataStore para que se conecte a mi contenedor docker de la otra PC(ver imagenes que estan en /img y en lugar de poner localhost poner la IP de la otra PC).  

8. Para que **GAM** no quede con las configuraciones viejas y evitar errores lo primero que necesito es crear dos codigos aleatorios, para esto en la PowerShell(como administrador), ejecutamos el siguiente comando dos veces:
```bash
[guid]::NewGuid().ToString()
```
y utilizo un codigo para **APPLICATION ID** y el otro codigo para **REPOSITORY ID**  
Tambien actualizamos:  
* Administrator User Name: admin
* Administrator User Password: admin123
* Connection User Name: modulocentral
* Connection User Password: modulocentral123

Una vez modificado esto realizamos: **Tools** &rarr; **Genexus Access Manager** &rarr; **Create Tables**  (No hace falta, solo hay que ejecutar el Build)
Esto vuelve a generar la estructura y configuraciones de GAM.  

Nota: Esto hay que hacerlo en las tres **Kbs**

9. Realizamos un **Build** y como es la primera coneccion nos tiene que pedir crear toda la estructura de datos nuevamente.

10. Los pasos 8 y 9 eran para probar si todo esta OK!!! y no vamos a tener ningun problema. Lo que tenemos que hacer ahora es el **RESTORE** del **BACKUP** que realizamos en el paso 5. NOTA: ESTO LO TENGO QUE HACER DESDE LA PC DE ELIAS YA QUE EN ESA PC ESTA ACTUALIZADA LA KB Y TAMBIEN HAY TENGO QUE HACER NUEVAMENTE EL BACKUP.