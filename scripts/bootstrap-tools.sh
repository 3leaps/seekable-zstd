#!/bin/bash
set -e

# Configuration
TOOLS_FILE=".goneat/tools.yaml"
BIN_DIR="./bin"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture names
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
fi

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

echo "Bootstrapping tools for $OS/$ARCH..."

# Function to extract value from simple yaml (dependency-free)
get_tool_config() {
    local id=$1
    local key=$2
    # Simple grep/awk parsing for the specific structure we know exists
    # This is not a full YAML parser but sufficient for this bootstrap script
    grep -A 20 "\- id: $id" "$TOOLS_FILE" | grep "$key:" | head -n1 | awk '{print $2}' | tr -d '"'
}

# Install goneat
echo "Installing goneat..."
VERSION="v0.3.8"
URL="https://github.com/fulmenhq/goneat/releases/download/$VERSION/goneat_${VERSION}_${OS}_${ARCH}.tar.gz"

# Checksum verification would go here but skipping for simplicity in bash script
# relying on https and github releases

echo "Downloading from $URL..."
curl -L -o "$BIN_DIR/goneat.tar.gz" "$URL"

echo "Extracting..."
tar -xzf "$BIN_DIR/goneat.tar.gz" -C "$BIN_DIR"

# Cleanup
rm "$BIN_DIR/goneat.tar.gz"
if [ -f "$BIN_DIR/goneat_$VERSION_${OS}_${ARCH}" ]; then
    mv "$BIN_DIR/goneat_$VERSION_${OS}_${ARCH}" "$BIN_DIR/goneat"
fi
chmod +x "$BIN_DIR/goneat"

echo "Successfully installed goneat to $BIN_DIR/goneat"
"$BIN_DIR/goneat" version
