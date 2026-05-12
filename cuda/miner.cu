#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <ctime>

// ==================== KECCAK-256 CUDA IMPLEMENTATION ====================

__constant__ uint64_t d_challenge[4];
__constant__ uint64_t d_target[4];

__device__ __forceinline__ uint64_t rotl64(uint64_t x, int n) {
    return (x << n) | (x >> (64 - n));
}

__device__ __forceinline__ uint64_t bswap64(uint64_t x) {
    x = ((x & 0x00000000FFFFFFFFULL) << 32) | ((x & 0xFFFFFFFF00000000ULL) >> 32);
    x = ((x & 0x0000FFFF0000FFFFULL) << 16) | ((x & 0xFFFF0000FFFF0000ULL) >> 16);
    x = ((x & 0x00FF00FF00FF00FFULL) << 8)  | ((x & 0xFF00FF00FF00FF00ULL) >> 8);
    return x;
}

static __constant__ uint64_t RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808AULL, 0x8000000080008000ULL,
    0x000000000000808BULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008AULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000AULL,
    0x000000008000808BULL, 0x800000000000008BULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800AULL, 0x800000008000000AULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

__device__ void keccak_f1600(uint64_t *state) {
    uint64_t C[5], D[5], B[25];

    for (int round = 0; round < 24; round++) {
        // Theta
        C[0] = state[0] ^ state[5] ^ state[10] ^ state[15] ^ state[20];
        C[1] = state[1] ^ state[6] ^ state[11] ^ state[16] ^ state[21];
        C[2] = state[2] ^ state[7] ^ state[12] ^ state[17] ^ state[22];
        C[3] = state[3] ^ state[8] ^ state[13] ^ state[18] ^ state[23];
        C[4] = state[4] ^ state[9] ^ state[14] ^ state[19] ^ state[24];

        D[0] = C[4] ^ rotl64(C[1], 1);
        D[1] = C[0] ^ rotl64(C[2], 1);
        D[2] = C[1] ^ rotl64(C[3], 1);
        D[3] = C[2] ^ rotl64(C[4], 1);
        D[4] = C[3] ^ rotl64(C[0], 1);

        state[0]  ^= D[0]; state[5]  ^= D[0]; state[10] ^= D[0]; state[15] ^= D[0]; state[20] ^= D[0];
        state[1]  ^= D[1]; state[6]  ^= D[1]; state[11] ^= D[1]; state[16] ^= D[1]; state[21] ^= D[1];
        state[2]  ^= D[2]; state[7]  ^= D[2]; state[12] ^= D[2]; state[17] ^= D[2]; state[22] ^= D[2];
        state[3]  ^= D[3]; state[8]  ^= D[3]; state[13] ^= D[3]; state[18] ^= D[3]; state[23] ^= D[3];
        state[4]  ^= D[4]; state[9]  ^= D[4]; state[14] ^= D[4]; state[19] ^= D[4]; state[24] ^= D[4];

        // Rho + Pi
        B[0]  = state[0];
        B[1]  = rotl64(state[6],  44);
        B[2]  = rotl64(state[12], 43);
        B[3]  = rotl64(state[18], 21);
        B[4]  = rotl64(state[24], 14);
        B[5]  = rotl64(state[3],  28);
        B[6]  = rotl64(state[9],  20);
        B[7]  = rotl64(state[10],  3);
        B[8]  = rotl64(state[16], 45);
        B[9]  = rotl64(state[22], 61);
        B[10] = rotl64(state[1],   1);
        B[11] = rotl64(state[7],   6);
        B[12] = rotl64(state[13], 25);
        B[13] = rotl64(state[19],  8);
        B[14] = rotl64(state[20], 18);
        B[15] = rotl64(state[4],  27);
        B[16] = rotl64(state[5],  36);
        B[17] = rotl64(state[11], 10);
        B[18] = rotl64(state[17], 15);
        B[19] = rotl64(state[23], 56);
        B[20] = rotl64(state[2],  62);
        B[21] = rotl64(state[8],  55);
        B[22] = rotl64(state[14], 39);
        B[23] = rotl64(state[15], 41);
        B[24] = rotl64(state[21],  2);

        // Chi
        state[0]  = B[0]  ^ ((~B[1])  & B[2]);
        state[1]  = B[1]  ^ ((~B[2])  & B[3]);
        state[2]  = B[2]  ^ ((~B[3])  & B[4]);
        state[3]  = B[3]  ^ ((~B[4])  & B[0]);
        state[4]  = B[4]  ^ ((~B[0])  & B[1]);
        state[5]  = B[5]  ^ ((~B[6])  & B[7]);
        state[6]  = B[6]  ^ ((~B[7])  & B[8]);
        state[7]  = B[7]  ^ ((~B[8])  & B[9]);
        state[8]  = B[8]  ^ ((~B[9])  & B[5]);
        state[9]  = B[9]  ^ ((~B[5])  & B[6]);
        state[10] = B[10] ^ ((~B[11]) & B[12]);
        state[11] = B[11] ^ ((~B[12]) & B[13]);
        state[12] = B[12] ^ ((~B[13]) & B[14]);
        state[13] = B[13] ^ ((~B[14]) & B[10]);
        state[14] = B[14] ^ ((~B[10]) & B[11]);
        state[15] = B[15] ^ ((~B[16]) & B[17]);
        state[16] = B[16] ^ ((~B[17]) & B[18]);
        state[17] = B[17] ^ ((~B[18]) & B[19]);
        state[18] = B[18] ^ ((~B[19]) & B[15]);
        state[19] = B[19] ^ ((~B[15]) & B[16]);
        state[20] = B[20] ^ ((~B[21]) & B[22]);
        state[21] = B[21] ^ ((~B[22]) & B[23]);
        state[22] = B[22] ^ ((~B[23]) & B[24]);
        state[23] = B[23] ^ ((~B[24]) & B[20]);
        state[24] = B[24] ^ ((~B[20]) & B[21]);

        // Iota
        state[0] ^= RC[round];
    }
}

