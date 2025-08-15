param(
    [string]$SourcePath = ".",
    [string]$OutputPath = "dist",
    [switch]$CreateVersioned,
    [switch]$Help
)

# Bilingual localization system
$SystemLanguage = (Get-Culture).TwoLetterISOLanguageName
$CurrentLanguage = if ($SystemLanguage -eq "es") { "es" } else { "en" }

$Messages = @{
    en = @{
        Title = "WordPress Plugin Builder - Universal plugin packaging script"
        Usage = "Usage: .\wp-plugin-builder.ps1 [-SourcePath <path>] [-OutputPath <path>] [-CreateVersioned] [-Help]"
        Parameters = "Parameters:"
        ParamSourcePath = "  -SourcePath     Plugin directory (default: current directory)"
        ParamOutputPath = "  -OutputPath     Output directory (default: 'dist')"
        ParamCreateVersioned = "  -CreateVersioned Also create ZIP with version in filename"
        ParamHelp = "  -Help           Show this help"
        AnalyzingPlugin = "Analyzing plugin..."
        PluginDetected = "Plugin detected:"
        Version = "Version:"
        MainFile = "Main file:"
        WarningsFound = "Warnings found:"
        PreparingFiles = "Preparing files..."
        CopyingFiles = "Copying {0} filtered files..."
        FilesCopied = "Files copied:"
        CreatingPackages = "Creating packages..."
        PackagedSuccessfully = "Plugin packaged successfully!"
        FilesGeneratedIn = "Files generated in:"
        ForWordPress = "- For WordPress upload"
        VersionedFile = "- Versioned file"
        ProcessCompleted = "Process completed!"
        ErrorNoMainFile = "No main PHP file with plugin header found"
        ErrorMissingPluginName = "Missing 'Plugin Name' in header"
        ErrorMissingVersion = "Missing 'Version' in header (recommended)"
        ErrorMissingReadme = "Missing readme.txt file (recommended for WordPress.org)"
        ErrorSourceNotExists = "Source directory does not exist: {0}"
        ErrorNoValidPlugin = "Could not detect a valid WordPress plugin in: {0}"
        ErrorNoFilesToPackage = "No files to package after applying exclusions. Check patterns."
        ErrorBackslashDetected = "Backslash entries detected in main zip."
        ErrorEntriesOutsideRoot = "Entries detected outside root folder '{0}/'."
        WarningVersionedNoVersion = "[WARNING] -CreateVersioned enabled but no 'Version' found in plugin header."
    }
    es = @{
        Title = "WordPress Plugin Builder - Script universal para empaquetar plugins"
        Usage = "Uso: .\wp-plugin-builder.ps1 [-SourcePath <ruta>] [-OutputPath <ruta>] [-CreateVersioned] [-Help]"
        Parameters = "Parametros:"
        ParamSourcePath = "  -SourcePath     Directorio del plugin (por defecto: directorio actual)"
        ParamOutputPath = "  -OutputPath     Directorio de salida (por defecto: 'dist')"
        ParamCreateVersioned = "  -CreateVersioned Crear tambien ZIP con version en el nombre"
        ParamHelp = "  -Help           Mostrar esta ayuda"
        AnalyzingPlugin = "Analizando plugin..."
        PluginDetected = "Plugin detectado:"
        Version = "Version:"
        MainFile = "Archivo principal:"
        WarningsFound = "Advertencias encontradas:"
        PreparingFiles = "Preparando archivos..."
        CopyingFiles = "Copiando {0} archivos filtrados..."
        FilesCopied = "Archivos copiados:"
        CreatingPackages = "Creando paquetes..."
        PackagedSuccessfully = "Plugin empaquetado exitosamente!"
        FilesGeneratedIn = "Archivos generados en:"
        ForWordPress = "- Para subir a WordPress"
        VersionedFile = "- Archivo versionado"
        ProcessCompleted = "Proceso completado!"
        ErrorNoMainFile = "No se encontro archivo PHP principal con cabecera de plugin"
        ErrorMissingPluginName = "Falta 'Plugin Name' en la cabecera"
        ErrorMissingVersion = "Falta 'Version' en la cabecera (recomendado)"
        ErrorMissingReadme = "Falta archivo readme.txt (recomendado para WordPress.org)"
        ErrorSourceNotExists = "El directorio de origen no existe: {0}"
        ErrorNoValidPlugin = "No se pudo detectar un plugin de WordPress valido en: {0}"
        ErrorNoFilesToPackage = "No hay archivos para empaquetar tras aplicar exclusiones. Revisa los patrones."
        ErrorBackslashDetected = "Se detectaron entradas con backslash en el zip principal."
        ErrorEntriesOutsideRoot = "Se detectaron entradas fuera de la carpeta raíz '{0}/'."
        WarningVersionedNoVersion = "[AVISO] -CreateVersioned activado pero no se encontró 'Version' en el header del plugin."
    }
}

