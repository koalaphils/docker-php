# Local Docker Build Script

Simple script to verify Docker images can be built locally without errors.

## Prerequisites

- Docker
- Composer (optional, for automatic GitHub token retrieval)

## Setup

Make the script executable:
```bash
chmod +x build-local.sh
```

Optional: Configure GitHub token in Composer for extension installations:
```bash
composer config --global github-oauth.github.com YOUR_GITHUB_TOKEN
```

## Usage

### Basic Syntax

```bash
./build-local.sh --version PHP_VERSION --variant VARIANT --mode MODE
```

### Parameters

**Required:**
- `--version, -v`: PHP version (e.g., 8.4.15, 8.3.28)
- `--variant, -t`: Variant (cli, cli-alpine, zts, zts-alpine, apache, fpm, fpm-alpine)
- `--mode, -m`: Build mode (`base`, `final`, or `both`)

**Optional:**
- `--github-token, -g`: GitHub token (auto-retrieved from Composer if not provided)
- `--help, -h`: Display help

### Build Modes

- `base` - Build base image only (cli, cli-alpine, zts, zts-alpine variants)
- `final` - Build final image only (requires base images to exist)
- `both` - Build both base and final images

## Examples

### Build CLI variant (base + final)

```bash
./build-local.sh --version 8.4.15 --variant cli --mode both
```

Builds:
- `php:8.4.15-cli-prebuild` (base image)
- `php:8.4.15-cli` (final image)

### Build only base image

```bash
./build-local.sh --version 8.3.28 --variant cli-alpine --mode base
```

Builds: `php:8.3.28-cli-alpine-prebuild`

### Build with custom GitHub token

```bash
./build-local.sh --version 8.4.15 --variant cli --mode both --github-token ghp_xxxxx
```

### Build Apache variant

Apache uses CLI base, so build CLI base first:

```bash
# Build CLI base
./build-local.sh --version 8.4.15 --variant cli --mode base

# Build Apache final
./build-local.sh --version 8.4.15 --variant apache --mode final
```

Or use `both` mode (script will prompt if CLI base is missing):

```bash
./build-local.sh --version 8.4.15 --variant apache --mode both
```

## Variant Dependencies

| Final Variant | Required Base Variant |
|---------------|----------------------|
| cli           | cli-prebuild         |
| cli-alpine    | cli-alpine-prebuild  |
| zts           | zts-prebuild         |
| zts-alpine    | zts-alpine-prebuild  |
| apache        | cli-prebuild         |
| fpm           | cli-prebuild         |
| fpm-alpine    | cli-alpine-prebuild  |

## How It Works

### Stage 1: Base Build (Prebuild Images)
- **Variants**: cli, cli-alpine, zts, zts-alpine
- **Process**: Installs PHP extensions and dependencies from source
- **Output**: `php:VERSION-VARIANT-prebuild`
- **Dockerfile**: `builder/VARIANT/Dockerfile`
- **Key feature**: Uses `--pull` flag to ensure official PHP base images (e.g., `php:8.4.15-cli`) are up to date
- **GitHub token**: Required for Composer authentication when installing PHP extensions

### Stage 2: Final Build
- **Variants**: All (cli, cli-alpine, zts, zts-alpine, apache, fpm, fpm-alpine)
- **Process**: 
  1. Checks if required prebuild image exists locally (fails fast with clear error if missing)
  2. Pre-pulls official PHP base image to ensure it's up-to-date (e.g., `php:8.4.15-fpm-alpine`)
  3. Builds final image: copies extensions from prebuild, installs runtime dependencies, configures PHP/Apache/FPM
- **Output**: `php:VERSION-VARIANT`
- **Dockerfile**: `Dockerfile-VARIANT`
- **Build context**: Only the specific required prebuild image is used (not all four)
  - `apache`, `fpm` → uses `cli-prebuild`
  - `fpm-alpine` → uses `cli-alpine-prebuild`
  - Other variants → uses their own respective prebuild
- **Important**: 
  - Does NOT use `--pull` flag during `docker build` (would break build-context)
  - Pre-pulls official base separately before building to keep it up-to-date
  - Final stage always uses official PHP images (e.g., `php:8.4.15-fpm-alpine`)
  - Prebuild images are only used as build-context to copy extensions

### Both Mode Behavior
When using `both` mode with variants that depend on other base variants (apache, fpm, fpm-alpine):
1. Script automatically builds the required base variant first (e.g., cli-prebuild for apache)
2. Then builds the final image using that base variant

Example: `./build-local.sh -v 8.4.15 -t apache -m both`
- Builds `php:8.4.15-cli-prebuild` first
- Then builds `php:8.4.15-apache` using the cli-prebuild as build context

## GitHub Token

The token is used for:
- Composer authentication when installing PHP extensions
- Accessing GitHub API during builds

Retrieve your token from Composer:
```bash
composer config --global github-oauth.github.com
```

The script automatically uses this if no token is provided.

## Troubleshooting

**Error: "docker is not available"**
```bash
docker version
```

**Error: "Dockerfile not found"**
Run the script from the project root directory.

**Build fails with authentication errors**
Provide a valid GitHub token:
```bash
./build-local.sh --version 8.4.15 --variant cli --mode both --github-token YOUR_TOKEN
```

**Error: "Variant does not have a base build"**
Variants like apache, fpm, fpm-alpine don't have their own base builds. Build the required base variant first (see Variant Dependencies table).

## Build All Variants

```bash
#!/bin/bash
VERSION="8.4.15"

# Build all base images
./build-local.sh --version $VERSION --variant cli --mode base
./build-local.sh --version $VERSION --variant cli-alpine --mode base
./build-local.sh --version $VERSION --variant zts --mode base
./build-local.sh --version $VERSION --variant zts-alpine --mode base

# Build all final images
./build-local.sh --version $VERSION --variant cli --mode final
./build-local.sh --version $VERSION --variant cli-alpine --mode final
./build-local.sh --version $VERSION --variant zts --mode final
./build-local.sh --version $VERSION --variant zts-alpine --mode final
./build-local.sh --version $VERSION --variant apache --mode final
./build-local.sh --version $VERSION --variant fpm --mode final
./build-local.sh --version $VERSION --variant fpm-alpine --mode final
```
