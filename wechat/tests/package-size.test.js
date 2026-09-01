const assert = require('assert')
const fs = require('fs')
const path = require('path')

const root = path.resolve(__dirname, '..')
const forbidden = path.join(root, 'assets/home')
assert(!fs.existsSync(forbidden) || fs.readdirSync(forbidden, { recursive: true }).every((name) => !/\.(png|jpe?g|webp)$/i.test(name)), 'Admin-managed home images must not be bundled in the WeChat package')

function bytes(directory) {
  let total = 0
  if (!fs.existsSync(directory)) return total
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name)
    total += entry.isDirectory() ? bytes(full) : fs.statSync(full).size
  }
  return total
}

const mainBytes = bytes(path.join(root, 'assets')) + bytes(path.join(root, 'js'))
const budget = 8 * 1024 * 1024
assert(mainBytes <= budget, `WeChat main runtime assets exceed the 8 MiB project budget: ${(mainBytes / 1024 / 1024).toFixed(2)} MiB`)
console.log(`wechat package size tests passed (${(mainBytes / 1024 / 1024).toFixed(2)} MiB runtime assets)`)