function Get-LocalizedMessage {
    param([string]$Key, [object[]]$Args = @())
    $message = $Messages[$CurrentLanguage][$Key]
    if ($Args.Count -gt 0) {
        return ($message -f $Args)
    }
    return $message
}

if ($Help) {
    Write-Host (Get-LocalizedMessage "Title")
    Write-Host (Get-LocalizedMessage "Usage")
    Write-Host ""
    Write-Host (Get-LocalizedMessage "Parameters")
    Write-Host (Get-LocalizedMessage "ParamSourcePath")
    Write-Host (Get-LocalizedMessage "ParamOutputPath")
    Write-Host (Get-LocalizedMessage "ParamCreateVersioned")
    Write-Host (Get-LocalizedMessage "ParamHelp")
    exit 0
}

# Output colors
$ErrorColor = "Red"
$WarningColor = "Yellow"
$SuccessColor = "Green"
$InfoColor = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-PluginInfo {
    param([string]$SourceDir)
    
    $phpFiles = Get-ChildItem -Path $SourceDir -Filter "*.php" -File
    
    foreach ($file in $phpFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match 'Plugin Name:\s*(.+)') {
            $pluginName = $matches[1].Trim()
            $version = $null
            
            if ($content -match 'Version:\s*([0-9A-Za-z\.-_]+)') {
                $version = $matches[1].Trim()
            }
            
            return @{
                Name = $pluginName
                Version = $version
                MainFile = $file.Name
                MainFilePath = $file.FullName
            }
        }
    }
    
    return $null
}

function Test-PluginStructure {
    param([string]$SourceDir, [hashtable]$PluginInfo)
    
    $issues = @()
    
    if (-not $PluginInfo) {
        $issues += (Get-LocalizedMessage "ErrorNoMainFile")
        return $issues
    }
    
    if (-not $PluginInfo.Name) {
        $issues += (Get-LocalizedMessage "ErrorMissingPluginName")
    }
    
    if (-not $PluginInfo.Version) {
        $issues += (Get-LocalizedMessage "ErrorMissingVersion")
    }
    
    $readmeFile = Get-ChildItem -Path $SourceDir -Filter "readme.txt" -File -ErrorAction SilentlyContinue
    if (-not $readmeFile) {
        $issues += (Get-LocalizedMessage "ErrorMissingReadme")
    }
    
    return $issues
}

