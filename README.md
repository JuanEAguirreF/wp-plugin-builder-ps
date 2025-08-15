# WP Plugin Builder (PowerShell)

> Build clean, WordPress-compatible ZIPs for your plugin — with correct Unix-style paths, a single root folder, optional versioned artifacts, and sensible excludes. Works on Windows/macOS/Linux with PowerShell 7+.

---

## English

### Why this exists

While developing WordPress plugins **on Windows**, I often iterate many test builds and need:

1. a **ZIP ready to upload** to WordPress, and
2. sometimes **versioned archives** to track changes.

Windows uses backslashes (`\`). When such ZIPs are unpacked on Linux/PHP (like most WP hosts), those backslashes may show up as **literal characters** in entry names instead of **real folders**. This script **forces Unix **``** separators**, wraps everything under a **single **``** root folder**, preserves empty directories, and applies **sensible exclusions** — so uploads/installations work smoothly in WordPress.

### Features

- ✅ **Correct internal paths**: always `/`, never `\`
- ✅ **Single root folder**: `plugin-slug/…`
- ✅ **Optional versioned ZIP**: `plugin-slug-<version>.zip` (reads `Version:` from your plugin header)
- ✅ **Empty directories preserved** (e.g., `languages/`)
- ✅ **Sensible excludes**: `node_modules`, `dist`, `.git`, `*.md`, etc.
- ✅ **Deterministic-friendly**: stable ordering recommended
- ✅ **Cross-platform**: PowerShell 7+ on Windows/macOS/Linux

### Requirements

- PowerShell 7+ (`pwsh`)
- Your main plugin file includes a standard WordPress header, e.g.:

```php
/*
Plugin Name: My Awesome Plugin
Version:     1.6.0
*/
```

### Installation

Place `wp-plugin-builder.ps1` at the repository root. No external dependencies required.

## 📂 Real Usage Example with Parameters

This example creates a versioned plugin ZIP ready to upload to WordPress:

```powershell
# Plugin source folder
$source = "C:\path\to\my-plugin"

# Output folder for the ZIP file
$output = "C:\path\to\zips"

# Run script
./wp-plugin-builder.ps1 -SourcePath $source -OutputPath $output -CreateVersioned
```

Main parameters:

- `-SourcePath` → Folder containing your plugin.
- `-OutputPath` → Folder where the ZIP will be saved.
- `-CreateVersioned` → Appends the version number to the ZIP file name.

---

## 📦 Advanced Example with `-Include`

You can also specify exactly which files and folders to include in the ZIP:

```powershell
./wp-plugin-builder.ps1 `
  -SourcePath . `
  -OutputPath dist `
  -Include 'my-plugin.php','readme.txt','assets','includes','languages' `
  -CreateVersioned
```

Or using *splatting* for cleaner syntax:

```powershell
$Params = @{
  SourcePath      = .
  OutputPath      = 'dist'
  Include         = @('my-plugin.php','readme.txt','assets','includes','languages')
  CreateVersioned = $true
}
./wp-plugin-builder.ps1 @Params
```

**Output:**
- `dist/<plugin-slug>.zip`
- `dist/<plugin-slug>-<version>.zip` (when `-CreateVersioned` and header `Version` exists)



### CI: GitHub Actions

**Build artifacts on push/PR**

```yaml
# .github/workflows/ci.yml
name: CI — Build plugin ZIPs

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build ZIPs
        shell: pwsh
        run: ./wp-plugin-builder.ps1 -SourcePath . -OutputPath dist -CreateVersioned
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: plugin-zips
          path: dist/*.zip
          if-no-files-found: error
```

**Release on tag** (validates tag vs. header `Version:` and publishes ZIPs)

```yaml
# .github/workflows/release.yml
name: Release — Tag to GitHub Release

on:
  push:
    tags:
      - 'v*.*.*'
      - 'v*.*'

permissions:
  contents: write

jobs:
  release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract plugin meta
        id: meta
        shell: pwsh
        run: |
          $main = Get-ChildItem -Path . -Filter *.php -File -Depth 1 |
            Where-Object { (Get-Content $_.FullName -Raw) -match '(?im)^\s*Plugin\s+Name\s*:\s*(.+)$' } |
            Select-Object -First 1
          if(-not $main){ $main = Get-ChildItem -Path . -Filter *.php -File -Recurse | Select-Object -First 1 }
          if(-not $main){ throw 'Main plugin file not found' }

          $raw = Get-Content -Path $main.FullName -Raw
          if($raw -match '(?im)^\s*Plugin\s+Name\s*:\s*(.+)$'){ $name = $Matches[1].Trim() } else { throw 'Plugin Name not found' }
          if($raw -match '(?im)^\s*Version\s*:\s*([0-9A-Za-z._-]+)'){ $version = $Matches[1].Trim() } else { throw 'Version not found' }

          $slug = ($name.ToLower() -replace '[^a-z0-9\-]+','-').Trim('-')
          "slug=$slug"       | Out-File -Append -FilePath $env:GITHUB_OUTPUT
          "version=$version" | Out-File -Append -FilePath $env:GITHUB_OUTPUT

      - name: Validate tag == header Version
        shell: pwsh
        run: |
          $tag = "$env:GITHUB_REF_NAME"  # e.g., v1.6.0
          $tagVer = $tag.TrimStart('v')
          if($tagVer -ne "${{ steps.meta.outputs.version }}"){
            throw "Tag ($tag) does not match plugin Version (${{ steps.meta.outputs.version }})"
          }

      - name: Build ZIPs for release
        shell: pwsh
        run: ./wp-plugin-builder.ps1 -SourcePath . -OutputPath dist -CreateVersioned

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: "${{ steps.meta.outputs.slug }} ${{ steps.meta.outputs.version }}"
          tag_name: ${{ github.ref_name }}
          files: dist/*.zip
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Tag & push:

```bash
git tag -a v1.6.0 -m "Release v1.6.0"
git push origin v1.6.0
```

### Verification tips

- No backslashes inside ZIP (all entries use `/`)
- All entries live under `plugin-slug/…`
- `plugin-slug/readme.txt` (recommended) and your main `.php` at that root
- Excludes applied (`node_modules`, `dist`, `.git`, `*.md`, etc.)
- (Optional) Sort files before zipping for stable builds

### Roadmap (Maybe not)

- Support `.distignore`/`.gitattributes`-style excludes
- Package as a PowerShell module and/or composite Action
- Pester tests for structure & path assertions

### License

MIT

---

## Español

### ¿Por qué existe?

Al desarrollar **plugins de WordPress en Windows**, suelo iterar muchas versiones de prueba y necesito:

1. un **ZIP listo para subir** a WordPress, y
2. a veces **ZIPs versionados** para llevar control.

Windows usa backslashes (`\`). Al descomprimir ese ZIP en Linux/PHP (la mayoría de hosts WP), esos backslashes pueden quedar como **caracteres literales** en los nombres en vez de **carpetas reales**. Este script **fuerza separadores Unix **``, agrupa todo bajo **una sola carpeta raíz **``, preserva directorios vacíos y aplica **exclusiones razonables** — así la subida/instalación en WordPress funciona sin sorpresas.

### Características

- ✅ **Rutas internas correctas**: siempre `/`, nunca `\`
- ✅ **Carpeta raíz única**: `plugin-slug/…`
- ✅ **ZIP versionado opcional**: `plugin-slug-<version>.zip` (lee `Version:` del header del plugin)
- ✅ **Preserva directorios vacíos** (p. ej., `languages/`)
- ✅ **Exclusiones sensatas**: `node_modules`, `dist`, `.git`, `*.md`, etc.
- ✅ **Apto para builds deterministas**: se recomienda orden estable
- ✅ **Multiplataforma**: PowerShell 7+ en Windows/macOS/Linux

### Requisitos

- PowerShell 7+ (`pwsh`)
- Tu archivo principal debe incluir el header estándar de WP, por ejemplo:

```php
/*
Plugin Name: Mi Plugin Genial
Version:     1.6.0
*/
```

### Instalación

Coloca `wp-plugin-builder.ps1` en la raíz del repositorio. No requiere dependencias externas.

## 📂 Ejemplo de uso real con parámetros

Este ejemplo crea un ZIP versionado del plugin, listo para subir a WordPress:

```powershell
# Carpeta de origen del plugin
$source = "C:\ruta\a\mi-plugin"

# Carpeta de salida donde se guardará el ZIP
$output = "C:\ruta\a\zips"

# Ejecutar script
./wp-plugin-builder.ps1 -SourcePath $source -OutputPath $output -CreateVersioned
```

Parámetros principales:

- `-SourcePath` → Carpeta donde está tu plugin.
- `-OutputPath` → Carpeta donde se guardará el archivo ZIP.
- `-CreateVersioned` → Añade el número de versión al nombre del archivo ZIP.

---

## 📦 Ejemplo avanzado con `-Include`

También puedes indicar exactamente qué archivos y carpetas incluir en el ZIP:

```powershell
./wp-plugin-builder.ps1 `
  -SourcePath . `
  -OutputPath dist `
  -Include 'mi-plugin.php','readme.txt','assets','includes','languages' `
  -CreateVersioned
```

O usando *splatting* para mayor legibilidad:

```powershell
$Parametros = @{
  SourcePath      = .
  OutputPath      = 'dist'
  Include         = @('mi-plugin.php','readme.txt','assets','includes','languages')
  CreateVersioned = $true
}
./wp-plugin-builder.ps1 @Parametros
```

**Salida:**
- `dist/<slug-del-plugin>.zip`
- `dist/<slug-del-plugin>-<version>.zip` (cuando se usa `-CreateVersioned` y el encabezado `Version` existe)


### CI: GitHub Actions

**Compilar artefactos en push/PR**

```yaml
# .github/workflows/ci.yml
name: CI — Build plugin ZIPs

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Construir ZIPs
        shell: pwsh
        run: ./wp-plugin-builder.ps1 -SourcePath . -OutputPath dist -CreateVersioned
      - name: Publicar artefactos
        uses: actions/upload-artifact@v4
        with:
          name: plugin-zips
          path: dist/*.zip
          if-no-files-found: error
```

**Release por tag** (valida el tag vs. `Version:` del header y publica ZIPs)

```yaml
# .github/workflows/release.yml
name: Release — Tag to GitHub Release

on:
  push:
    tags:
      - 'v*.*.*'
      - 'v*.*'

permissions:
  contents: write

jobs:
  release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extraer metadatos del plugin
        id: meta
        shell: pwsh
        run: |
          $main = Get-ChildItem -Path . -Filter *.php -File -Depth 1 |
            Where-Object { (Get-Content $_.FullName -Raw) -match '(?im)^\s*Plugin\s+Name\s*:\s*(.+)$' } |
            Select-Object -First 1
          if(-not $main){ $main = Get-ChildItem -Path . -Filter *.php -File -Recurse | Select-Object -First 1 }
          if(-not $main){ throw 'No se encontró el archivo principal del plugin' }

          $raw = Get-Content -Path $main.FullName -Raw
          if($raw -match '(?im)^\s*Plugin\s+Name\s*:\s*(.+)$'){ $name = $Matches[1].Trim() } else { throw 'No se encontró Plugin Name' }
          if($raw -match '(?im)^\s*Version\s*:\s*([0-9A-Za-z._-]+)'){ $version = $Matches[1].Trim() } else { throw 'No se encontró Version' }

          $slug = ($name.ToLower() -replace '[^a-z0-9\-]+','-').Trim('-')
          "slug=$slug"       | Out-File -Append -FilePath $env:GITHUB_OUTPUT
          "version=$version" | Out-File -Append -FilePath $env:GITHUB_OUTPUT

      - name: Validar tag == versión del header
        shell: pwsh
        run: |
          $tag = "$env:GITHUB_REF_NAME"  # ej: v1.6.0
          $tagVer = $tag.TrimStart('v')
          if($tagVer -ne "${{ steps.meta.outputs.version }}"){
            throw "El tag ($tag) no coincide con la versión del plugin (${{ steps.meta.outputs.version }})"
          }

      - name: Construir ZIPs para release
        shell: pwsh
        run: ./wp-plugin-builder.ps1 -SourcePath . -OutputPath dist -CreateVersioned

      - name: Crear GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: "${{ steps.meta.outputs.slug }} ${{ steps.meta.outputs.version }}"
          tag_name: ${{ github.ref_name }}
          files: dist/*.zip
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Crear y subir el tag:

```bash
git tag -a v1.6.0 -m "Release v1.6.0"
git push origin v1.6.0
```

### Verificación rápida

- Sin backslashes en el ZIP (todo `/`)
- Todo dentro de `plugin-slug/…`
- `plugin-slug/readme.txt` recomendado y tu `.php` principal en esa raíz
- Exclusiones aplicadas (`node_modules`, `dist`, `.git`, `*.md`, etc.)
- (Opcional) Ordenar archivos antes de zipear para builds estables

### Roadmap (Tal vez no lo haga)

- Soporte a exclusiones estilo `.distignore`/`.gitattributes`
- Publicarlo como módulo PowerShell / Action compuesta
- Tests con Pester

### Licencia

MIT

