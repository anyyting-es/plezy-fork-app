# 🚨 READ THIS SUPER IMPORTANT - Windows Build & Environment Guide

> **¡LEER PRIMERO! Documentación crítica para desarrollo y compilación en Windows para Plezy.**

---

## 📌 1. El Problema del Motor de Flutter y los Controles de Video en Windows

### 🔍 ¿Qué ocurre?
Al ejecutar `flutter run -d windows` con un Flutter SDK estándar de fábrica:
- La ventana nativa del reproductor de video (`libmpv` HWND) se dibuja **por encima** de los controles flotantes de Flutter (DirectComposition).
- Esto causa que el video tape el 100% de la interfaz de Flutter (botón de regresar, barra de progreso, botones de reproducción), o que al intentar forzar el orden de capas la pantalla quede en negro.

### 🛠️ La Solución: Motor Parcheado con Soporte `FLUTTER_WINDOWS_DCOMP`
El creador original de Plezy desarrolló una versión parcheada del motor ejecutable de Flutter para Windows (`flutter_windows.dll`) que activa la variable de entorno `FLUTTER_WINDOWS_DCOMP=1`. Este motor coloca la interfaz gráfica de Flutter en una capa DirectComposition superior (`IDCompositionVisual`), permitiendo que el video se dibuje de fondo y los controles **SIEMPRE queden por encima**.

### 📥 ¿Cómo instalar el motor parcheado en tu SDK de Flutter?
Si ejecutas `flutter upgrade` o `flutter precache`, tu SDK de Flutter restaurará la librería estándar sin soporte DComp.

Para volver a instalar el motor parcheado en tu SDK:
```powershell
# 1. Asegúrate de precargar las dependencias de Windows en tu SDK
flutter precache --windows

# 2. Descarga e instala el motor parcheado DComp en la caché de tu Flutter SDK
powershell -ExecutionPolicy Bypass -File windows/tool/install-patched-engine.ps1
```

---

## ⚙️ 2. Compilación del Backend de Torrents en Go (`aniting-backend.exe`)

El reproductor incluye un motor en Go (`backend/`) que sirve streaming de torrents y ejecuta extensiones en JS via Goja en `http://127.0.0.1:9876`.

### 🔨 Compilar el Backend manualmente:
```powershell
cd backend
go build -ldflags="-s -w" -o aniting-backend.exe .
```

### 📦 Empaquetado automático en Release:
El archivo `windows/CMakeLists.txt` incluye la regla de instalación que copia automáticamente `aniting-backend.exe` y `libmpv-2.dll` al directorio de salida final (`build/windows/x64/runner/Release/`).

---

## ⚠️ 3. Solución a Errores Comunes de Compilación

### A. Error `LNK1168: cannot open plezy.exe for writing` o `file(INSTALL) Access Denied`
- **Causa**: La aplicación `plezy.exe` o el backend `aniting-backend.exe` están ejecutándose en segundo plano y Windows bloquea la sobreescritura de los archivos `.exe`.
- **Solución**: Cierra los procesos activos desde PowerShell antes de volver a compilar:
  ```powershell
  Get-Process plezy,aniting-backend -ErrorAction SilentlyContinue | Stop-Process -Force
  ```

### B. Error `Could NOT find JNI (missing: JAVA_INCLUDE_PATH)`
- **Causa**: Ocurre en sistemas Windows sin Java / JDK instalado cuando `package:jni` intenta compilar su script CMake nativo.
- **Solución**: Implementamos un guard en `windows/CMakeLists.txt` que detecta la ausencia de JDK y stubbea la librería `jni` como `INTERFACE` sin interrumpir la compilación.

### C. Error `MissingPlatformDirectoryException(Unable to get application documents directory)`
- **Causa**: Al desinstalar OneDrive en Windows, las rutas del registro `User Shell Folders` (`Personal`, `Desktop`, `Pictures`) quedan corruptas apuntando a carpetas inexistentes dentro de `OneDrive\`.
- **Solución**: `TorrentEngineService.dart` cuenta con un mecanismo de fallback que detecta el fallo y conmuta a `%USERPROFILE%\.aniting\torrents`.

---

## 🚀 4. Comandos de Compilación Rápidos

### Modo Desarrollo (Debug):
```powershell
flutter run -d windows
```

### Modo Producción (Release):
```powershell
flutter build windows --release
```
Ubicación del ejecutable final listo para distribución:
📂 `build\windows\x64\runner\Release\plezy.exe`
