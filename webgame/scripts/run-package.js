const cp = require('child_process');
const path = require('path');

const isWin = process.platform === 'win32';
const scriptsDir = path.resolve(__dirname, '..', '..', 'scripts');
const args = process.argv.slice(2);

let cmd;
let cmdArgs;
if (isWin) {
  cmd = 'powershell';
  cmdArgs = [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', path.join(scriptsDir, 'package-native-webgame.ps1'),
    ...args,
  ];
} else {
  cmd = 'bash';
  cmdArgs = [
    path.join(scriptsDir, 'package-native-webgame.sh'),
    ...args,
  ];
}

const result = cp.spawnSync(cmd, cmdArgs, {
  stdio: 'inherit',
  cwd: path.resolve(__dirname, '..'),
});

process.exit(result.status == null ? 1 : result.status);
