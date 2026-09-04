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

