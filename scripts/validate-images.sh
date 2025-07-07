#!/bin/bash
set -e

# Script to validate Docker images in manifest.json are still available in the registry
# Uses crane tool (from go-containerregistry) for efficient manifest inspection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_FILE="$REPO_ROOT/manifest.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if manifest.json exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "${RED}Error: manifest.json not found at $MANIFEST_FILE${NC}"
    exit 1
fi

# Dry run mode for testing
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    shift
fi

# Check if crane is installed
if ! command -v crane &> /dev/null && [ "$DRY_RUN" != "true" ]; then
    echo -e "${YELLOW}Warning: 'crane' command not found. Installing...${NC}"
    
    # Install crane based on OS
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    case "$OS" in
        Linux*)
            case "$ARCH" in
                x86_64) CRANE_ARCH="x86_64" ;;
                aarch64|arm64) CRANE_ARCH="arm64" ;;
                *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            CRANE_URL="https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_${CRANE_ARCH}.tar.gz"
            ;;
        Darwin*)
            case "$ARCH" in
                x86_64) CRANE_ARCH="x86_64" ;;
                arm64) CRANE_ARCH="arm64" ;;
                *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            CRANE_URL="https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Darwin_${CRANE_ARCH}.tar.gz"
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    # Download and install crane
    TEMP_DIR=$(mktemp -d)
    curl -sL "$CRANE_URL" | tar -xz -C "$TEMP_DIR"
    sudo mv "$TEMP_DIR/crane" /usr/local/bin/
    rm -rf "$TEMP_DIR"
    
    if ! command -v crane &> /dev/null; then
        echo -e "${RED}Failed to install crane${NC}"
        exit 1
    fi
    echo -e "${GREEN}crane installed successfully${NC}"
fi

# Function to check if an image exists
check_image() {
    local repo="$1"
    local digest="$2"
    
    # Dry run mode - simulate some missing images for testing
    if [ "$DRY_RUN" = "true" ]; then
        # Simulate that version 5.0.4 is missing
        if [[ "$repo" == *":5.0.4" ]]; then
            return 1
        fi
        # All other images exist
        return 0
    fi
    
    # Try to fetch the manifest using the digest
    if crane manifest "${repo}@${digest}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Parse manifest.json and check each image
echo "Validating Docker images from manifest.json..."
echo "================================================"

# Extract all image entries and check them
missing_images=()
checked_count=0
total_count=$(jq -r '.cassandra.docker | to_entries | length' "$MANIFEST_FILE")

# Iterate through all versions
jq -r '.cassandra.docker | to_entries[] | "\(.key)|\(.value.repo)|\(.value.digest)"' "$MANIFEST_FILE" | while IFS='|' read -r version repo digest; do
    checked_count=$((checked_count + 1))
    printf "[%3d/%3d] Checking %s... " "$checked_count" "$total_count" "$version"
    
    if check_image "$repo" "$digest"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ MISSING${NC}"
        missing_images+=("$version|$repo|$digest")
    fi
done | tee /tmp/validation_output.txt

# Count missing images from the output
missing_count=$(grep -c "MISSING" /tmp/validation_output.txt || true)
rm -f /tmp/validation_output.txt

# Summary
echo "================================================"
echo "Validation Summary:"
echo "  Total images: $total_count"
echo "  Available: $((total_count - missing_count))"
echo "  Missing: $missing_count"

# If there are missing images, list them and exit with error
if [ "$missing_count" -gt 0 ]; then
    echo ""
    echo -e "${RED}Missing images detected!${NC}"
    echo "The following images are no longer available in the registry:"
    
    # Re-run to get the missing images list
    jq -r '.cassandra.docker | to_entries[] | "\(.key)|\(.value.repo)|\(.value.digest)"' "$MANIFEST_FILE" | while IFS='|' read -r version repo digest; do
        if ! check_image "$repo" "$digest" 2>/dev/null; then
            echo "  - Version: $version"
            echo "    Repo: $repo"
            echo "    Digest: $digest"
            echo ""
        fi
    done
    
    echo "To rebuild missing images:"
    echo "  1. Remove the entries from manifest.json"
    echo "  2. Run the build workflow"
    echo ""
    echo "Or use the --fix option to automatically remove missing entries:"
    echo "  $0 --fix"
    
    # Handle --fix option
    if [ "${1:-}" = "--fix" ]; then
        echo ""
        echo "Fixing manifest.json by removing missing images..."
        
        # Create a backup
        cp "$MANIFEST_FILE" "${MANIFEST_FILE}.backup"
        echo "Backup created: ${MANIFEST_FILE}.backup"
        
        # Remove missing images from manifest
        temp_file=$(mktemp)
        jq_filter='.cassandra.docker'
        
        jq -r '.cassandra.docker | to_entries[] | "\(.key)|\(.value.repo)|\(.value.digest)"' "$MANIFEST_FILE" | while IFS='|' read -r version repo digest; do
            if check_image "$repo" "$digest" 2>/dev/null; then
                :  # Image exists, keep it
            else
                echo "Removing $version from manifest..."
                jq_filter="$jq_filter | del(.\"$version\")"
            fi
        done
        
        # Apply the filter
        jq ".cassandra.docker = ($jq_filter)" "$MANIFEST_FILE" > "$temp_file"
        mv "$temp_file" "$MANIFEST_FILE"
        
        echo -e "${GREEN}manifest.json has been updated${NC}"
        echo "Removed $missing_count missing image entries"
    fi
    
    exit 1
else
    echo -e "${GREEN}All images are available in the registry!${NC}"
    exit 0
fi