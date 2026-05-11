require('dotenv').config();
const { ethers } = require('ethers');
const { HashContract } = require('./contract');
const { log } = require('./logger');

async function check() {
    const RPC_URL = process.env.RPC_URL || 'https://ethereum-public.nodies.app/';

    log.hash('$HASH Mining State Check');
    log.hash('═══════════════════════');

    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const blockNumber = await provider.getBlockNumber();
    log.info(`Current block: ${blockNumber}`);
    log.info(`Current epoch: ${Math.floor(blockNumber / 100)}`);

    if (process.env.PRIVATE_KEY) {
        const contract = new HashContract(RPC_URL, process.env.PRIVATE_KEY);
        const address = contract.getAddress();
        log.info(`Miner address: ${address}`);

        const balance = await contract.getBalance();
        log.info(`ETH balance: ${balance} ETH`);

        const state = await contract.getMiningState();
        log.info(`Era: ${state.era}`);
        log.info(`Reward: ${ethers.formatEther(state.reward)} HASH per mint`);
        log.info(`Difficulty (target): ${state.difficulty}`);
        log.info(`Total minted: ${state.minted}`);
        log.info(`Remaining: ${state.remaining}`);
        log.info(`Epoch: ${state.epoch}`);
        log.info(`Epoch blocks left: ${state.epochBlocksLeft}`);

        const challenge = await contract.getChallenge();
        log.info(`Your challenge: ${challenge}`);
        log.info(`Target hex: 0x${state.difficulty.toString(16).padStart(64, '0')}`);
    } else {
        log.warn('PRIVATE_KEY not set — showing read-only info');
    }
}

check().catch((err) => {
    log.error(`Error: ${err.message}`);
    process.exit(1);
});
