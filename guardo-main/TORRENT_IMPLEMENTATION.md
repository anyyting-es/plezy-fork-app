# Implementación de Torrent Backend para Anityng

## Resumen

Se ha implementado un sistema de streaming de torrents para la aplicación Anityng utilizando un backend en Go que se comunica con la aplicación Flutter a través de HTTP local.

## Arquitectura

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│  Go Backend      │────▶│  Torrent        │
│   (Dart)        │◀────│  (torrent-backend)│◀────│  Network (P2P)  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        │                        │
        │                        └─────► HTTP Stream (localhost:9876)
        │
        └─────► Video Player (MPV via media_kit)
```

## Componentes

### 1. Backend Go (`torrent-backend/`)

**Archivos principales:**
- `main.go` - Servidor HTTP con integración de torrent usando `anacrolix/torrent`
- `go.mod` - Dependencias de Go
- `README.md` - Instrucciones de compilación y uso

**Endpoints:**
- `GET /health` - Verifica estado del backend
- `POST /add` - Agrega torrent (magnet/hash)
- `GET /torrent/{infoHash}` - Obtiene información
- `GET /stream/{infoHash}/{fileIndex}` - Stream de archivo
- `DELETE /torrent/{infoHash}` - Elimina torrent
- `GET /list` - Lista torrents activos

**Puerto default:** `9876`

### 2. Flutter Provider (`lib/providers/torrent_provider.dart`)

**Clases:**
- `TorrentProvider` - Implementa interfaz `VideoProvider`
- `TorrentConfig` - Configuración del backend
- `TorrentBackendInfo` - Información de torrent
- `TorrentFile` - Archivo dentro del torrent

**Funcionalidades:**
- Auto-inicio del backend Go cuando se necesita
- Búsqueda en AnimeTosho API
- Streaming HTTP desde torrent
- Gestión de caché de torrents activos

### 3. Integración UI

**Archivos modificados:**
- `lib/services/api_service.dart` - Instancia de `TorrentProvider`
- `lib/pages/watch_page.dart` - Selector de provider "Torrent"
- `lib/pages/settings_page.dart` - Toggle para habilitar torrents
- `lib/models/app_models.dart` - Campo `enableTorrents` en `AppSettings`

## Flujo de Uso

1. **Usuario activa torrents en Settings**
   - Settings → "Habilitar soporte para Torrents" → Guardar

2. **Usuario selecciona anime y episodio**

3. **Usuario cambia a provider "Torrent"**
   - En el reproductor: botón de servidor → "Torrent"

4. **TorrentProvider:**
   - Busca episodios en AnimeTosho API
   - Obtiene magnet link del episodio
   - Inicia backend Go automáticamente
   - Agrega torrent al backend
   - Espera a que haya archivos disponibles
   - Obtiene URL de stream HTTP local
   - Reproduce en MPV

5. **Backend Go:**
   - Descarga torrent en tiempo real
   - Sirve archivo vía HTTP con soporte Range Requests
   - Permite seek sin descargar todo el archivo

## Compilación

### Backend Go

```bash
# Windows
cd torrent-backend
go mod download
go build -o torrent-backend.exe .

# O usar script automático
.\build-torrent-backend.bat
```

### Deployment

Copiar `torrent-backend.exe` a:
- `build\windows\x64\runner\Debug\`
- `build\windows\x64\runner\Release\`

## Configuración

### Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TORRENT_PORT` | `9876` | Puerto del servidor HTTP |
| `TORRENT_DOWNLOAD_DIR` | `~/.anityng/torrents` | Directorio de descargas |

### App Settings

```dart
AppSettings(
  enableTorrents: false, // Default: desactivado
   torrentBackendUrl: '', // Opcional: backend remoto (online)
  // ... otros settings
)
```

Si `torrentBackendUrl` está vacío:
- En escritorio usa backend local (incluido con el instalador de Windows)

Si `torrentBackendUrl` está configurado:
- Todas las plataformas intentan usar ese backend remoto (online)

## Ventajas

✅ **Sin cambios mayores al código existente** - Los providers actuales siguen funcionando
✅ **Arquitectura limpia** - Separación clara entre Flutter y backend
✅ **Streaming eficiente** - Range requests permiten seek sin descargar todo
✅ **Multi-plataforma** - Go compila para Windows, Linux, macOS
✅ **Battle-tested** - `anacrolix/torrent` es una librería madura

## Desventajas

⚠️ **Requiere Go instalado** para compilar el backend
⚠️ **Binario adicional** - ~10-15MB dependiendo de la plataforma
⚠️ **Dos procesos** - Flutter + Go backend corriendo simultáneamente
⚠️ **Consumo de recursos** - Torrent usa RAM y CPU para descifrar/decodificar

## Consideraciones de Seguridad

- El backend solo escucha en `127.0.0.1` (localhost)
- No hay exposición a internet
- CORS habilitado solo para localhost
- Los torrents se descargan en directorio del usuario

## Troubleshooting

### El backend no inicia
1. Verificar que Go esté instalado: `go version`
2. Verificar que el ejecutable esté en el directorio correcto
3. Revisar logs en consola de debug: `[TorrentBackend]`

### Error de puerto en uso
```bash
export TORRENT_PORT=9878
go run main.go
```

### Los torrents no descargan
- Verificar conexión a internet
- El torrent puede no tener seeders
- Revisar firewall/antivirus

### Flutter no encuentra el backend
- Verificar que `torrent-backend.exe` esté en el mismo directorio que el ejecutable de Flutter
- Revisar logs: `[TorrentProvider] Starting backend from: ...`

## Futuras Mejoras

- [ ] Soporte para subtítulos desde torrents
- [ ] Precarga de siguientes episodios
- [ ] Persistencia de torrents entre sesiones
- [ ] Selector de calidad de archivos en torrent
- [ ] Progress de descarga en UI
- [ ] Cancelar descarga de torrent
- [ ] Límite de velocidad de descarga
- [ ] WebTorrent para torrents vía web

## Referencias

- [anacrolix/torrent](https://github.com/anacrolix/torrent)
- [AnimeTosho API](https://animetosho.org/feed/api)
- [media_kit](https://github.com/media-kit/media-kit)
