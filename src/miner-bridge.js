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
        if (this.process) {
            const oldProcess = this.process;
            oldProcess.removeAllListeners();
            oldProcess.kill('SIGTERM');
            this.process = null;
        }

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

        const proc = spawn(this.cudaBinaryPath, args, {
            stdio: ['pipe', 'pipe', 'pipe'],
        });
        
        this.process = proc;
        this.running = true;

        let stdoutBuffer = '';

        proc.stdout.on('data', (data) => {
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

        proc.stderr.on('data', (data) => {
            const msg = data.toString().trim();
            if (msg) this.emit('log', msg);
        });

        proc.on('exit', (code) => {
            if (this.process === proc) {
                this.running = false;
                this.process = null;
                this.emit('exit', code);
            }
        });

        proc.on('error', (err) => {
            if (this.process === proc) {
                this.running = false;
                this.process = null;
                this.emit('error', err);
            }
        });
    }

    stop() {
        if (this.process) {
            const proc = this.process;
            this.process = null;
            this.running = false;
            proc.removeAllListeners();
            proc.kill('SIGTERM');
        }
    }

    isRunning() {
        return this.running;
    }
}

module.exports = { MinerBridge };
