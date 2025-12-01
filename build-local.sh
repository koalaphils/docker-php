#!/bin/bash

# Simple script to verify local Docker image builds
# Builds base and final images locally for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PHP_VERSION=""
VARIANT=""
BUILD_MODE=""
GITHUB_TOKEN=""

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -v, --version VERSION       PHP version (e.g., 8.4.15, 8.3.28)
    -t, --variant VARIANT       Variant type (cli, cli-alpine, zts, zts-alpine, apache, fpm, fpm-alpine)
    -m, --mode MODE             Build mode: 'base' for prebuild images, 'final' for final images, 'both' for both
    -g, --github-token TOKEN    GitHub token (optional, will try to retrieve from composer if not provided)
    -h, --help                  Display this help message

Examples:
    # Build base image only (prebuild)
    $0 --version 8.4.15 --variant cli --mode base

    # Build final image using existing prebuild
    $0 --version 8.4.15 --variant cli --mode final

    # Build both base and final images
    $0 --version 8.4.15 --variant cli --mode both

    # Build with custom GitHub token
    $0 --version 8.4.15 --variant cli --mode both --github-token ghp_xxxxx

EOF
    exit 1
}

# Function to retrieve GitHub token from composer
get_github_token_from_composer() {
    echo -e "${YELLOW}Attempting to retrieve GitHub token from Composer...${NC}" >&2
    
    # Try to get token from composer config
    local token=$(composer config --global github-oauth.github.com 2>/dev/null || echo "")
    
    if [ -n "$token" ]; then
        echo -e "${GREEN}GitHub token retrieved from Composer configuration${NC}" >&2
        echo "$token"
    else
        echo -e "${YELLOW}No GitHub token found in Composer configuration${NC}" >&2
        echo ""
    fi
}

# Function to validate variant
validate_variant() {
    local variant=$1
    local valid_variants=("cli" "cli-alpine" "zts" "zts-alpine" "apache" "fpm" "fpm-alpine")
    
    for valid in "${valid_variants[@]}"; do
        if [ "$variant" = "$valid" ]; then
            return 0
        fi
    done
    
    echo -e "${RED}Error: Invalid variant '$variant'${NC}"
    echo "Valid variants: ${valid_variants[*]}"
    exit 1
}

# Function to check if variant needs base build
needs_base_build() {
    local variant=$1
    case "$variant" in
        cli|cli-alpine|zts|zts-alpine)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get base variant for final builds
get_base_variant() {
    local variant=$1
    case "$variant" in
        apache|fpm)
            echo "cli"
            ;;
        fpm-alpine)
            echo "cli-alpine"
            ;;
        cli|cli-alpine|zts|zts-alpine)
            echo "$variant"
            ;;
    esac
}

# Function to build base (prebuild) image
build_base_image() {
    local version=$1
    local variant=$2
    local github_token=$3
    
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}Building BASE image for PHP ${version} ${variant}${NC}"
    echo -e "${GREEN}======================================${NC}"
    
    local dockerfile="builder/${variant}/Dockerfile"
    local image_tag="php:${version}-${variant}-prebuild"
    
    if [ ! -f "$dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile not found: $dockerfile${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Building: $image_tag${NC}"
    
    if [ -n "$github_token" ]; then
        echo -e "${YELLOW}Using provided GitHub token${NC}"
        echo "$github_token" | docker buildx build \
            --pull \
            --file "$dockerfile" \
            --build-arg PHP_VERSION="$version" \
            --tag "$image_tag" \
            --secret id=github_token,src=/dev/stdin \
            .
    else
        echo -e "${YELLOW}Warning: No GitHub token provided. Build may fail if private repositories are accessed.${NC}"
        docker buildx build \
            --pull \
            --file "$dockerfile" \
            --build-arg PHP_VERSION="$version" \
            --tag "$image_tag" \
            .
    fi
    
    echo -e "${GREEN}Base image built successfully: $image_tag${NC}"
}

