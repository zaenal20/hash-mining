#!/bin/bash

# ========================================================
# HASH256 CUDA MINER VERIFICATION SCRIPT
# ========================================================
# Script ini akan memaksa miner lu melakukan komputasi 
# pada challenge asli dari Etherscan, dan membuktikan 
# apakah ia bisa menemukan nonce yang valid.

echo "Membangun ulang (compiling) miner..."
cd cuda
# Versi CUDA VPS lu pakai versi lama, jadi kita hilangkan -arch=sm_89 agar otomatis menyesuaikan
nvcc -O3 -o miner miner.cu

if [ $? -ne 0 ]; then
    echo "Gagal compile! Cek pesan error nvcc."
    exit 1
fi

echo -e "\nCompile sukses! Menjalankan verifikasi...\n"

# Challenge asli dari transaksi sukses
CHALLENGE="5bcc23a21849ceebf4885d7580babf6cfbbaec4a66941e36d57a2946ad2ad2b1"

# Hash asli yang ketemu adalah 0x000000000000125b...
# pasang target sedikit di atasnya biar dianggap "sukses" oleh miner lu
TARGET="000000000000125c000000000000000000000000000000000000000000000000"

# Nonce pemenang aslinya adalah berakhiran ...dc65
# mulai pencarian dari ...dc01 (sekitar 100 langkah sebelum menang)
START_NONCE="b3beebac11185eda01b9832e4675e41c430a31e09a32a246000000066140dc01"

# jalankan: 
# - 1 grid
# - 1 block (thread tunggal biar gampang ditrack)
# - 256 nonces per batch (ini lebih dari cukup untuk cover range 0x00 sampai 0xff)
echo "Menjalankan miner..."
echo "Challenge   : $CHALLENGE"
echo "Target      : $TARGET"
echo "Start Nonce : $START_NONCE"
echo "Expected    : FOUND:0xb3beebac11185eda01b9832e4675e41c430a31e09a32a246000000066140dc65"
echo "--------------------------------------------------------"

./miner $CHALLENGE $TARGET $START_NONCE 1 1 256

echo "--------------------------------------------------------"
