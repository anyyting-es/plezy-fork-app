# Aniting Backend

El backend oficial en Go para Anityng, encargado de las descargas torrent (usando `anacrolix/torrent`) y el motor de extensiones Javascript (usando `goja`). Anityng.

## Requisitos

- Go 1.21 o superior
- Conexión a internet para descargar dependencias

## Instalación

### 1. Instalar dependencias

```bash
cd torrent-backend
go mod download
```

### 2. Compilar Rápido (Windows + Android)

Para compilar automáticamente ambos binarios y que se copien a las carpetas correctas del proyecto Flutter, puedes usar el script de PowerShell incluido:

```powershell
.\build_all.ps1
```

Este script se encarga de:
- Compilar `torrent-backend.exe` para Windows y copiarlo a los directorios Debug y Release de Flutter.
- Detectar el NDK de Android, compilar `libtorrent.so` (arm64-v8a) y copiarlo a `android/app/src/main/jniLibs/arm64-v8a/`.

### 3. Compilar Manualmente

Si prefieres hacerlo de forma manual:

#### Windows
```bash
go build -o torrent-backend.exe .
```
Luego copia el ejecutable generado a `..\build\windows\x64\runner\Debug\` y `Release\`.

#### Android
Requiere tener el Android NDK configurado y ejecutar el build con CGO usando `c-shared`:
```bash
go build -ldflags="-checklinkname=0" -buildmode=c-shared -o libtorrent.so -tags library .
```
Luego copia `libtorrent.so` y `libtorrent.h` a `..\android\app\src\main\jniLibs\arm64-v8a\`.

## Uso

El backend se inicia automáticamente cuando la aplicación Flutter lo necesita (cuando se selecciona el provider "Torrent").

### Endpoints

- `GET /health` - Verifica si el backend está corriendo
- `POST /add` - Agrega un torrent (magnet link o infohash)
- `GET /torrent/{infoHash}` - Obtiene información de un torrent
- `GET /stream/{infoHash}/{fileIndex}` - Stream de un archivo del torrent
- `DELETE /torrent/{infoHash}` - Elimina un torrent
- `GET /list` - Lista todos los torrents activos

### Variables de Entorno

- `TORRENT_PORT` - Puerto del servidor (default: 9876)
- `TORRENT_DOWNLOAD_DIR` - Directorio de descargas (default: `~/.anityng/torrents`)

## Configuración en la App

1. Ve a Settings en la aplicación
2. Activa "Habilitar soporte para Torrents"
3. Guarda la configuración
4. En el reproductor, selecciona "Torrent" como servidor

## Notas

- El backend se ejecuta localmente en `http://127.0.0.1:9876`
- Los torrents se descargan en tiempo real mientras se reproduce el video
- Se recomienda tener buena conexión a internet para mejor experiencia
- El backend se cierra automáticamente cuando la aplicación Flutter termina

## Desarrollo

### Correr en modo desarrollo

```bash
go run main.go
```

### Logs

Los logs del backend se muestran en la consola de debug de Flutter con el prefijo `[TorrentBackend]`.

## Troubleshooting

### El backend no inicia

1. Verifica que Go esté instalado: `go version`
2. Verifica que el ejecutable esté en el directorio correcto
3. Revisa los logs en la consola de debug

### Error de puerto en uso

Cambia el puerto con la variable de entorno:

```bash
export TORRENT_PORT=9877
go run main.go
```

### Los torrents no descargan

- Verifica tu conexión a internet
- Algunos torrents pueden no tener seeders
- Revisa el firewall/antivirus