// ==================== MINING KERNEL ====================

__global__ void mine_kernel(
    uint64_t n0, uint64_t n1, uint64_t n2, uint64_t n3,
    uint64_t *result_nonce,
    uint32_t *found,
    uint32_t nonces_per_thread
) {
    uint64_t tid = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    uint64_t base_nonce_low = n3 + tid * nonces_per_thread;

    for (uint32_t i = 0; i < nonces_per_thread; i++) {
        if (*found) return;

        uint64_t nonce_low = base_nonce_low + i;

        // Initialize state to zero
        uint64_t state[25];
        uint64_t h0, h1, h2, h3;
        #pragma unroll
        for (int j = 0; j < 25; j++) state[j] = 0;

        // Absorb challenge (bytes 0-31) -> state[0..3] as LE uint64
        state[0] = d_challenge[0];
        state[1] = d_challenge[1];
        state[2] = d_challenge[2];
        state[3] = d_challenge[3];

        state[4] = bswap64(n0);
        state[5] = bswap64(n1);
        state[6] = bswap64(n2);
        state[7] = bswap64(nonce_low);
        state[8] = 0x01ULL;
        state[16] = 0x8000000000000000ULL;

        keccak_f1600(state);

        h0 = bswap64(state[0]);
        if (h0 > d_target[0]) continue;
        if (h0 < d_target[0]) goto found_solution;

        h1 = bswap64(state[1]);
        if (h1 > d_target[1]) continue;
        if (h1 < d_target[1]) goto found_solution;

        h2 = bswap64(state[2]);
        if (h2 > d_target[2]) continue;
        if (h2 < d_target[2]) goto found_solution;

        h3 = bswap64(state[3]);
        if (h3 >= d_target[3]) continue;

        found_solution:
        if (atomicCAS(found, 0u, 1u) == 0u) {
            result_nonce[0] = n0;
            result_nonce[1] = n1;
            result_nonce[2] = n2;
            result_nonce[3] = nonce_low;
        }
        return;
    }
}

// ==================== HOST CODE ====================

