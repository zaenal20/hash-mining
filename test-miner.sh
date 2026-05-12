#!/bin/bash

# ========================================================
# HASH256 CUDA MINER VERIFICATION SCRIPT
# ========================================================
# Script ini akan memaksa miner lu melakukan komputasi 
# pada challenge asli dari Etherscan, dan membuktikan 
# apakah ia bisa menemukan nonce yang valid.

echo "Membangun ulang (compiling) miner..."
nvcc -O3 -arch=sm_89 -o cuda/miner cuda/miner.cu

if [ $? -ne 0 ]; then
    echo "Gagal compile! Cek pesan error nvcc."
    exit 1
fi

echo -e "\nCompile sukses! Menjalankan verifikasi...\n"

# Challenge asli dari transaksi sukses
CHALLENGE="e2bc94782f473999e5d0e107cc2e54848c172f8a5704cff9558e55d8d77e1992"

# Hash asli yang ketemu adalah 0x000000000000011c...
# Kita pasang target sedikit di atasnya biar dianggap "sukses" oleh miner lu
TARGET="000000000000011d000000000000000000000000000000000000000000000000"

# Nonce pemenang aslinya adalah berakhiran ...182a1 (a1 hex = 161 decimal)
# Kita mulai pencarian dari ...18200 (161 langkah sebelum menang)
START_NONCE="65d3947577da48e4d964a370ee4cbec46dcf460dc89373460000059f6af18200"

# Kita jalankan: 
# - 1 grid
# - 1 block (thread tunggal biar gampang ditrack)
# - 256 nonces per batch (ini lebih dari cukup untuk cover range 0x00 sampai 0xff)
echo "Menjalankan miner..."
echo "Challenge   : $CHALLENGE"
echo "Target      : $TARGET"
echo "Start Nonce : $START_NONCE"
echo "Harapan     : Miner harus nge-print FOUND:0x65d3947577da48e4d964a370ee4cbec46dcf460dc89373460000059f6af182a1"
echo "--------------------------------------------------------"

./cuda/miner $CHALLENGE $TARGET $START_NONCE 1 1 256

echo "--------------------------------------------------------"
echo "Jika tulisan FOUND di atas ekornya sama persis (...182a1),"
echo "maka algoritma endianness, padding, state-loop, dsb SUDAH 100% PERFECT!"