function Get-FilesToInclude {
    param([string]$SourceDir)
    
    $excludePatterns = @(
        "*.git*",
        ".gitignore", ".gitattributes", ".editorconfig",
        ".vscode", ".idea", ".fleet",
        ".github",
        "tests", "test", "spec",
        "dist", "build",
        "node_modules", "vendor/bin",
        "*.log", "*.tmp", "*.temp",
        "Thumbs.db", ".DS_Store",
        "*.zip", "*.rar", "*.7z",
        "*.md",
        "composer.json", "composer.lock",
        "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock",
        "webpack.config.*", "vite.config.*", "rollup.config.*",
        "build-plugin.ps1", "wp-plugin-builder*.ps1"
    )
    
    # Normalizar patrones: agregar comodines si no los tienen
    $excludePatterns = $excludePatterns | ForEach-Object {
        if ($_ -notlike '*`**' -and $_ -notlike '*?*' -and $_ -notmatch '^\*' -and $_ -notmatch '\*$') {
            "*$_*"
        } else {
            $_
        }
    }
    
    $allFiles = Get-ChildItem -Path $SourceDir -Recurse -File
    $filesToInclude = @()
    
    foreach ($file in $allFiles) {
        # Intenta GetRelativePath si existe; si no, usa Substring
        $normalizedSource = $SourceDir.TrimEnd(@('\', '/'))
        try {
            $relativePath = [System.IO.Path]::GetRelativePath($normalizedSource, $file.FullName)
        } catch {
            $relativePath = $file.FullName.Substring($normalizedSource.Length + 1)
        }
        $shouldExclude = $false
        
        foreach ($pattern in $excludePatterns) {
            if ($relativePath -like $pattern -or $file.Name -like $pattern) {
                $shouldExclude = $true
                break
            }
        }
        
        # Exclusión adicional por segmento para carpetas conocidas
        if ($relativePath -match '(?i)(^|[\\/])(node_modules|dist|build|\.git)([\\/]|$)') {
            $shouldExclude = $true
        }
        
        if (-not $shouldExclude) {
            $filesToInclude += $file
        }
    }
    
    return $filesToInclude
}

function Create-ZipWithUnixPaths {
    param(
        [string]$SourceDir,
        [string]$ZipPath,
        [string]$PluginName
    )
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }
    
    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    
    try {
        $root = (Resolve-Path $SourceDir).Path
        
        # Archivos con compresión óptima (los directorios se crean automáticamente)
        Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
            $normalizedRoot = $root.TrimEnd(@('\', '/'))
            $rel = $_.FullName.Substring($normalizedRoot.Length + 1)
            $unix = "$PluginName/" + ($rel -replace '\\', '/')
            
            $entry = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                $_.FullName,
                $unix,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
        }
    }
    finally {
        $zip.Dispose()
    }
}

# Main script
try {
    Write-ColorOutput "WordPress Plugin Builder v1.0" $InfoColor
    Write-ColorOutput "================================" $InfoColor
    
    # Validate paths
    $SourcePath = Resolve-Path $SourcePath -ErrorAction Stop
    
    if (-not (Test-Path $SourcePath -PathType Container)) {
        throw (Get-LocalizedMessage "ErrorSourceNotExists" $SourcePath)
    }
    
    # Get plugin information
    Write-ColorOutput (Get-LocalizedMessage "AnalyzingPlugin") $InfoColor
    $pluginInfo = Get-PluginInfo -SourceDir $SourcePath
    
    if (-not $pluginInfo) {
        throw (Get-LocalizedMessage "ErrorNoValidPlugin" $SourcePath)
    }
    
    $pluginName = ($pluginInfo.Name.ToLower() -replace '[^a-z0-9\-]+', '-').Trim('-')
    
    Write-ColorOutput "$(Get-LocalizedMessage 'PluginDetected') $($pluginInfo.Name)" $SuccessColor
    if ($pluginInfo.Version) {
        Write-ColorOutput "$(Get-LocalizedMessage 'Version') $($pluginInfo.Version)" $InfoColor
    }
    Write-ColorOutput "$(Get-LocalizedMessage 'MainFile') $($pluginInfo.MainFile)" $InfoColor
    
    # Validate structure
    $issues = Test-PluginStructure -SourceDir $SourcePath -PluginInfo $pluginInfo
    if ($issues.Count -gt 0) {
        Write-ColorOutput (Get-LocalizedMessage "WarningsFound") $WarningColor
        foreach ($issue in $issues) {
            Write-ColorOutput "  - $issue" $WarningColor
        }
        Write-ColorOutput "" # Empty line
    }
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Create temporary directory
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "wp-plugin-build-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # Copy files to temporary directory
    Write-ColorOutput (Get-LocalizedMessage "PreparingFiles") $InfoColor
    
    $filesToInclude = Get-FilesToInclude -SourceDir $SourcePath
    
    # Fail fast if nothing to package
    if (-not $filesToInclude -or $filesToInclude.Count -eq 0) {
        throw (Get-LocalizedMessage "ErrorNoFilesToPackage")
    }
    
    $copyingMessage = Get-LocalizedMessage "CopyingFiles"
    Write-ColorOutput ($copyingMessage -f $filesToInclude.Count) $InfoColor
    foreach ($file in $filesToInclude) {
        $normalizedSource = $SourcePath.TrimEnd(@('\', '/'))
        try {
            $relativePath = [System.IO.Path]::GetRelativePath($normalizedSource, $file.FullName)
        } catch {
            $relativePath = $file.FullName.Substring($normalizedSource.Length + 1)
        }
        $destPath = Join-Path $tempDir $relativePath
        $destDir = Split-Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop | Out-Null
        }
        
        Copy-Item $file.FullName $destPath -Force -ErrorAction Stop
    }
    
    Write-ColorOutput "$(Get-LocalizedMessage 'FilesCopied') $($filesToInclude.Count)" $InfoColor
    
    # Create ZIPs
    Write-ColorOutput (Get-LocalizedMessage "CreatingPackages") $InfoColor
    
    # Main ZIP (replaceable)
    $mainZipPath = Join-Path $OutputPath "$pluginName.zip"
    Create-ZipWithUnixPaths -SourceDir $tempDir -ZipPath $mainZipPath -PluginName $pluginName
    
    # Verify paths with backslash and correct structure
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipFile = [System.IO.Compression.ZipFile]::OpenRead($mainZipPath)
    $badEntries = $zipFile.Entries | Where-Object { $_.FullName -match '\\' }
    $badRootEntries = $zipFile.Entries | Where-Object { $_.FullName -notmatch "^(?i)$([regex]::Escape($pluginName))/" }
    $zipFile.Dispose()
    if ($badEntries) { throw (Get-LocalizedMessage "ErrorBackslashDetected") }
    if ($badRootEntries) { throw (Get-LocalizedMessage "ErrorEntriesOutsideRoot" $pluginName) }
    
    $mainZipSize = [math]::Round((Get-Item $mainZipPath).Length / 1KB, 2)
    Write-ColorOutput "   [OK] $pluginName.zip ($mainZipSize KB)" $SuccessColor
    
    # Versioned ZIP (optional)
    if ($CreateVersioned -and -not $pluginInfo.Version) {
        Write-ColorOutput (Get-LocalizedMessage "WarningVersionedNoVersion") $WarningColor
    }
    
    if ($CreateVersioned -and $pluginInfo.Version) {
        $versionedFileName = $pluginName + "-" + $pluginInfo.Version + ".zip"
        $versionedZipPath = Join-Path $OutputPath $versionedFileName
        Create-ZipWithUnixPaths -SourceDir $tempDir -ZipPath $versionedZipPath -PluginName $pluginName
        
        $versionedZipSize = [math]::Round((Get-Item $versionedZipPath).Length / 1KB, 2)
        Write-ColorOutput "   [OK] $versionedFileName ($versionedZipSize KB)" $SuccessColor
    }
    
    Write-ColorOutput (Get-LocalizedMessage "PackagedSuccessfully") $SuccessColor
    Write-ColorOutput "$(Get-LocalizedMessage 'FilesGeneratedIn') $OutputPath" $InfoColor
    Write-ColorOutput "   - $pluginName.zip $(Get-LocalizedMessage 'ForWordPress')" "White"
    if ($CreateVersioned -and $pluginInfo.Version) {
        $versionedName = $pluginName + "-" + $pluginInfo.Version + ".zip"
        Write-ColorOutput "   - $versionedName $(Get-LocalizedMessage 'VersionedFile')" "White"
    }
    
}
finally {
    # Clean temporary directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-ColorOutput (Get-LocalizedMessage "ProcessCompleted") $SuccessColor