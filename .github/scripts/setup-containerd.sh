#!/bin/bash
# Enhanced containerd.io installation script for GitHub Actions
# Addresses package conflicts and provides fallback installation methods

set -e

# Function to wait for dpkg lock to be released
wait_for_dpkg_lock() {
  echo "=== Waiting for dpkg/apt locks to be released ==="
  local max_wait=300  # 5 minutes max
  local wait_time=0
  
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if [ $wait_time -ge $max_wait ]; then
      echo "❌ Timeout waiting for dpkg locks to be released"
      # Force kill any hanging apt processes
      sudo pkill -f "apt|dpkg" || true
      sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock
      break
    fi
    echo "⏳ Waiting for package manager locks to be released... ($wait_time/${max_wait}s)"
    sleep 10
    wait_time=$((wait_time + 10))
  done
}

# Function to perform system cleanup
cleanup_system() {
  echo "=== Performing system cleanup ==="
  
  # Kill any hanging package manager processes
  sudo pkill -f "unattended-upgrades|packagekit|snapd" || true
  
  # Remove locks if they exist
  sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock
  
  # Stop problematic services temporarily
  sudo systemctl stop snapd || true
  sudo systemctl stop unattended-upgrades || true
  
  # Configure dpkg to be non-interactive
  echo 'APT::Get::Assume-Yes "true";' | sudo tee /etc/apt/apt.conf.d/90-noninteractive
  echo 'DPkg::Options "--force-confdef";' | sudo tee -a /etc/apt/apt.conf.d/90-noninteractive
  echo 'DPkg::Options "--force-confold";' | sudo tee -a /etc/apt/apt.conf.d/90-noninteractive
}

# Initial system preparation
cleanup_system
wait_for_dpkg_lock

# Enhanced diagnosis and package conflict resolution
echo "=== System Diagnosis ==="
echo "OS Info: $(lsb_release -a 2>/dev/null || echo 'N/A')"
echo "Architecture: $(dpkg --print-architecture)"
echo "Available disk space: $(df -h / | tail -1)"

# Show existing container-related packages
echo "=== Existing container packages ==="
dpkg -l | grep -E "(containerd|runc|docker)" || echo "No container packages found"

# Show held packages that might block installation
echo "=== Held packages ==="
apt-mark showhold || echo "No held packages"

# Aggressive removal of conflicting packages with dpkg fallback
echo "=== Removing conflicting packages (Enhanced) ==="

# First, try normal removal
sudo apt-get remove -y runc containerd docker.io docker-doc docker-compose podman-docker docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin || true

# Force remove any remaining packages with dpkg
sudo dpkg --remove --force-depends runc containerd.io docker.io docker-doc docker-compose podman-docker docker-ce docker-ce-cli 2>/dev/null || true

# Clean up broken packages
sudo apt-get install -f -y || true
sudo apt-get autoremove -y
sudo apt-get autoclean

# Remove any package holds that might conflict
sudo apt-mark unhold runc containerd containerd.io docker.io docker-ce docker-ce-cli || true

