# Configuracion de la otra PC como servidor

## Modificaciones en Docker Desktop

1. En **Settings** &rarr; **General**  
Seleccionar unicamente la opcion "Start Docker Desktop when you sign in to your computer" y lo demas dejarlo exactamente como esta.

## Modificaciones Docker desde el Git Bash

2. En caso de que se reinicie Windows puede pasar que no se inicialice el contenedor de Oracle.  

Para saber si esto es asi ejecutamos:
```bash
docker inspect oracle11g-local --format="{{.HostConfig.RestartPolicy.Name}}"
```
Si devuelve **no** quiere deciur que mi contenedor oracle no tiene politica de reinicio, es decir, podria quedar apagado hasta que lo inicies manualmente, para solucionar esto ejecutamos el comando:
```bash
docker update --restart unless-stopped oracle11g-local
```
Esto no recrea el contenedor, no borra datos y no debería reiniciar Oracle en ese momento. Simplemente cambia la configuración del contenedor existente.  
Para comprobarlo ejecutamos nuevamente el comando inspect y deberia devolver **unless-stopped**.  
Tener en cuenta que esto no me afecta los comandos docker stop, start y restart que los puedo utilizar normalmente.

## Modificaciones en la PC

3. Cambiar la configuracion para que la PC no se suspenda nunca. Para esto nos vamos a Configuracion &rarr; Energia y Suspencion. Y poner pantalla en 15 minutos y Suspender Nunca.

4. En Panel de control &rarr; Hardware y sonido &rarr; Opciones de energía: elegir "Equilibrado"

5. Entrar al enlace que esta alado de Equilibrado(recomendado) que dice "Cambiar la configuracion del plan" &rarr; "Cambiar la configuracion avanzada de energia" y aqui actualizar:
*  Disco Duro &rarr; Apagar disco duro tras &rarr; Configuracion (Minutos): 0 (Aplicar y Aceptar).

6. Configuracion de la placa de Red Ethernet para que Windows no la apague por ahorro de energia, para esto nos vamos a:
* Inicio &rarr; Segundo click &rarr; Administrador de dispositivos &rarr; Adaptadores de Red &rarr; Realtek Gaming GbE Family Controller &rarr; Administracion de Energia &rarr; Deselecionar la primera opcion.