void hex_to_bytes(const char *hex, uint8_t *bytes, int len) {
    for (int i = 0; i < len; i++) {
        sscanf(hex + 2 * i, "%2hhx", &bytes[i]);
    }
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "Usage: %s <challenge_hex_64> <target_hex_64> <start_nonce_hex_64> [grid_size] [block_size] [nonces_per_thread]\n", argv[0]);
        return 1;
    }

    const char *challenge_hex = argv[1];
    const char *target_hex = argv[2];
    const char *start_nonce_hex = argv[3];
    int grid_size = argc > 4 ? atoi(argv[4]) : 512;
    int block_size = argc > 5 ? atoi(argv[5]) : 256;
    uint32_t nonces_per_thread = argc > 6 ? (uint32_t)atoi(argv[6]) : 128;

    // Parse start_nonce -> 4 x uint64 BE
    uint8_t nonce_bytes[32];
    // Pad or read 32 bytes from hex string (which may be shorter or exactly 64 chars)
    memset(nonce_bytes, 0, 32);
    int hex_len = strlen(start_nonce_hex);
    if (hex_len > 64) hex_len = 64;
    int offset = 64 - hex_len; // right align
    for (int i = 0; i < hex_len; i += 2) {
        int byte_idx = (offset + i) / 2;
        char byte_str[3] = { start_nonce_hex[i], start_nonce_hex[i+1], 0 };
        if (i + 1 >= hex_len) {
            byte_str[0] = '0';
            byte_str[1] = start_nonce_hex[i];
        }
        nonce_bytes[byte_idx] = (uint8_t)strtoul(byte_str, NULL, 16);
    }
    uint64_t h_nonce[4];
    for (int i = 0; i < 4; i++) {
        h_nonce[i] = 0;
        for (int j = 0; j < 8; j++) {
            h_nonce[i] = (h_nonce[i] << 8) | nonce_bytes[i * 8 + j];
        }
    }

    // Parse challenge -> 4 x uint64 LE
    uint8_t challenge_bytes[32];
    hex_to_bytes(challenge_hex, challenge_bytes, 32);
    uint64_t h_challenge[4];
    for (int i = 0; i < 4; i++) {
        h_challenge[i] = 0;
        for (int j = 0; j < 8; j++) {
            h_challenge[i] |= (uint64_t)challenge_bytes[i * 8 + j] << (j * 8);
        }
    }

    // Parse target -> 4 x uint64 BE (for comparison)
    uint8_t target_bytes[32];
    hex_to_bytes(target_hex, target_bytes, 32);
    uint64_t h_target[4];
    for (int i = 0; i < 4; i++) {
        h_target[i] = 0;
        for (int j = 0; j < 8; j++) {
            h_target[i] = (h_target[i] << 8) | target_bytes[i * 8 + j];
        }
    }

    // Copy to constant memory
    cudaMemcpyToSymbol(d_challenge, h_challenge, sizeof(h_challenge));
    cudaMemcpyToSymbol(d_target, h_target, sizeof(h_target));

    // Allocate device memory
    uint64_t *d_result_nonce;
    uint32_t *d_found;
    cudaMalloc(&d_result_nonce, 4 * sizeof(uint64_t));
    cudaMalloc(&d_found, sizeof(uint32_t));

    uint64_t total_threads = (uint64_t)grid_size * block_size;
    uint64_t nonces_per_batch = total_threads * nonces_per_thread;
    uint64_t total_hashes = 0;

    fprintf(stderr, "HASH GPU Miner started\n");
    fprintf(stderr, "GPU Grid: %d blocks x %d threads = %llu threads\n", grid_size, block_size, (unsigned long long)total_threads);
    fprintf(stderr, "Nonces per batch: %llu\n", (unsigned long long)nonces_per_batch);
    fprintf(stderr, "Challenge: %s\n", challenge_hex);
    fprintf(stderr, "Target: %s\n", target_hex);
    fprintf(stderr, "Base Nonce: %016llx%016llx%016llx%016llx\n", 
            (unsigned long long)h_nonce[0], (unsigned long long)h_nonce[1], 
            (unsigned long long)h_nonce[2], (unsigned long long)h_nonce[3]);
    fflush(stderr);

    struct timespec ts_start, ts_now;
    clock_gettime(CLOCK_MONOTONIC, &ts_start);
    struct timespec ts_last_report = ts_start;

    while (1) {
        // Reset found flag
        uint32_t zero = 0;
        cudaMemcpy(d_found, &zero, sizeof(uint32_t), cudaMemcpyHostToDevice);

        // Launch kernel
        mine_kernel<<<grid_size, block_size>>>(h_nonce[0], h_nonce[1], h_nonce[2], h_nonce[3], d_result_nonce, d_found, nonces_per_thread);
        cudaDeviceSynchronize();

        // Check for errors
        cudaError_t err = cudaGetLastError();
        if (err != cudaSuccess) {
            fprintf(stderr, "CUDA error: %s\n", cudaGetErrorString(err));
            return 1;
        }

        // Check if found
        uint32_t h_found;
        cudaMemcpy(&h_found, d_found, sizeof(uint32_t), cudaMemcpyDeviceToHost);

        total_hashes += nonces_per_batch;

        if (h_found) {
            uint64_t result[4];
            cudaMemcpy(result, d_result_nonce, 4 * sizeof(uint64_t), cudaMemcpyDeviceToHost);
            // Output to stdout for Node.js to read
            printf("FOUND:0x%016llx%016llx%016llx%016llx\n", 
                (unsigned long long)result[0], (unsigned long long)result[1], 
                (unsigned long long)result[2], (unsigned long long)result[3]);
            fflush(stdout);
            break;
        }

        // Report hash rate every ~2 seconds
        clock_gettime(CLOCK_MONOTONIC, &ts_now);
        double elapsed = (ts_now.tv_sec - ts_last_report.tv_sec) + (ts_now.tv_nsec - ts_last_report.tv_nsec) / 1e9;
        if (elapsed >= 2.0) {
            double total_elapsed = (ts_now.tv_sec - ts_start.tv_sec) + (ts_now.tv_nsec - ts_start.tv_nsec) / 1e9;
            double hashrate = total_hashes / total_elapsed;
            fprintf(stderr, "Hashrate: %.2f MH/s | Total: %llu\n",
                    hashrate / 1e6, (unsigned long long)total_hashes);
            fflush(stderr);
            ts_last_report = ts_now;
        }

        h_nonce[3] += nonces_per_batch;

        // Check for stdin signal to stop (non-blocking)
        // The Node.js parent will kill the process on epoch change
    }

    cudaFree(d_result_nonce);
    cudaFree(d_found);

    return 0;
}