# Clear any problematic package cache
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/cache/apt/archives/*

# Add Docker's official GPG key and repository for containerd.io
echo "=== Setting up Docker repository (Enhanced) ==="
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common
sudo mkdir -p /etc/apt/keyrings

# Remove any existing Docker GPG keys
sudo rm -f /etc/apt/keyrings/docker.gpg
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker GPG key with enhanced retry logic
for i in {1..5}; do
  if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    echo "✅ Docker GPG key added successfully"
    break
  else
    echo "⚠️  Attempt $i failed to add Docker GPG key, retrying..."
    sudo rm -f /etc/apt/keyrings/docker.gpg
    sleep 10
    if [ $i -eq 5 ]; then
      echo "❌ Failed to add Docker GPG key after 5 attempts"
      echo "Trying alternative GPG key source..."
      # Fallback: try alternative GPG key source
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || exit 1
    fi
  fi
done

sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Remove any existing Docker repository entries
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/sources.list.d/docker.list.save

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package cache with verification
echo "=== Updating package cache ==="
sudo apt-get clean
sudo apt-get update

# Verify Docker repository is accessible
apt-cache policy containerd.io | head -10

# Install containerd.io with enhanced error handling and fallback
echo "=== Installing containerd.io (Enhanced) ==="

# Wait for locks before installation
wait_for_dpkg_lock

# Method 1: Standard installation with specific version pinning
INSTALL_SUCCESS=false
for i in {1..3}; do
  echo "=== Standard installation attempt $i/3 ==="
  
  # Ensure no locks before attempting installation
  wait_for_dpkg_lock
  
  if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends containerd.io; then
    echo "✅ containerd.io installed successfully via standard method"
    INSTALL_SUCCESS=true
    break
  else
    echo "⚠️  Standard installation attempt $i failed"
    # Show specific error details
    echo "=== Diagnostic information for failed attempt ==="
    apt-cache policy containerd.io | head -5
    dpkg -l | grep -E "(containerd|runc)" || echo "No conflicting packages found"
    
    # Clean up and retry
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    wait_for_dpkg_lock
    sudo apt-get update
    sleep 15
    
    if [ $i -eq 3 ]; then
      echo "❌ Standard installation failed after 3 attempts"
      INSTALL_SUCCESS=false
    fi
  fi
done

# Method 2: Fallback - manual installation
if [ "$INSTALL_SUCCESS" != "true" ]; then
  echo "=== Attempting manual containerd.io installation ==="
  
  # Get latest containerd.io package URL
  CONTAINERD_VERSION="1.6.28-1"
  CONTAINERD_DEB_URL="http://archive.ubuntu.com/ubuntu/pool/universe/c/containerd/containerd_${CONTAINERD_VERSION}_amd64.deb"
  
  # Try downloading and installing manually
  if wget -O containerd.deb "$CONTAINERD_DEB_URL" && sudo dpkg -i containerd.deb; then
    echo "✅ containerd.io installed via manual method"
    INSTALL_SUCCESS=true
  else
    echo "❌ Manual installation also failed"
    # Last resort: try from GitHub releases
    echo "=== Trying containerd from GitHub releases ==="
    CONTAINERD_VERSION="1.7.13"
    wget -O containerd.tar.gz "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
    sudo tar -xzf containerd.tar.gz -C /usr/local
    sudo mkdir -p /usr/local/lib/systemd/system/
    wget -O containerd.service "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"
    sudo mv containerd.service /usr/local/lib/systemd/system/
    sudo systemctl enable containerd
    INSTALL_SUCCESS=true
  fi
fi

if [ "$INSTALL_SUCCESS" != "true" ]; then
  echo "❌ All containerd.io installation methods failed"
  echo "=== Final diagnostic information ==="
  apt-cache policy containerd.io || true
  apt-mark showhold || true
  dpkg -l | grep -E "(containerd|runc|docker)" || true
  exit 1
fi

# Configure containerd
echo "=== Configuring containerd ==="
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Start containerd service
echo "=== Starting containerd service ==="
sudo systemctl daemon-reload
sudo systemctl start containerd
sudo systemctl enable containerd

# Wait for containerd socket to be ready
echo "=== Waiting for containerd socket ==="
sudo timeout 30 bash -c 'until [ -S /run/containerd/containerd.sock ]; do sleep 1; done'

# Download and install nerdctl if requested
if [ "${INSTALL_NERDCTL:-true}" = "true" ]; then
  echo "=== Installing nerdctl ==="
  NERDCTL_VERSION="${NERDCTL_VERSION:-1.7.6}"
  curl -sSL "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz" -o nerdctl.tar.gz
  sudo tar -xzf nerdctl.tar.gz -C /usr/local/bin/
  sudo chmod +x /usr/local/bin/nerdctl
  rm nerdctl.tar.gz
  
  # Verify nerdctl installation
  echo "=== Verifying nerdctl installation ==="
  sudo nerdctl version
  sudo nerdctl info
fi

# Install buildkit if requested
if [ "${INSTALL_BUILDKIT:-false}" = "true" ]; then
  echo "=== Installing buildkit ==="
  curl -sSL "https://github.com/moby/buildkit/releases/download/v0.12.5/buildkit-v0.12.5.linux-amd64.tar.gz" -o buildkit.tar.gz
  sudo tar -xzf buildkit.tar.gz -C /usr/local/
  sudo chmod +x /usr/local/bin/buildctl /usr/local/bin/buildkitd
  rm buildkit.tar.gz
  
  # Start buildkitd daemon in background for advanced build features
  echo "=== Starting buildkitd daemon ==="
  sudo mkdir -p /run/buildkit
  sudo nohup /usr/local/bin/buildkitd \
    --addr unix:///run/buildkit/buildkitd.sock \
    --group $(id -gn) \
    --containerd-worker \
    --containerd-worker-addr /run/containerd/containerd.sock \
    > /var/log/buildkitd.log 2>&1 &
  
  # Wait for buildkit socket to be ready
  echo "=== Waiting for buildkit socket ==="
  sudo timeout 30 bash -c 'until [ -S /run/buildkit/buildkitd.sock ]; do sleep 1; done'
  sudo chmod 666 /run/buildkit/buildkitd.sock
  
  # Verify buildkit installation
  echo "=== Buildkit Status ==="
  export BUILDKIT_HOST=unix:///run/buildkit/buildkitd.sock
  buildctl debug info || echo "buildctl not ready yet, continuing..."
fi

# Final verification
echo "=== Final Verification ==="
echo "Containerd Status:"
sudo systemctl status containerd --no-pager || true
containerd --version
sudo systemctl is-active --quiet containerd || { echo "ERROR: containerd is not running"; exit 1; }

if [ "${INSTALL_NERDCTL:-true}" = "true" ]; then
  echo "=== Testing nerdctl functionality ==="
  sudo nerdctl system info >/dev/null || { echo "ERROR: nerdctl cannot communicate with containerd"; exit 1; }
  
  # Test basic image operations
  echo "=== Testing basic image operations ==="
  sudo nerdctl pull hello-world:latest || { echo "ERROR: Cannot pull images with nerdctl"; exit 1; }
  sudo nerdctl images hello-world || true
  sudo nerdctl rmi hello-world:latest || true
fi

echo "=== Setup Complete and Verified ==="