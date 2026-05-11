const { ethers } = require('ethers');

const CONTRACT_ADDRESS = '0xAC7b5d06fa1e77D08aea40d46cB7C5923A87A0cc';

const MINING_ABI = [
    'function getChallenge(address miner) view returns (bytes32)',
    'function currentDifficulty() view returns (uint256)',
    'function miningState() view returns (uint256 era, uint256 reward, uint256 difficulty, uint256 minted, uint256 remaining, uint256 epoch, uint256 epochBlocksLeft_)',
    'function epochBlocksLeft() view returns (uint256)',
    'function mine(uint256 nonce)',
    'function usedProofs(bytes32) view returns (bool)',
    'function totalMints() view returns (uint256)',
    'function currentReward() view returns (uint256)',
    'function totalMiningMinted() view returns (uint256)',
    'event Mined(address indexed miner, uint256 nonce, uint256 reward, uint256 era)',
];

class HashContract {
    constructor(rpcUrl, privateKey) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.wallet = new ethers.Wallet(privateKey, this.provider);
        this.contract = new ethers.Contract(CONTRACT_ADDRESS, MINING_ABI, this.wallet);
        this.readContract = new ethers.Contract(CONTRACT_ADDRESS, MINING_ABI, this.provider);
    }

    async getChallenge() {
        return await this.readContract.getChallenge(this.wallet.address);
    }

    async getDifficulty() {
        return await this.readContract.currentDifficulty();
    }

    async getMiningState() {
        const state = await this.readContract.miningState();
        return {
            era: state.era,
            reward: state.reward,
            difficulty: state.difficulty,
            minted: state.minted,
            remaining: state.remaining,
            epoch: state.epoch,
            epochBlocksLeft: state.epochBlocksLeft_,
        };
    }

    async getEpochBlocksLeft() {
        return await this.readContract.epochBlocksLeft();
    }

    async submitMine(nonce, maxGasPriceGwei) {
        const feeData = await this.provider.getFeeData();
        const maxGasPrice = ethers.parseUnits(maxGasPriceGwei.toString(), 'gwei');

        if (feeData.gasPrice > maxGasPrice) {
            throw new Error(`Gas price ${ethers.formatUnits(feeData.gasPrice, 'gwei')} gwei exceeds max ${maxGasPriceGwei} gwei`);
        }

        const tx = await this.contract.mine(nonce, {
            gasLimit: 250000n,
            maxFeePerGas: feeData.maxFeePerGas,
            maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
        });

        return tx;
    }

    async getBalance() {
        const balance = await this.provider.getBalance(this.wallet.address);
        return ethers.formatEther(balance);
    }

    getAddress() {
        return this.wallet.address;
    }
}

module.exports = { HashContract, CONTRACT_ADDRESS };
