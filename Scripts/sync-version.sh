#!/bin/bash

# sync-version.sh - Sync version between git tag and source code
# Usage: ./sync-version.sh [version]
# If no version is provided, it will use the latest git tag

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version from argument or git tag
if [ -n "$1" ]; then
    VERSION="$1"
    echo -e "${YELLOW}Using provided version: $VERSION${NC}"
else
    # Get latest tag
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -z "$LATEST_TAG" ]; then
        echo -e "${RED}No git tags found and no version provided${NC}"
        exit 1
    fi
    # Remove 'v' prefix if present
    VERSION="${LATEST_TAG#v}"
    echo -e "${YELLOW}Using version from latest tag: $VERSION${NC}"
fi

# Validate version format (basic semver)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
    echo -e "${RED}Invalid version format: $VERSION${NC}"
    echo "Expected format: X.Y.Z or X.Y.Z-suffix"
    exit 1
fi

# Get current date
BUILD_DATE=$(date +%Y-%m-%d)

# Update OpenFoundationModelsOpenAI.swift
SWIFT_FILE="Sources/OpenFoundationModelsOpenAI/OpenFoundationModelsOpenAI.swift"
if [ -f "$SWIFT_FILE" ]; then
    echo "Updating $SWIFT_FILE..."
    
    # Update version
    sed -i.bak "s/public static let version = \".*\"/public static let version = \"$VERSION\"/" "$SWIFT_FILE"
    
    # Update build date
    sed -i.bak "s/public static let buildDate = \".*\"/public static let buildDate = \"$BUILD_DATE\"/" "$SWIFT_FILE"
    
    # Remove backup file
    rm -f "$SWIFT_FILE.bak"
    
    echo -e "${GREEN}✓ Updated version to $VERSION${NC}"
    echo -e "${GREEN}✓ Updated build date to $BUILD_DATE${NC}"
else
    echo -e "${RED}Error: $SWIFT_FILE not found${NC}"
    exit 1
fi

# Optional: Update Package.swift if it contains version
if [ -f "Package.swift" ] && grep -q 'let version = "' Package.swift; then
    echo "Updating Package.swift..."
    sed -i.bak "s/let version = \".*\"/let version = \"$VERSION\"/" Package.swift
    rm -f Package.swift.bak
    echo -e "${GREEN}✓ Updated Package.swift${NC}"
fi

# Show diff
echo -e "\n${YELLOW}Changes made:${NC}"
git diff --color

# Offer to commit changes
echo -e "\n${YELLOW}Do you want to commit these changes? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    git add -A
    git commit -m "chore: sync version to $VERSION"
    echo -e "${GREEN}✓ Changes committed${NC}"
    
    # Offer to create tag if not already exists
    if ! git rev-parse "v$VERSION" >/dev/null 2>&1; then
        echo -e "\n${YELLOW}Do you want to create tag v$VERSION? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            git tag -a "v$VERSION" -m "Release version $VERSION"
            echo -e "${GREEN}✓ Tag v$VERSION created${NC}"
            echo -e "${YELLOW}Remember to push the tag: git push origin v$VERSION${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Changes not committed${NC}"
fi

echo -e "\n${GREEN}Version sync complete!${NC}"