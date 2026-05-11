#!/bin/bash
set -e

echo "══════════════════════════════════════"
echo "  \$HASH GPU Miner — Container Setup"
echo "══════════════════════════════════════"

# Install system dependencies
echo "[1/5] Installing system packages..."
apt-get update -qq
apt-get install -y -qq curl wget gcc g++ make > /dev/null 2>&1
echo "  ✓ System packages installed"

# Install CUDA toolkit
echo "[2/5] Installing CUDA toolkit..."
if command -v nvcc &> /dev/null; then
    echo "  ✓ nvcc already installed: $(nvcc --version | grep release)"
else
    # Install CUDA toolkit via apt
    apt-get install -y -qq nvidia-cuda-toolkit > /dev/null 2>&1 || {
        echo "  Trying alternative CUDA install..."
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
        dpkg -i cuda-keyring_1.1-1_all.deb > /dev/null 2>&1
        apt-get update -qq
        apt-get install -y -qq cuda-toolkit-12-8 > /dev/null 2>&1
        rm -f cuda-keyring_1.1-1_all.deb
        export PATH=/usr/local/cuda/bin:$PATH
    }
    echo "  ✓ CUDA toolkit installed"
fi

# Install Node.js
echo "[3/5] Installing Node.js..."
if command -v node &> /dev/null; then
    echo "  ✓ Node.js already installed: $(node --version)"
else
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
    echo "  ✓ Node.js installed: $(node --version)"
fi

# Install npm dependencies
echo "[4/5] Installing npm dependencies..."
npm install --quiet 2>&1 | tail -1
echo "  ✓ npm dependencies installed"

# Build CUDA miner
echo "[5/5] Building CUDA miner..."
cd cuda

# Detect GPU compute capability
GPU_ARCH="sm_89"  # Default for RTX 5070
echo "  Using GPU architecture: $GPU_ARCH"

chmod +x build.sh

# Try to build
nvcc -O3 -arch=$GPU_ARCH -o miner miner.cu 2>&1 && {
    echo "  ✓ CUDA miner built successfully"
} || {
    echo "  ⚠ Build with $GPU_ARCH failed, trying sm_80..."
    nvcc -O3 -arch=sm_80 -o miner miner.cu 2>&1 && {
        echo "  ✓ CUDA miner built with sm_80"
    } || {
        echo "  ⚠ Trying without arch flag..."
        nvcc -O3 -o miner miner.cu 2>&1
        echo "  ✓ CUDA miner built with default arch"
    }
}

cd ..

echo ""
echo "══════════════════════════════════════"
echo "  Setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Copy .env.example to .env"
echo "     cp .env.example .env"
echo "  2. Edit .env and add your PRIVATE_KEY"
echo "     nano .env"
echo "  3. Test contract connection:"
echo "     npm run check"
echo "  4. Start mining:"
echo "     npm start"
echo "══════════════════════════════════════"
