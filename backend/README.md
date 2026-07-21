# Aniting Torrent Backend

Motor de torrents en Go para la app Aniting. Proporciona un servidor HTTP local
que Flutter llama para agregar torrents, consultar progreso, y streamear archivos
directamente al reproductor MPV.

## Stack

- **`anacrolix/torrent`** — cliente BitTorrent puro Go, streaming secuencial
- **`golang.org/x/time/rate`** — rate limiting de descarga/subida
- Servidor HTTP en `127.0.0.1:9876` (o puerto aleatorio si 9876 está ocupado)

## Requisitos

- Go 1.21+

## Compilar

```bash
cd backend/
go mod download
go build -o aniting-backend .
```

### Para Linux (producción)
```bash
go build -ldflags="-s -w" -o aniting-backend .
```

### Para Windows
```bash
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o aniting-backend.exe .
```

## Ejecutar

```bash
# Directorio de descarga por defecto: ~/.aniting/torrents
./aniting-backend

# Con directorio personalizado
./aniting-backend /ruta/a/descargas

# Con variables de entorno
ANITING_PORT=9876 ANITING_DOWNLOAD_DIR=/data/torrents ./aniting-backend
```

El proceso imprime `ANITING_BACKEND_PORT=<puerto>` al arrancar — Flutter
lo parsea para saber en qué puerto escucha.

## API

### `GET /health`
```json
{ "status": "ok", "time": "2026-07-03T18:00:00Z" }
```

### `POST /add`
Agrega un torrent. Espera hasta 60 s por metadatos.

Request:
```json
{ "magnetLink": "magnet:?xt=urn:btih:..." }
// o
{ "infoHash": "abc123..." }
```

Response:
```json
{
  "infoHash": "abc123",
  "name": "Movie.mkv",
  "size": 1234567890,
  "progress": 0,
  "files": [
    { "index": 0, "path": "Movie.mkv", "size": 1234567890, "downloaded": 0 }
  ]
}
```

### `GET /torrent/{infoHash}`
Obtiene estadísticas actuales (progreso, velocidades, peers).

### `DELETE /torrent/{infoHash}`
Elimina el torrent. Body opcional: `{ "deleteFiles": true }`.

### `GET /list`
Lista todos los torrents activos.

### `GET /stream/{infoHash}/{fileIndex}`
**Endpoint principal para reproducción.** Sirve el archivo con soporte Range
para que MPV pueda buscar libremente. El torrent se descarga en streaming
secuencial — la reproducción puede comenzar en segundos.

Ejemplo URL para MPV: `http://127.0.0.1:9876/stream/abc123/0`

### `POST /settings`
Ajusta límites de velocidad en tiempo real.
```json
{ "downloadLimit": 5242880, "uploadLimit": 1048576 }
```
(bytes/s, 0 = ilimitado)

### `GET /network`
Info de red: IP local, IP pública, puerto BitTorrent.

## Integración con Flutter

El servicio `TorrentEngineService` en `lib/services/torrent_engine_service.dart`
lanza este binario como proceso hijo y se comunica via HTTP en `localhost:9876`.

Flujo:
1. Flutter lanza `aniting-backend` y parsea la línea `ANITING_BACKEND_PORT=...`
2. Cuando el usuario selecciona un stream de torrent (desde extensión Stremio),
   Flutter llama `POST /add` con el magnet link
3. Flutter recibe el `infoHash` y el índice del archivo de video
4. Pasa `http://127.0.0.1:9876/stream/{infoHash}/0` al player MPV
5. MPV hace requests HTTP con Range headers — el backend los sirve en tiempo real
