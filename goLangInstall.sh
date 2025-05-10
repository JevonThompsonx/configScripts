#!/bin/bash

set -e

# Define Go version (change this to target a specific version if needed)
GO_VERSION=$(curl -s https://go.dev/VERSION?m=text)

# System architecture (supports amd64 and arm64)
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" == "amd64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "arm64" ]]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Download and install
cd /tmp
echo "Downloading Go $GO_VERSION for $ARCH..."
curl -LO https://go.dev/dl/${GO_VERSION}.linux-${ARCH}.tar.gz

echo "Removing any existing Go installation..."
sudo rm -rf /usr/local/go

echo "Extracting Go..."
sudo tar -C /usr/local -xzf ${GO_VERSION}.linux-${ARCH}.tar.gz

# Set up Go environment variables (optional: add to shell profile)
if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' ~/.bashrc; then
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
fi
if ! grep -q 'export GOPATH=$HOME/go' ~/.bashrc; then
  echo 'export GOPATH=$HOME/go' >> ~/.bashrc
  echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
fi

# Apply changes for current session
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Clean up
rm ${GO_VERSION}.linux-${ARCH}.tar.gz

# Verify installation
echo "Go installed successfully:"
go version
