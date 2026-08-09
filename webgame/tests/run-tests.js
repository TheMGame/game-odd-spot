const assert = require('assert')
const crypto = require('crypto')
const fs = require('fs')
const path = require('path')
const { validateLevel } = require('../js/app')
const { pointInPolygon } = require('../js/core/utils')
const { validEmail } = require('../js/ui/login')

const root = path.resolve(__dirname, '..')

const level = {
  schema_version: 1,
  level_id: 'level-1',
  level_version: 1,
  mode: 'find_anachronism',
  assets: { width: 1200, height: 800, image: { asset_id: 'image-1', url: 'https://cdn.example/image.png' } },
  differences: [
    { id: 'a', shape: 'circle', x: .2, y: .2, radius: .05 },
    { id: 'b', shape: 'circle', x: .5, y: .5, radius: .05 },
    { id: 'c', shape: 'polygon', points: [{ x: .7, y: .7 }, { x: .8, y: .7 }, { x: .75, y: .8 }] },
  ],
}

assert.deepStrictEqual(validateLevel(level), { ok: true })
assert.strictEqual(pointInPolygon({ x: .75, y: .74 }, level.differences[2].points), true)
assert.strictEqual(pointInPolygon({ x: .2, y: .8 }, level.differences[2].points), false)
assert.strictEqual(validEmail('player@example.com'), true)
assert.strictEqual(validEmail('not-an-email'), false)

const expectedHashes = {
  'assets/audio/complete.wav': '8f12fcfdb0764656980058116ed96cbf57967b57e54ead3acdac7b50ac6fd558',
  'assets/audio/correct.wav': '3dc44ed3190aa48b43fa5a897f3c6382e3eb53208e19250abc983e29277e0459',
  'assets/audio/quiet_search_loop.wav': '6259c731b359a21b686091fd693262f2cb8e7c86c09c56c360fede714d367805',
  'assets/audio/ui_click.wav': 'c3181e395d14a57907c03e701bdc5f0bd761a39a63cf381e8b0bae4400571f2e',
  'assets/branding/default-avatar.png': 'f9fe75583edd3d11a40d1c566993b6daa8a030e4b864972646f196d00de63d5a',
  'assets/branding/guagua-rabbit-logo.png': 'e88abc5bfddb83d1eb5c652ab8c52e2db73b3495b9bb0646beb7cd9116ab54ea',
}
for (const [name, expected] of Object.entries(expectedHashes)) {
  const actual = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, name))).digest('hex')
  assert.strictEqual(actual, expected, `${name} must match the existing client asset`)
}

const animationFrames = fs.readdirSync(path.join(root, 'assets/animations')).filter((name) => name.endsWith('.png'))
assert.strictEqual(animationFrames.length, 20)

const jsFiles = walk(path.join(root, 'js')).filter((name) => name.endsWith('.js')).concat([path.join(root, 'game.js')])
for (const file of jsFiles) {
  const source = fs.readFileSync(file, 'utf8')
  assert(!/\bwx\./.test(source), `${path.relative(root, file)} still contains WeChat-only API usage`)
  assert(!/loginWechat|wechatLogin/.test(source), `${path.relative(root, file)} still contains WeChat login logic`)
}

for (const required of ['index.html', 'styles.css', 'app.bundle.js', 'service-worker.js']) {
  assert(fs.existsSync(path.join(root, required)), `${required} is missing`)
}

console.log('webgame unit and parity checks passed')

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const resolved = path.join(directory, entry.name)
    return entry.isDirectory() ? walk(resolved) : [resolved]
  })
}
