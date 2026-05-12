require('dotenv').config();
const { ethers } = require('ethers');
const path = require('path');
const { HashContract } = require('./contract');
const { MinerBridge } = require('./miner-bridge');
const { log } = require('./logger');

// ==================== CONFIG ====================
const RPC_URL = process.env.RPC_URL || 'https://ethereum-public.nodies.app/';
const TX_RPC_URL = process.env.TX_RPC_URL; // Private RPC like Flashbots
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const MAX_GAS_PRICE_GWEI = parseInt(process.env.MAX_GAS_PRICE_GWEI || '15');
const TIP_GWEI = parseInt(process.env.TIP_GWEI || '2'); // Tip for builder
const CUDA_GRID = parseInt(process.env.CUDA_GRID || '512');
const CUDA_BLOCKS = parseInt(process.env.CUDA_BLOCKS || '256');
const CUDA_NPT = parseInt(process.env.CUDA_NPT || '128');
const EPOCH_POLL_MS = parseInt(process.env.EPOCH_POLL_MS || '30000');
const CUDA_BINARY = process.env.CUDA_BINARY || path.join(__dirname, '..', 'cuda', 'miner');

// ==================== HELPERS ====================
function difficultyToHex(difficulty) {
    return difficulty.toString(16).padStart(64, '0');
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// ==================== MAIN ====================
async function main() {
    if (!PRIVATE_KEY) {
        log.error('PRIVATE_KEY not set in .env file');
        process.exit(1);
    }

    log.hash('═══════════════════════════════════════');
    log.hash('   $HASH GPU Miner — CUDA Edition');
    log.hash('═══════════════════════════════════════');

    // Initialize contract
    const contract = new HashContract(RPC_URL, PRIVATE_KEY, TX_RPC_URL);
    const minerAddress = contract.getAddress();

    log.info(`Miner address: ${minerAddress}`);
    log.info(`Read RPC: ${RPC_URL}`);
    if (TX_RPC_URL) log.info(`Write RPC (Private): ${TX_RPC_URL}`);
    log.info(`Max gas price: ${MAX_GAS_PRICE_GWEI} gwei | Miner Tip: ${TIP_GWEI} gwei`);

    // Check ETH balance
    const balance = await contract.getBalance();
    log.info(`ETH balance: ${balance} ETH`);
    if (parseFloat(balance) < 0.005) {
        log.warn('Low ETH balance! You need ETH for gas fees.');
    }

    // Read mining state
    const state = await contract.getMiningState();
    log.info(`Era: ${state.era} | Reward: ${ethers.formatEther(state.reward)} HASH/mint`);
    log.info(`Difficulty (target): ${state.difficulty}`);
    log.info(`Minted: ${state.minted} | Remaining: ${state.remaining}`);
    log.info(`Epoch: ${state.epoch} | Blocks left: ${state.epochBlocksLeft}`);

    if (state.remaining === 0n) {
        log.error('Mining supply exhausted! No more HASH to mine.');
        process.exit(0);
    }

    // Initialize CUDA miner bridge
    const miner = new MinerBridge(CUDA_BINARY, CUDA_GRID, CUDA_BLOCKS, CUDA_NPT);

    // GPU log handler
    miner.on('log', (msg) => {
        if (msg.includes('Hashrate')) {
            log.gpu(msg);
        }
    });

    miner.on('error', (err) => {
        log.error(`CUDA process error: ${err.message}`);
    });

    miner.on('exit', (code) => {
        if (code !== 0 && code !== null) {
            log.warn(`CUDA process exited with code ${code}`);
        }
    });

    // ==================== MINING LOOP ====================
    let currentEpoch = null;
    let mining = true;
    let mineCount = 0;

    process.on('SIGINT', () => {
        log.warn('Shutting down...');
        mining = false;
        miner.stop();
        process.exit(0);
    });

    while (mining) {
        try {
            // Get fresh challenge and difficulty
            const challenge = await contract.getChallenge();
            const difficulty = await contract.getDifficulty();
            const epochInfo = await contract.getMiningState();
            const epoch = epochInfo.epoch;

            if (currentEpoch !== null && epoch !== currentEpoch) {
                log.warn(`Epoch changed: ${currentEpoch} -> ${epoch}`);
            }
            currentEpoch = epoch;

            const challengeHex = challenge.slice(2); // remove 0x
            const targetHex = difficultyToHex(difficulty);

            log.mine(`Starting mining | Epoch: ${epoch} | Blocks left: ${epochInfo.epochBlocksLeft}`);
            log.mine(`Challenge: 0x${challengeHex.slice(0, 16)}...`);
            log.mine(`Target:    0x${targetHex.slice(0, 16)}...`);

            // Random 256-bit start nonce to explore different parts of the space
            // 32 bytes = 64 hex characters
            const startNonce = ethers.hexlify(ethers.randomBytes(32)).slice(2);

            // Start CUDA miner
            const noncePromise = new Promise((resolve, reject) => {
                const onFound = (nonce) => {
                    miner.removeListener('exit', onExit);
                    resolve(nonce);
                };
                const onExit = (code) => {
                    miner.removeListener('found', onFound);
                    if (code !== 0 && code !== null) {
                        reject(new Error(`Miner exited with error code: ${code}`));
                    } else {
                        // Killed intentionally (SIGTERM from epoch change or shutdown)
                        resolve(null);
                    }
                };

                miner.once('found', onFound);
                miner.once('exit', onExit);
            });

            miner.start(challengeHex, targetHex, startNonce);

            // Poll for epoch changes - managed properly to avoid leaks
            let epochChanged = false;
            const epochCheck = setInterval(async () => {
                try {
                    const state = await contract.getMiningState();
                    if (state.epoch !== currentEpoch) {
                        log.warn(`Epoch changed: ${currentEpoch} -> ${state.epoch}. Restarting...`);
                        epochChanged = true;
                        miner.stop();
                    }
                } catch (e) {}
            }, EPOCH_POLL_MS);

            // Wait for solution
            let nonce;
            try {
                nonce = await noncePromise;
            } catch (e) {
                log.warn(`Mining error: ${e.message}. Retrying...`);
                nonce = null;
            } finally {
                clearInterval(epochCheck);
            }

            if (nonce === null) {
                await sleep(1000);
                continue;
            }

            // null = miner was stopped intentionally (epoch change), restart loop
            if (nonce === null) {
                log.info('Miner stopped, restarting with fresh challenge...');
                await sleep(500);
                continue;
            }

            log.success(`Solution found! Nonce: ${nonce}`);

            // Submit transaction
            log.info(`Submitting mine(nonce) transaction with ${TIP_GWEI} gwei tip...`);
            try {
                const tx = await contract.submitMine(nonce, MAX_GAS_PRICE_GWEI, TIP_GWEI);
                log.success(`TX submitted: ${tx.hash}`);
                log.info('Waiting for confirmation...');

                const receipt = await tx.wait();
                if (receipt.status === 1) {
                    mineCount++;
                    log.hash(`✓ MINED SUCCESSFULLY! (total: ${mineCount})`);
                    log.hash(`TX: https://etherscan.io/tx/${tx.hash}`);

                    // Check new balance
                    const newState = await contract.getMiningState();
                    log.info(`Remaining supply: ${newState.remaining}`);
                } else {
                    log.error('Transaction reverted!');
                }
            } catch (txErr) {
                log.error(`TX failed: ${txErr.message}`);
                if (txErr.message.includes('BlockCapReached')) {
                    log.warn('Block mint cap (10) reached. Waiting for next block...');
                    await sleep(15000);
                } else if (txErr.message.includes('ProofAlreadyUsed')) {
                    log.warn('Proof already used. Someone beat us. Retrying...');
                } else if (txErr.message.includes('InsufficientWork')) {
                    log.warn('Difficulty changed. Retrying with new target...');
                }
            }

            // Small delay before next round
            await sleep(1000);

        } catch (err) {
            log.error(`Error: ${err.message}`);
            miner.stop();
            await sleep(5000);
        }
    }
}

main().catch((err) => {
    log.error(`Fatal: ${err.message}`);
    process.exit(1);
});
