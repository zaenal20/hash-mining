#!/bin/bash
echo "Building CUDA miner..."
nvcc -O3 -arch=sm_89 -o miner miner.cu
if [ $? -eq 0 ]; then
    echo "Build successful: ./cuda/miner"
else
    echo "Build failed!"
    exit 1
fi
