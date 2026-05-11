# $HASH GPU Miner — CUDA + Node.js

Headless GPU miner untuk token **$HASH** (`0xAC7b5d06fa1e77D08aea40d46cB7C5923A87A0cc`) di Ethereum mainnet.

Menggunakan **NVIDIA CUDA** untuk brute-force keccak256 PoW dan **ethers.js** untuk submit transaksi on-chain.

## Requirements

- NVIDIA GPU (CUDA-capable)
- CUDA Toolkit (`nvcc`)
- Node.js v18+
- ETH di wallet untuk gas fee

## Setup

### 1. Clone & Install

```bash
git clone https://github.com/USERNAME/hash-miner.git
cd hash-miner
npm install
```

### 2. Install System Dependencies (Ubuntu/Debian)

```bash
apt-get update && apt-get install -y gcc g++ curl make nvidia-cuda-toolkit
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
```

### 3. Compile CUDA Miner

```bash
cd cuda
nvcc -O3 -o miner miner.cu
cd ..
```

> Kalau GPU compute capability berbeda, sesuaikan flag `-arch`:
> - RTX 30xx → `-arch=sm_86`
> - RTX 40xx → `-arch=sm_89`
> - RTX 50xx → `-arch=sm_100` atau tanpa flag

### 4. Konfigurasi

```bash
cp .env.example .env
nano .env
```

Isi file `.env`:

```env
RPC_URL=https://ethereum-public.nodies.app/
PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
MAX_GAS_PRICE_GWEI=15
CUDA_GRID=512
CUDA_BLOCKS=256
CUDA_NPT=128
CUDA_BINARY=./cuda/miner
```

### 5. Test Koneksi

```bash
npm run check
```

Output yang diharapkan:
```
HASH $HASH Mining State Check
i  Current block: 25070692
i  Era: 0 | Reward: 100.0 HASH
i  Difficulty: 1645504...
i  Challenge: 0xa78b37...
```

### 6. Mulai Mining

```bash
# Foreground
npm start

# Background
nohup npm start > mining.log 2>&1 &

# Monitor log
tail -f mining.log
```

## Cara Kerja

```
1. Ambil challenge dari contract: keccak256(chainId, contract, wallet, epoch)
2. GPU brute-force: cari nonce dimana keccak256(challenge | nonce) < target
3. Submit mine(nonce) transaction ke Ethereum
4. Dapat 100 HASH reward (era 0)
5. Ulangi
```

## Tuning CUDA

Sesuaikan parameter di `.env` untuk GPU lu:

| GPU | CUDA_GRID | CUDA_BLOCKS | CUDA_NPT |
|-----|-----------|-------------|----------|
| RTX 3080 | 256 | 256 | 128 |
| RTX 4090 | 1024 | 256 | 256 |
| RTX 5070 | 512 | 256 | 128 |
| RTX 5080 | 1024 | 256 | 256 |
| RTX 5090 | 2048 | 256 | 512 |
| RTX 6000 Ada | 2048 | 256 | 512 |
| A100 | 2048 | 512 | 512 |

## Info Contract

| | |
|---|---|
| **Contract** | `0xAC7b5d06fa1e77D08aea40d46cB7C5923A87A0cc` |
| **Network** | Ethereum Mainnet |
| **Algorithm** | keccak256 PoW |
| **Total Supply** | 21,000,000 HASH |
| **Reward** | 100 HASH/mint (era 0), halving tiap 100k mints |
| **Epoch** | Setiap 100 blocks (~20 menit) |
| **Max mints/block** | 10 |

## ⚠️ Disclaimer

- Pastikan reward HASH > biaya gas sebelum mining
- Gunakan wallet berbeda untuk setiap mesin agar tidak bentrok
- Script ini untuk keperluan edukasi dan personal use
