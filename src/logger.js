const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    dim: '\x1b[2m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
};

function timestamp() {
    return new Date().toISOString().replace('T', ' ').replace('Z', '');
}

const log = {
    info: (msg) => console.log(`${colors.dim}[${timestamp()}]${colors.reset} ${colors.cyan}ℹ${colors.reset}  ${msg}`),
    success: (msg) => console.log(`${colors.dim}[${timestamp()}]${colors.reset} ${colors.green}✓${colors.reset}  ${msg}`),
    warn: (msg) => console.log(`${colors.dim}[${timestamp()}]${colors.reset} ${colors.yellow}⚠${colors.reset}  ${msg}`),
    error: (msg) => console.log(`${colors.dim}[${timestamp()}]${colors.reset} ${colors.red}✗${colors.reset}  ${msg}`),
    mine: (msg) => console.log(`${colors.dim}[${timestamp()}]${colors.reset} ${colors.magenta}⛏${colors.reset}  ${msg}`),
    gpu: (msg) => console.log(`${colors.dim}[${timestamp()}]${colors.reset} ${colors.blue}GPU${colors.reset} ${msg}`),
    hash: (msg) => console.log(`${colors.dim}[${timestamp()}]${colors.reset} ${colors.bright}${colors.green}$HASH${colors.reset} ${msg}`),
};

module.exports = { log };
