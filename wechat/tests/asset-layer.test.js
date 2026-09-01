const assert = require('assert')
const fs = require('fs')
const path = require('path')

const jsRoot = path.resolve(__dirname, '../js')
const assetService = path.join(jsRoot, 'services/assets.js')

function javascriptFiles(directory) {
  const result = []
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name)
    if (entry.isDirectory()) result.push(...javascriptFiles(full))
    else if (entry.isFile() && entry.name.endsWith('.js')) result.push(full)
  }
  return result
}

for (const file of javascriptFiles(jsRoot)) {
  if (file === assetService) continue
  const source = fs.readFileSync(file, 'utf8')
  assert(!/wx\.createImage\s*\(/.test(source), `${path.relative(jsRoot, file)} bypasses the image cache with wx.createImage`)
  assert(!/wx\.downloadFile\s*\(/.test(source), `${path.relative(jsRoot, file)} bypasses the image cache with wx.downloadFile`)
}

const appSource = fs.readFileSync(path.join(jsRoot, 'app.js'), 'utf8')
for (const required of ['home.logo_url', 'home.header_url', 'home.hero_fallback_url', 'home.collection_placeholder_url', "variant: 'series'", "variant: 'level_thumbnail'", "variant: 'museum'", "descriptor: level.assets.image"]) {
  assert(appSource.includes(required), `Admin image category is not routed through loadImageBatch: ${required}`)
}

console.log('wechat asset layer tests passed')
