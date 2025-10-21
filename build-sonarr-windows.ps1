#Requires -Version 5.1

<#
.SYNOPSIS
    Builds Sonarr for Windows with FFmpeg Encoding feature
.DESCRIPTION
    This script automates the compilation of Sonarr backend and frontend,
    creates a complete package ready for distribution or installation.
.PARAMETER Version
    Version number to use for the build (default: 4.0.10.9999)
.PARAMETER Branch
    Branch name to use in assembly configuration (default: ffmpeg-encoding)
.PARAMETER SkipFrontend
    Skip frontend compilation (useful for backend-only changes)
.PARAMETER SkipBackend
    Skip backend compilation (useful for frontend-only changes)
.PARAMETER CreateZip
    Create a ZIP archive of the final package
.EXAMPLE
    .\build-sonarr-windows.ps1
    Builds Sonarr with default settings
.EXAMPLE
    .\build-sonarr-windows.ps1 -Version "4.0.11.1000" -Branch "my-feature" -CreateZip
    Builds Sonarr with custom version, branch name, and creates ZIP
#>

param(
    [string]$Version = "4.0.10.9999",
    [string]$Branch = "ffmpeg-encoding",
    [switch]$SkipFrontend,
    [switch]$SkipBackend,
    [switch]$CreateZip
)

$ErrorActionPreference = "Stop"

# Colors
function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $previousColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Output $Message
    $Host.UI.RawUI.ForegroundColor = $previousColor
}

# Banner
Write-ColorOutput @"

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ███████╗ ██████╗ ███╗   ██╗ █████╗ ██████╗ ██████╗       ║
║   ██╔════╝██╔═══██╗████╗  ██║██╔══██╗██╔══██╗██╔══██╗      ║
║   ███████╗██║   ██║██╔██╗ ██║███████║██████╔╝██████╔╝      ║
║   ╚════██║██║   ██║██║╚██╗██║██╔══██║██╔══██╗██╔══██╗      ║
║   ███████║╚██████╔╝██║ ╚████║██║  ██║██║  ██║██║  ██║      ║
║   ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝      ║
║                                                              ║
║              Build Script with FFmpeg Encoding              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -Color Cyan

Write-ColorOutput "🚀 Building Sonarr $Version ($Branch)" -Color Cyan
Write-Output ""

# Check prerequisites
Write-ColorOutput "🔍 Checking prerequisites..." -Color Yellow

# Check .NET SDK
try {
    $dotnetVersion = & dotnet --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  ✅ .NET SDK: $dotnetVersion" -Color Green
    } else {
        throw
    }
} catch {
    Write-ColorOutput "  ❌ .NET SDK 8.0 is not installed!" -Color Red
    Write-Output "     Download from: https://dotnet.microsoft.com/download/dotnet/8.0"
    exit 1
}

# Check Node.js
if (-not $SkipFrontend) {
    try {
        $nodeVersion = & node --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  ✅ Node.js: $nodeVersion" -Color Green
        } else {
            throw
        }
    } catch {
        Write-ColorOutput "  ❌ Node.js is not installed!" -Color Red
        Write-Output "     Download from: https://nodejs.org/"
        exit 1
    }

    # Check Yarn
    try {
        $yarnVersion = & yarn --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  ✅ Yarn: $yarnVersion" -Color Green
        } else {
            throw
        }
    } catch {
        Write-ColorOutput "  ❌ Yarn is not installed!" -Color Red
        Write-Output "     Install with: npm install -g yarn"
        exit 1
    }
}

Write-Output ""

# Clean previous builds
Write-ColorOutput "🧹 Cleaning previous builds..." -Color Yellow
$cleanDirs = @("_output", "_artifacts", "_tests")
foreach ($dir in $cleanDirs) {
    if (Test-Path $dir) {
        Remove-Item -Recurse -Force $dir
        Write-Output "  Removed $dir"
    }
}
Write-ColorOutput "  ✅ Clean completed" -Color Green
Write-Output ""

