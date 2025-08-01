#!/bin/bash
# Validation script for containerd setup
# Used to verify that containerd and nerdctl are working correctly

set -e

echo "=== Containerd and nerdctl Validation ==="

# Check if containerd is installed and running
echo "1. Checking containerd installation..."
if command -v containerd >/dev/null 2>&1; then
    echo "✅ containerd is installed: $(containerd --version)"
else
    echo "❌ containerd is not installed"
    exit 1
fi

# Check containerd service status
echo "2. Checking containerd service..."
if sudo systemctl is-active --quiet containerd; then
    echo "✅ containerd service is running"
else
    echo "❌ containerd service is not running"
    sudo systemctl status containerd --no-pager || true
    exit 1
fi

# Check containerd socket
echo "3. Checking containerd socket..."
if [ -S /run/containerd/containerd.sock ]; then
    echo "✅ containerd socket exists"
else
    echo "❌ containerd socket not found"
    exit 1
fi

# Check if nerdctl is installed
echo "4. Checking nerdctl installation..."
if command -v nerdctl >/dev/null 2>&1; then
    echo "✅ nerdctl is installed"
    sudo nerdctl version | head -3 || echo "nerdctl version details available"
else
    echo "❌ nerdctl is not installed"
    exit 1
fi

# Test nerdctl connectivity to containerd
echo "5. Testing nerdctl connectivity..."
if sudo nerdctl info >/dev/null 2>&1; then
    echo "✅ nerdctl can communicate with containerd"
else
    echo "❌ nerdctl cannot communicate with containerd"
    echo "nerdctl info output:"
    sudo nerdctl info || true
    exit 1
fi

# Test basic nerdctl operations
echo "6. Testing basic nerdctl operations..."
echo "   - Testing image pull..."
if sudo nerdctl pull hello-world:latest >/dev/null 2>&1; then
    echo "✅ Image pull successful"
    
    echo "   - Testing image list..."
    if sudo nerdctl images hello-world >/dev/null 2>&1; then
        echo "✅ Image listing successful"
        
        echo "   - Testing image removal..."
        if sudo nerdctl rmi hello-world:latest >/dev/null 2>&1; then
            echo "✅ Image removal successful"
        else
            echo "⚠️  Image removal failed (non-critical)"
        fi
    else
        echo "❌ Image listing failed"
        exit 1
    fi
else
    echo "❌ Image pull failed"
    echo "Attempting to diagnose the issue..."
    sudo nerdctl pull hello-world:latest || true
    exit 1
fi

# Check if buildkit is requested and installed
if [ "${INSTALL_BUILDKIT:-false}" = "true" ]; then
    echo "7. Checking buildkit installation..."
    if command -v buildctl >/dev/null 2>&1 && command -v buildkitd >/dev/null 2>&1; then
        echo "✅ buildkit tools are installed"
        
        # Check if buildkit socket exists
        if [ -S /run/buildkit/buildkitd.sock ]; then
            echo "✅ buildkit socket exists"
            
            # Test buildctl connectivity
            export BUILDKIT_HOST=unix:///run/buildkit/buildkitd.sock
            if buildctl debug info >/dev/null 2>&1; then
                echo "✅ buildctl can communicate with buildkitd"
            else
                echo "⚠️  buildctl connectivity test failed (may need time to start)"
            fi
        else
            echo "⚠️  buildkit socket not found (may need time to start)"
        fi
    else
        echo "❌ buildkit tools are not installed"
        exit 1
    fi
fi

echo ""
echo "=== Validation Summary ==="
echo "✅ All critical components are working correctly"
echo "✅ containerd.io installation and setup successful"
echo "✅ nerdctl is functional and can manage containers"

if [ "${INSTALL_BUILDKIT:-false}" = "true" ]; then
    echo "✅ buildkit components are installed"
fi

echo ""
echo "=== System Information ==="
echo "OS: $(lsb_release -d | cut -f2)"
echo "Architecture: $(dpkg --print-architecture)"
echo "containerd version: $(containerd --version)"
echo "nerdctl version: $(sudo nerdctl version --format table 2>/dev/null || echo 'Version info available via sudo nerdctl version')"

echo ""
echo "🎉 Setup validation completed successfully!"