# 🛠️ Tutoriel: Compiler Sonarr sur Windows avec FFmpeg Encoding

Ce guide vous permet de compiler Sonarr avec la nouvelle fonctionnalité FFmpeg Encoding intégrée.

---

## 📋 Prérequis

### 1. Installer les outils nécessaires

#### A. .NET SDK 8.0
- **Télécharger**: [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- **Version requise**: .NET 8.0 SDK (vérifier avec `dotnet --version`)
- **Installation**: Exécuter l'installeur et redémarrer le terminal

```powershell
# Vérifier l'installation
dotnet --version
# Doit afficher: 8.0.x
```

#### B. Node.js et Yarn
- **Node.js**: [Télécharger LTS](https://nodejs.org/) (v18 ou supérieur)
- **Yarn**: Se installe automatiquement avec Node.js ou via npm

```powershell
# Vérifier Node.js
node --version
# Doit afficher: v18.x.x ou supérieur

# Installer Yarn globalement (si nécessaire)
npm install -g yarn

# Vérifier Yarn
yarn --version
```

#### C. Git pour Windows
- **Télécharger**: [Git for Windows](https://git-scm.com/download/win)
- Nécessaire pour cloner le dépôt

#### D. Visual Studio Build Tools (optionnel mais recommandé)
- **Télécharger**: [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/)
- Sélectionner ".NET desktop build tools" lors de l'installation
- OU installer Visual Studio Community 2022 complet

---

## 📥 Étape 1: Cloner le dépôt

```powershell
# Créer un dossier de travail
mkdir C:\Dev
cd C:\Dev

# Cloner votre fork avec la branche FFmpeg
git clone https://github.com/aubertlucas/Sonarr.git
cd Sonarr

# Vérifier que vous êtes sur la bonne branche
git checkout claude/add-ffmpeg-encoding-011CUM3J9QkP7KDLo7j4unD9

# Vérifier que les fichiers FFmpeg sont présents
dir src\NzbDrone.Core\MediaFiles\Encoding\
```

---

## 🏗️ Étape 2: Compiler le Backend (.NET)

### Option A: Compilation Simple (Développement)

```powershell
# Nettoyer les anciens builds
if (Test-Path _output) { Remove-Item -Recurse -Force _output }
if (Test-Path _tests) { Remove-Item -Recurse -Force _tests }

# Compiler pour Windows x64
dotnet msbuild src/Sonarr.sln `
  -restore `
  -p:Configuration=Release `
  -p:Platform=Windows `
  -p:RuntimeIdentifiers=win-x64 `
  -p:SelfContained=True `
  -p:EnableWindowsTargeting=true `
  -t:PublishAllRids
```

**Durée**: ~5-10 minutes

**Résultat**: Les fichiers compilés se trouvent dans `_output/net8.0/win-x64/publish/`

### Option B: Compilation avec Version Personnalisée

```powershell
# Définir les variables d'environnement
$env:SONARR_VERSION = "4.0.10.9999"
$env:BRANCH = "ffmpeg-encoding"

# Mettre à jour le numéro de version
$propsFile = "src\Directory.Build.props"
(Get-Content $propsFile) -replace '<AssemblyVersion>[\d.]+</AssemblyVersion>', "<AssemblyVersion>$env:SONARR_VERSION</AssemblyVersion>" | Set-Content $propsFile
(Get-Content $propsFile) -replace '<AssemblyConfiguration>.*</AssemblyConfiguration>', "<AssemblyConfiguration>$env:BRANCH</AssemblyConfiguration>" | Set-Content $propsFile

# Compiler
dotnet msbuild src/Sonarr.sln `
  -restore `
  -p:Configuration=Release `
  -p:Platform=Windows `
  -p:RuntimeIdentifiers=win-x64 `
  -p:SelfContained=True `
  -p:EnableWindowsTargeting=true `
  -t:PublishAllRids
```

---

## 🎨 Étape 3: Compiler le Frontend (React/TypeScript)

```powershell
# Installer les dépendances Node.js
yarn install

# Nettoyer les anciens builds UI
if (Test-Path _output\UI) { Remove-Item -Recurse -Force _output\UI }

# Compiler le frontend en mode production
yarn build --env production
```

**Durée**: ~3-5 minutes

**Résultat**: Les fichiers UI se trouvent dans `_output/UI/`

---

## 📦 Étape 4: Packager Sonarr Complet

```powershell
# Créer le dossier de packaging
$PACKAGE_DIR = "_artifacts\win-x64\net8.0\Sonarr"
if (Test-Path _artifacts) { Remove-Item -Recurse -Force _artifacts }
New-Item -ItemType Directory -Force -Path $PACKAGE_DIR

# Copier les fichiers backend
Copy-Item -Recurse -Force "_output\net8.0\win-x64\publish\*" $PACKAGE_DIR

# Copier Sonarr.Update
Copy-Item -Recurse -Force "_output\Sonarr.Update\net8.0\win-x64\publish" "$PACKAGE_DIR\Sonarr.Update"

# Copier les fichiers Windows spécifiques
Copy-Item -Recurse -Force "_output\net8.0-windows\win-x64\publish\*" $PACKAGE_DIR

# Copier la licence
Copy-Item "LICENSE.md" $PACKAGE_DIR

# Nettoyer les fichiers non-Windows
Remove-Item -Force "$PACKAGE_DIR\Sonarr.Mono.*" -ErrorAction SilentlyContinue
Remove-Item -Force "$PACKAGE_DIR\Mono.Posix.NETStandard.*" -ErrorAction SilentlyContinue
Remove-Item -Force "$PACKAGE_DIR\libMonoPosixHelper.*" -ErrorAction SilentlyContinue

# Ajouter Sonarr.Windows au package de mise à jour
Copy-Item "$PACKAGE_DIR\Sonarr.Windows.*" "$PACKAGE_DIR\Sonarr.Update\"

Write-Host "✅ Package créé dans: $PACKAGE_DIR" -ForegroundColor Green
```

---

## 🚀 Étape 5: Tester Sonarr Localement

### A. Exécution en mode développement

```powershell
cd _artifacts\win-x64\net8.0\Sonarr

# Lancer Sonarr
.\Sonarr.exe

# OU avec console pour voir les logs
.\Sonarr.Console.exe
```

**Accès**: Ouvrir un navigateur sur `http://localhost:8989`

### B. Vérifier la fonctionnalité FFmpeg

1. Aller dans **Settings → Media Management**
2. Scroller jusqu'à la section **"FFmpeg Encoding"**
3. Cocher **"Enable FFmpeg Encoding"**
4. Configurer:
   - **FFmpeg Path**: `C:\ffmpeg\bin\ffmpeg.exe` (ou `ffmpeg` si dans le PATH)
   - **FFmpeg Arguments**: `-c:v hevc_nvenc -preset p1 -b:v 4M -c:a libopus -b:a 128k`
   - **Delete Original**: Décoché (pour tester)
   - **Minimum Size**: 0 GB (encode tous les fichiers)
   - **Skip HEVC**: Coché
   - **Timeout**: 0 (illimité)
5. Cliquer **Save**
6. Déclencher un téléchargement pour tester l'encodage automatique

---

## 📤 Étape 6: Créer un Package de Mise à Jour

### Option 1: ZIP Portable

```powershell
# Créer un ZIP avec 7-Zip (à installer si nécessaire)
cd _artifacts\win-x64\net8.0
7z a -tzip Sonarr.v4.0.10.9999.windows.zip Sonarr\*

# OU avec PowerShell (plus lent)
Compress-Archive -Path "Sonarr\*" -DestinationPath "Sonarr.v4.0.10.9999.windows.zip"

Write-Host "✅ Package ZIP créé: Sonarr.v4.0.10.9999.windows.zip" -ForegroundColor Green
```

**Utilisation**: Extraire le ZIP et remplacer le dossier Sonarr existant

### Option 2: Installer comme Update dans Sonarr existant

```powershell
# Arrêter Sonarr s'il est en cours d'exécution
Stop-Process -Name "Sonarr" -Force -ErrorAction SilentlyContinue

# Localiser l'installation Sonarr existante
$SONARR_INSTALL = "C:\ProgramData\Sonarr\bin"  # Ajuster selon votre installation

# Sauvegarder l'ancienne version
$BACKUP_DIR = "C:\ProgramData\Sonarr\bin.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Recurse -Force $SONARR_INSTALL $BACKUP_DIR

# Copier la nouvelle version
Copy-Item -Recurse -Force "_artifacts\win-x64\net8.0\Sonarr\*" $SONARR_INSTALL

# Redémarrer Sonarr service
Start-Service -Name "Sonarr"

# OU démarrer manuellement
Start-Process "$SONARR_INSTALL\Sonarr.exe"

Write-Host "✅ Sonarr mis à jour avec succès!" -ForegroundColor Green
Write-Host "Backup de l'ancienne version: $BACKUP_DIR" -ForegroundColor Yellow
```

---

## 🔧 Configuration FFmpeg

### Installer FFmpeg (si non présent)

#### Méthode 1: Winget (recommandé)
```powershell
winget install ffmpeg
```

#### Méthode 2: Chocolatey
```powershell
choco install ffmpeg
```

#### Méthode 3: Manuel
1. Télécharger depuis [ffmpeg.org](https://ffmpeg.org/download.html#build-windows)
2. Extraire dans `C:\ffmpeg\`
3. Ajouter `C:\ffmpeg\bin` au PATH système

### Vérifier FFmpeg

```powershell
ffmpeg -version

# Devrait afficher quelque chose comme:
# ffmpeg version N-114XXX-g... Copyright (c) 2000-2025...
```

### Arguments FFmpeg Recommandés

| Scénario | Arguments |
|----------|-----------|
| **NVIDIA GPU (NVENC)** | `-c:v hevc_nvenc -preset p1 -b:v 4M -c:a libopus -b:a 128k` |
| **AMD GPU (AMF)** | `-c:v hevc_amf -quality speed -b:v 4M -c:a libopus -b:a 128k` |
| **Intel GPU (QuickSync)** | `-c:v hevc_qsv -preset fast -b:v 4M -c:a libopus -b:a 128k` |
| **CPU (lent)** | `-c:v libx265 -preset medium -crf 23 -c:a libopus -b:a 128k` |
| **Qualité maximale** | `-c:v hevc_nvenc -preset p7 -b:v 8M -c:a libopus -b:a 192k` |
| **Rapidité maximale** | `-c:v hevc_nvenc -preset p1 -b:v 2M -c:a copy` |

---

## 🐛 Dépannage

### Erreur: "dotnet: command not found"
- Installer .NET SDK 8.0
- Redémarrer PowerShell après installation

### Erreur: "yarn: command not found"
- Installer Node.js
- Exécuter `npm install -g yarn`
- Redémarrer PowerShell

### Erreur de compilation C# : "CS0234: Type or namespace missing"
```powershell
# Nettoyer et restaurer les packages NuGet
dotnet clean src/Sonarr.sln
dotnet restore src/Sonarr.sln
Remove-Item -Recurse -Force "$env:USERPROFILE\.nuget\packages\nzbdrone.*"
```

### Erreur frontend: "ELIFECYCLE Command failed"
```powershell
# Nettoyer le cache Yarn et node_modules
Remove-Item -Recurse -Force node_modules, yarn.lock
yarn cache clean
yarn install
```

### Sonarr ne démarre pas après la mise à jour
```powershell
# Restaurer la sauvegarde
Stop-Service -Name "Sonarr" -ErrorAction SilentlyContinue
Copy-Item -Recurse -Force "C:\ProgramData\Sonarr\bin.backup.*\*" "C:\ProgramData\Sonarr\bin"
Start-Service -Name "Sonarr"
```

### FFmpeg ne s'exécute pas
```powershell
# Vérifier les permissions
icacls "C:\ffmpeg\bin\ffmpeg.exe" /grant Users:RX

# Tester FFmpeg manuellement
& "C:\ffmpeg\bin\ffmpeg.exe" -version
```

---

## 📊 Structure du Build

```
_artifacts/
└── win-x64/
    └── net8.0/
        └── Sonarr/                  # 📦 Package final
            ├── Sonarr.exe           # Exécutable principal
            ├── Sonarr.Console.exe   # Version console (avec logs)
            ├── Sonarr.dll           # Bibliothèque principale
            ├── Sonarr.Windows.dll   # Spécifique Windows
            ├── NzbDrone.Core.dll    # Contient FfmpegEncodingService
            ├── UI/                  # Interface React
            │   ├── index.html
            │   └── ...
            ├── Sonarr.Update/       # Auto-updater
            │   └── ...
            └── LICENSE.md

_output/
├── net8.0/
│   └── win-x64/
│       └── publish/             # Build backend brut
├── net8.0-windows/
│   └── win-x64/
│       └── publish/             # Spécifique Windows
└── UI/                          # Build frontend
    └── ...
```

---

## ⚙️ Variables d'Environnement Utiles

```powershell
# Définir avant compilation
$env:SONARR_VERSION = "4.0.10.9999"
$env:BRANCH = "ffmpeg-encoding"
$env:SONARR_MAJOR_VERSION = "4"
$env:FRAMEWORK = "net8.0"
$env:RUNTIME = "win-x64"
```

---

## 📝 Script Automatisé Complet

Créer `build-sonarr-windows.ps1`:

```powershell
#Requires -Version 5.1

param(
    [string]$Version = "4.0.10.9999",
    [string]$Branch = "ffmpeg-encoding"
)

Write-Host "🚀 Building Sonarr $Version ($Branch)" -ForegroundColor Cyan

# Nettoyer
Write-Host "🧹 Cleaning..." -ForegroundColor Yellow
Remove-Item -Recurse -Force _output, _artifacts, _tests -ErrorAction SilentlyContinue

# Mettre à jour la version
Write-Host "📝 Updating version..." -ForegroundColor Yellow
$propsFile = "src\Directory.Build.props"
(Get-Content $propsFile) -replace '<AssemblyVersion>[\d.]+</AssemblyVersion>', "<AssemblyVersion>$Version</AssemblyVersion>" | Set-Content $propsFile
(Get-Content $propsFile) -replace '<AssemblyConfiguration>.*</AssemblyConfiguration>', "<AssemblyConfiguration>$Branch</AssemblyConfiguration>" | Set-Content $propsFile

# Backend
Write-Host "🏗️ Building backend..." -ForegroundColor Yellow
dotnet msbuild src/Sonarr.sln -restore -p:Configuration=Release -p:Platform=Windows -p:RuntimeIdentifiers=win-x64 -p:SelfContained=True -p:EnableWindowsTargeting=true -t:PublishAllRids
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Frontend
Write-Host "🎨 Building frontend..." -ForegroundColor Yellow
yarn install
yarn build --env production
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Package
Write-Host "📦 Packaging..." -ForegroundColor Yellow
$PACKAGE_DIR = "_artifacts\win-x64\net8.0\Sonarr"
New-Item -ItemType Directory -Force -Path $PACKAGE_DIR | Out-Null
Copy-Item -Recurse -Force "_output\net8.0\win-x64\publish\*" $PACKAGE_DIR
Copy-Item -Recurse -Force "_output\Sonarr.Update\net8.0\win-x64\publish" "$PACKAGE_DIR\Sonarr.Update"
Copy-Item -Recurse -Force "_output\net8.0-windows\win-x64\publish\*" $PACKAGE_DIR
Copy-Item "LICENSE.md" $PACKAGE_DIR
Remove-Item -Force "$PACKAGE_DIR\Sonarr.Mono.*" -ErrorAction SilentlyContinue
Remove-Item -Force "$PACKAGE_DIR\Mono.Posix.NETStandard.*" -ErrorAction SilentlyContinue
Copy-Item "$PACKAGE_DIR\Sonarr.Windows.*" "$PACKAGE_DIR\Sonarr.Update\"

# ZIP
Write-Host "🗜️ Creating ZIP..." -ForegroundColor Yellow
Compress-Archive -Path "$PACKAGE_DIR\*" -DestinationPath "_artifacts\Sonarr.v$Version.windows.zip" -Force

Write-Host "✅ Build completed successfully!" -ForegroundColor Green
Write-Host "📁 Package: $PACKAGE_DIR" -ForegroundColor Cyan
Write-Host "📦 ZIP: _artifacts\Sonarr.v$Version.windows.zip" -ForegroundColor Cyan
```

**Usage**:
```powershell
.\build-sonarr-windows.ps1 -Version "4.0.10.9999" -Branch "ffmpeg-encoding"
```

---

## 🎉 Résultat Final

Après compilation complète, vous aurez:

1. ✅ **Sonarr compilé** avec FFmpeg Encoding
2. ✅ **Package portable** dans `_artifacts/win-x64/net8.0/Sonarr/`
3. ✅ **Archive ZIP** pour distribution
4. ✅ **Logs de compilation** pour vérification

**Temps total**: ~10-15 minutes (selon la machine)

---

## 📚 Ressources

- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [.NET SDK Download](https://dotnet.microsoft.com/download)
- [FFmpeg Download](https://ffmpeg.org/download.html)
- [Node.js Download](https://nodejs.org/)
- [GitHub Sonarr](https://github.com/Sonarr/Sonarr)

---

**Créé avec ❤️ pour la communauté Sonarr**

🤖 Generated with [Claude Code](https://claude.com/claude-code)
