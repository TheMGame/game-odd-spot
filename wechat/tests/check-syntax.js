const fs = require('fs')
const path = require('path')
const childProcess = require('child_process')

const root = path.resolve(__dirname, '..')
function visit(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name)
    if (entry.isDirectory() && entry.name !== 'node_modules') visit(full)
    else if (entry.isFile() && entry.name.endsWith('.js')) childProcess.execFileSync(process.execPath, ['--check', full], { stdio: 'inherit' })
  }
}
visit(root)

const gameConfig = JSON.parse(fs.readFileSync(path.join(root, 'game.json'), 'utf8'))
for (const subpackage of gameConfig.subpackages || []) {
  const entry = path.join(root, subpackage.root, 'game.js')
  if (!fs.existsSync(entry)) {
    throw new Error(`Missing WeChat subpackage entry: ${entry}`)
  }
}
console.log('wechat syntax check passed')
