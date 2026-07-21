param (
    [switch]$SkipAndroid = $false,
    [switch]$SkipWindows = $false
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BackendDir = $ScriptDir
$ProjectRoot = (Get-Item $ScriptDir).Parent.FullName

cd $BackendDir

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Compilador del Backend de Torrents" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Bajar dependencias
Write-Host "`n[*] Verificando dependencias de Go..." -ForegroundColor Yellow
go mod download
if ($LASTEXITCODE -ne 0) {
    Write-Error "Fallo al descargar las dependencias de Go."
    exit 1
}

# 2. Compilar para Windows
if (-not $SkipWindows) {
    Write-Host "`n[*] Compilando ejecutable para Windows..." -ForegroundColor Yellow
    $env:CGO_ENABLED = "0"
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    
    go build -o aniting-backend.exe .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Fallo la compilacion para Windows."
        exit 1
    }
    
    Write-Host "[+] Ejecutable de Windows compilado (aniting-backend.exe)" -ForegroundColor Green

    # Copiar a directorios de build de Flutter si existen
    $DebugDir = Join-Path $ProjectRoot "build\windows\x64\runner\Debug"
    $ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"

    if (Test-Path $DebugDir) {
        try {
            Copy-Item -Path ".\aniting-backend.exe" -Destination $DebugDir -Force -ErrorAction Stop
            Write-Host "    -> Copiado a $DebugDir" -ForegroundColor DarkGray
        } catch {
            Write-Warning "No se pudo copiar a $DebugDir. ¿La app esta corriendo?"
        }
    }
    if (Test-Path $ReleaseDir) {
        try {
            Copy-Item -Path ".\aniting-backend.exe" -Destination $ReleaseDir -Force -ErrorAction Stop
            Write-Host "    -> Copiado a $ReleaseDir" -ForegroundColor DarkGray
        } catch {
            Write-Warning "No se pudo copiar a $ReleaseDir. ¿La app esta corriendo?"
        }
    }
}

# 3. Compilar para Android
if (-not $SkipAndroid) {
    Write-Host "`n[*] Buscando Android NDK..." -ForegroundColor Yellow
    
    $NdkBase = Join-Path $env:LOCALAPPDATA "Android\Sdk\ndk"
    if (-not (Test-Path $NdkBase)) {
        Write-Warning "Directorio de NDK no encontrado en $NdkBase."
        Write-Warning "Saltando compilacion de Android."
    } else {
        # Buscar la version mas reciente de NDK instalada
        $LatestNdk = Get-ChildItem -Path $NdkBase -Directory | Sort-Object Name -Descending | Select-Object -First 1
        
        if ($null -eq $LatestNdk) {
            Write-Warning "No hay carpetas de versiones de NDK en $NdkBase."
        } else {
            Write-Host "[+] NDK encontrado: $($LatestNdk.FullName)" -ForegroundColor Green
            
            $CcPath = Join-Path $LatestNdk.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android30-clang.cmd"
            $CxxPath = Join-Path $LatestNdk.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android30-clang++.cmd"
            
            if (-not (Test-Path $CcPath)) {
                # Alternativa de version
                $CcPath = Join-Path $LatestNdk.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android-clang.cmd"
                $CxxPath = Join-Path $LatestNdk.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android-clang++.cmd"
            }

            if (-not (Test-Path $CcPath)) {
                Write-Warning "No se pudo encontrar el compilador clang de Android NDK (aarch64-linux-android)."
            } else {
                Write-Host "`n[*] Compilando libreria nativa (.so) para Android (arm64-v8a)..." -ForegroundColor Yellow
                
                $env:CGO_ENABLED = "1"
                $env:GOOS = "android"
                $env:GOARCH = "arm64"
                $env:CC = $CcPath
                $env:CXX = $CxxPath

                # -checklinkname=0 es un workaround para el error de red de go1.23+ con anet
                go build -ldflags="-checklinkname=0" -buildmode=c-shared -o libtorrent.so -tags library .
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Fallo la compilacion para Android."
                    exit 1
                }
                
                Write-Host "[+] Libreria de Android compilada (libtorrent.so)" -ForegroundColor Green

                # Copiar a android/app/src/main/jniLibs/arm64-v8a
                $AndroidJniDir = Join-Path $ProjectRoot "android\app\src\main\jniLibs\arm64-v8a"
                if (-not (Test-Path $AndroidJniDir)) {
                    New-Item -ItemType Directory -Force -Path $AndroidJniDir | Out-Null
                }

                Copy-Item -Path ".\libtorrent.so" -Destination $AndroidJniDir -Force
                Copy-Item -Path ".\libtorrent.h" -Destination $AndroidJniDir -Force
                
                Write-Host "    -> Copiado a $AndroidJniDir" -ForegroundColor DarkGray
            }
        }
    }
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "               ¡COMPLETADO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