# Update version number
if (-not $SkipBackend) {
    Write-ColorOutput "📝 Updating version to $Version..." -Color Yellow
    $propsFile = "src\Directory.Build.props"

    if (Test-Path $propsFile) {
        $content = Get-Content $propsFile -Raw
        $content = $content -replace '<AssemblyVersion>[\d.]+</AssemblyVersion>', "<AssemblyVersion>$Version</AssemblyVersion>"
        $content = $content -replace '<AssemblyConfiguration>.*</AssemblyConfiguration>', "<AssemblyConfiguration>$Branch</AssemblyConfiguration>"
        Set-Content -Path $propsFile -Value $content -NoNewline
        Write-ColorOutput "  ✅ Version updated in Directory.Build.props" -Color Green
    } else {
        Write-ColorOutput "  ⚠️  Warning: Directory.Build.props not found" -Color Yellow
    }
    Write-Output ""
}

# Build backend
if (-not $SkipBackend) {
    Write-ColorOutput "🏗️  Building backend (.NET)..." -Color Yellow
    Write-Output "  This may take 5-10 minutes..."
    Write-Output ""

    $buildStart = Get-Date

    try {
        & dotnet msbuild src/Sonarr.sln `
            -restore `
            -p:Configuration=Release `
            -p:Platform=Windows `
            -p:RuntimeIdentifiers=win-x64 `
            -p:SelfContained=True `
            -p:EnableWindowsTargeting=true `
            -t:PublishAllRids

        if ($LASTEXITCODE -ne 0) {
            throw "Backend build failed with exit code $LASTEXITCODE"
        }

        $buildTime = [math]::Round(((Get-Date) - $buildStart).TotalSeconds, 1)
        Write-Output ""
        Write-ColorOutput "  ✅ Backend build completed in $buildTime seconds" -Color Green
    } catch {
        Write-ColorOutput "  ❌ Backend build failed: $_" -Color Red
        exit 1
    }
    Write-Output ""
}

# Build frontend
if (-not $SkipFrontend) {
    Write-ColorOutput "🎨 Building frontend (React/TypeScript)..." -Color Yellow
    Write-Output "  Installing dependencies..."

    $frontendStart = Get-Date

    try {
        # Install dependencies
        & yarn install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) {
            throw "Yarn install failed with exit code $LASTEXITCODE"
        }

        Write-Output ""
        Write-Output "  Compiling frontend..."

        # Build frontend
        & yarn build --env production
        if ($LASTEXITCODE -ne 0) {
            throw "Frontend build failed with exit code $LASTEXITCODE"
        }

        $frontendTime = [math]::Round(((Get-Date) - $frontendStart).TotalSeconds, 1)
        Write-Output ""
        Write-ColorOutput "  ✅ Frontend build completed in $frontendTime seconds" -Color Green
    } catch {
        Write-ColorOutput "  ❌ Frontend build failed: $_" -Color Red
        exit 1
    }
    Write-Output ""
}

# Package Sonarr
Write-ColorOutput "📦 Packaging Sonarr..." -Color Yellow

$PACKAGE_DIR = "_artifacts\win-x64\net8.0\Sonarr"

try {
    # Create package directory
    New-Item -ItemType Directory -Force -Path $PACKAGE_DIR | Out-Null
    Write-Output "  Created package directory"

    # Copy backend files
    if (Test-Path "_output\net8.0\win-x64\publish") {
        Copy-Item -Recurse -Force "_output\net8.0\win-x64\publish\*" $PACKAGE_DIR
        Write-Output "  Copied backend files"
    }

    # Copy Sonarr.Update
    if (Test-Path "_output\Sonarr.Update\net8.0\win-x64\publish") {
        Copy-Item -Recurse -Force "_output\Sonarr.Update\net8.0\win-x64\publish" "$PACKAGE_DIR\Sonarr.Update"
        Write-Output "  Copied Sonarr.Update"
    }

    # Copy Windows-specific files
    if (Test-Path "_output\net8.0-windows\win-x64\publish") {
        Copy-Item -Recurse -Force "_output\net8.0-windows\win-x64\publish\*" $PACKAGE_DIR
        Write-Output "  Copied Windows-specific files"
    }

    # Copy LICENSE
    if (Test-Path "LICENSE.md") {
        Copy-Item "LICENSE.md" $PACKAGE_DIR
        Write-Output "  Copied LICENSE.md"
    }

    # Remove non-Windows files
    Remove-Item -Force "$PACKAGE_DIR\Sonarr.Mono.*" -ErrorAction SilentlyContinue
    Remove-Item -Force "$PACKAGE_DIR\Mono.Posix.NETStandard.*" -ErrorAction SilentlyContinue
    Remove-Item -Force "$PACKAGE_DIR\libMonoPosixHelper.*" -ErrorAction SilentlyContinue
    Write-Output "  Removed non-Windows files"

    # Add Sonarr.Windows to Update package
    if (Test-Path "$PACKAGE_DIR\Sonarr.Windows.dll") {
        Copy-Item "$PACKAGE_DIR\Sonarr.Windows.*" "$PACKAGE_DIR\Sonarr.Update\"
        Write-Output "  Added Sonarr.Windows to Update package"
    }

    Write-ColorOutput "  ✅ Packaging completed" -Color Green
} catch {
    Write-ColorOutput "  ❌ Packaging failed: $_" -Color Red
    exit 1
}
Write-Output ""

# Create ZIP archive
if ($CreateZip) {
    Write-ColorOutput "🗜️  Creating ZIP archive..." -Color Yellow

    $zipPath = "_artifacts\Sonarr.v$Version.windows.zip"

    try {
        # Check if 7-Zip is available
        $sevenZip = $null
        $sevenZipPaths = @(
            "C:\Program Files\7-Zip\7z.exe",
            "C:\Program Files (x86)\7-Zip\7z.exe",
            "$env:ProgramFiles\7-Zip\7z.exe"
        )

        foreach ($path in $sevenZipPaths) {
            if (Test-Path $path) {
                $sevenZip = $path
                break
            }
        }

        if ($sevenZip) {
            Write-Output "  Using 7-Zip for compression..."
            & $sevenZip a -tzip $zipPath "$PACKAGE_DIR\*"
            if ($LASTEXITCODE -ne 0) {
                throw "7-Zip compression failed"
            }
        } else {
            Write-Output "  Using PowerShell compression (slower)..."
            Compress-Archive -Path "$PACKAGE_DIR\*" -DestinationPath $zipPath -Force
        }

        $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
        Write-ColorOutput "  ✅ ZIP created: $zipPath ($zipSize MB)" -Color Green
    } catch {
        Write-ColorOutput "  ❌ ZIP creation failed: $_" -Color Red
        exit 1
    }
    Write-Output ""
}

# Summary
Write-ColorOutput @"

╔══════════════════════════════════════════════════════════════╗
║                    BUILD COMPLETED! ✅                        ║
╚══════════════════════════════════════════════════════════════╝

"@ -Color Green

Write-ColorOutput "📁 Build Artifacts:" -Color Cyan
Write-Output ""
Write-Output "  Package Directory:"
Write-ColorOutput "    $PACKAGE_DIR" -Color Yellow
Write-Output ""

if (Test-Path "$PACKAGE_DIR\Sonarr.exe") {
    Write-ColorOutput "  Main Executable:" -Color Cyan
    Write-ColorOutput "    $PACKAGE_DIR\Sonarr.exe" -Color Yellow
    Write-Output ""
}

if (Test-Path "$PACKAGE_DIR\Sonarr.Console.exe") {
    Write-ColorOutput "  Console Executable (with logs):" -Color Cyan
    Write-ColorOutput "    $PACKAGE_DIR\Sonarr.Console.exe" -Color Yellow
    Write-Output ""
}

if ($CreateZip -and (Test-Path $zipPath)) {
    Write-ColorOutput "  ZIP Archive:" -Color Cyan
    Write-ColorOutput "    $zipPath" -Color Yellow
    Write-Output ""
}

Write-ColorOutput "🚀 Next Steps:" -Color Cyan
Write-Output ""
Write-Output "  1. Test locally:"
Write-ColorOutput "     cd $PACKAGE_DIR" -Color Yellow
Write-ColorOutput "     .\Sonarr.Console.exe" -Color Yellow
Write-Output ""
Write-Output "  2. Access Sonarr:"
Write-ColorOutput "     http://localhost:8989" -Color Yellow
Write-Output ""
Write-Output "  3. Configure FFmpeg Encoding:"
Write-Output "     Settings → Media Management → FFmpeg Encoding"
Write-Output ""

Write-ColorOutput "📚 Documentation:" -Color Cyan
Write-Output "  - COMPILATION_WINDOWS.md - Compilation guide"
Write-Output "  - FFMPEG_ENCODING_FEATURE.md - FFmpeg feature documentation"
Write-Output ""

Write-ColorOutput "✨ Build completed successfully!" -Color Green
Write-Output ""
