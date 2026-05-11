const { spawn } = require('child_process');
const path = require('path');
const EventEmitter = require('events');

class MinerBridge extends EventEmitter {
    constructor(cudaBinaryPath, gridSize = 512, blockSize = 256, noncesPerThread = 128) {
        super();
        this.cudaBinaryPath = cudaBinaryPath;
        this.gridSize = gridSize;
        this.blockSize = blockSize;
        this.noncesPerThread = noncesPerThread;
        this.process = null;
        this.running = false;
    }

    start(challengeHex, targetHex, startNonce = 0) {
        if (this.process) this.stop();

        // Remove 0x prefix if present
        const challenge = challengeHex.startsWith('0x') ? challengeHex.slice(2) : challengeHex;
        const target = targetHex.startsWith('0x') ? targetHex.slice(2).padStart(64, '0') : targetHex.padStart(64, '0');

        const args = [
            challenge,
            target,
            startNonce.toString(),
            this.gridSize.toString(),
            this.blockSize.toString(),
            this.noncesPerThread.toString(),
        ];

        this.process = spawn(this.cudaBinaryPath, args, {
            stdio: ['pipe', 'pipe', 'pipe'],
        });
        this.running = true;

        let stdoutBuffer = '';

        this.process.stdout.on('data', (data) => {
            stdoutBuffer += data.toString();
            const lines = stdoutBuffer.split('\n');
            stdoutBuffer = lines.pop(); // keep incomplete line

            for (const line of lines) {
                if (line.startsWith('FOUND:')) {
                    const nonce = line.split(':')[1].trim();
                    this.emit('found', nonce);
                }
            }
        });

        this.process.stderr.on('data', (data) => {
            const msg = data.toString().trim();
            if (msg) this.emit('log', msg);
        });

        this.process.on('exit', (code) => {
            this.running = false;
            this.process = null;
            this.emit('exit', code);
        });

        this.process.on('error', (err) => {
            this.running = false;
            this.emit('error', err);
        });
    }

    stop() {
        if (this.process) {
            this.process.kill('SIGTERM');
            this.process = null;
            this.running = false;
        }
    }

    isRunning() {
        return this.running;
    }
}

module.exports = { MinerBridge };