# Function to build final image
build_final_image() {
    local version=$1
    local variant=$2
    
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}Building FINAL image for PHP ${version} ${variant}${NC}"
    echo -e "${GREEN}======================================${NC}"
    
    local dockerfile="Dockerfile-${variant}"
    local image_tag="php:${version}-${variant}"
    
    if [ ! -f "$dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile not found: $dockerfile${NC}"
        exit 1
    fi
    
    # Determine which base variant is required for this variant
    local base_variant=$(get_base_variant "$variant")
    
    # Check if required prebuild image exists locally
    local prebuild_image="php:${version}-${base_variant}-prebuild"
    if ! docker image inspect "$prebuild_image" >/dev/null 2>&1; then
        echo -e "${RED}Error: Required prebuild image not found: ${prebuild_image}${NC}"
        echo "Tip: Build it first with:"
        echo "  $0 --version $version --variant $base_variant --mode base"
        echo "Or use:"
        echo "  $0 --version $version --variant $variant --mode both"
        exit 1
    fi
    
    local build_contexts=""
    
    # Only add the specific build context needed for this variant
    build_contexts="--build-context php-${version}-${base_variant}=docker-image://php:${version}-${base_variant}-prebuild"
    
    echo -e "${YELLOW}Building: $image_tag${NC}"
    echo -e "${YELLOW}Using base context: php-${version}-${base_variant}-prebuild${NC}"
    
    # Pre-pull official base image to ensure it's up-to-date
    echo -e "${YELLOW}Ensuring official base image is up-to-date: php:${version}-${variant}${NC}"
    docker pull "php:${version}-${variant}" >/dev/null || true

    docker buildx build \
        --file "$dockerfile" \
        --build-arg PHP_VERSION="$version" \
        $build_contexts \
        --tag "$image_tag" \
        .
    
    echo -e "${GREEN}Final image built successfully: $image_tag${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            PHP_VERSION="$2"
            shift 2
            ;;
        -t|--variant)
            VARIANT="$2"
            shift 2
            ;;
        -m|--mode)
            BUILD_MODE="$2"
            shift 2
            ;;
        -g|--github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$PHP_VERSION" ]; then
    echo -e "${RED}Error: PHP version is required${NC}"
    usage
fi

if [ -z "$VARIANT" ]; then
    echo -e "${RED}Error: Variant is required${NC}"
    usage
fi

if [ -z "$BUILD_MODE" ]; then
    echo -e "${RED}Error: Build mode is required${NC}"
    usage
fi

# Validate variant
validate_variant "$VARIANT"

# Validate build mode
if [[ ! "$BUILD_MODE" =~ ^(base|final|both)$ ]]; then
    echo -e "${RED}Error: Invalid build mode '$BUILD_MODE'. Must be 'base', 'final', or 'both'${NC}"
    exit 1
fi

# Get GitHub token from composer if not provided
if [ -z "$GITHUB_TOKEN" ]; then
    GITHUB_TOKEN=$(get_github_token_from_composer)
fi

# Display configuration
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Build Configuration${NC}"
echo -e "${GREEN}======================================${NC}"
echo "PHP Version:       $PHP_VERSION"
echo "Variant:           $VARIANT"
echo "Build Mode:        $BUILD_MODE"
echo "GitHub Token:      $([ -n "$GITHUB_TOKEN" ] && echo "Provided" || echo "Not provided")"
echo -e "${GREEN}======================================${NC}"
echo ""

# Ensure docker is available
if ! docker version >/dev/null 2>&1; then
    echo -e "${RED}Error: docker is not available${NC}"
    exit 1
fi

# Execute build based on mode
case "$BUILD_MODE" in
    base)
        if needs_base_build "$VARIANT"; then
            build_base_image "$PHP_VERSION" "$VARIANT" "$GITHUB_TOKEN"
        else
            echo -e "${RED}Error: Variant '$VARIANT' does not have a base build${NC}"
            exit 1
        fi
        ;;
    final)
        build_final_image "$PHP_VERSION" "$VARIANT"
        ;;
    both)
        if needs_base_build "$VARIANT"; then
            build_base_image "$PHP_VERSION" "$VARIANT" "$GITHUB_TOKEN"
        else
            # For variants without their own base build, we need the appropriate base variant
            base_variant=$(get_base_variant "$VARIANT")
            echo -e "${YELLOW}Variant '$VARIANT' uses base variant '$base_variant'${NC}"
            echo -e "${YELLOW}Building required prebuild image for '$base_variant'${NC}"
            echo ""
            build_base_image "$PHP_VERSION" "$base_variant" "$GITHUB_TOKEN"
        fi
        build_final_image "$PHP_VERSION" "$VARIANT"
        ;;
esac

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}======================================${NC}"
