const assert = require('assert')

const memory = new Map()
global.wx = {
  env: { USER_DATA_PATH: '/tmp/oddspot-test' },
  getRandomValues(bytes) { for (let i = 0; i < bytes.length; i += 1) bytes[i] = i + 1; return bytes },
  getStorageSync(key) { return memory.has(key) ? memory.get(key) : '' },
  setStorageSync(key, value) { memory.set(key, JSON.parse(JSON.stringify(value))) },
  removeStorageSync(key) { memory.delete(key) },
  getAppBaseInfo() { return { language: 'zh_CN' } },
  getWindowInfo() { return { windowWidth: 540, windowHeight: 960, pixelRatio: 1 } },
  getFileSystemManager() { return { mkdirSync() {}, accessSync() { throw new Error('missing') }, statSync() { return { size: 0 } }, unlinkSync() {} } },
  createCanvas() {
    const context = new Proxy({
      measureText(value) { return { width: String(value).length * 20 } },
    }, { get(target, key) { return key in target ? target[key] : () => {} }, set(target, key, value) { target[key] = value; return true } })
    return { width: 0, height: 0, getContext() { return context } }
  },
}

const { SessionStore, Preferences, ProgressStore } = require('../js/core/storage')
const { pointInPolygon } = require('../js/core/utils')
const { OddSpotApp, validateLevel } = require('../js/app')

function validLevel() {
  const descriptor = { asset_id: 'a', url: 'https://oddspot.guaguatu.com/content/a.webp', sha256: 'a'.repeat(64) }
  return {
    schema_version: 1, level_id: 'level-1', level_version: 2, mode: 'find_anachronism',
    assets: { width: 1024, height: 1024, image: descriptor },
    differences: [
      { id: 'd1', shape: 'circle', x: .2, y: .2, radius: .03 },
      { id: 'd2', shape: 'circle', x: .4, y: .4, radius: .03 },
      { id: 'd3', shape: 'polygon', points: [{ x: .6, y: .6 }, { x: .7, y: .6 }, { x: .65, y: .7 }] },
    ],
  }
}

assert.deepStrictEqual(validateLevel(validLevel()), { ok: true })
const invalid = validLevel(); invalid.differences[0].radius = .5
assert.strictEqual(validateLevel(invalid).ok, false)
assert.strictEqual(pointInPolygon({ x: .5, y: .5 }, [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }]), true)

const session = new SessionStore()
session.update({ user_id: 'u1', access_token: 'a', refresh_token: 'r', expires_in: 3600 })
assert.strictEqual(session.hasValidToken(), true)
const preferences = new Preferences()
assert.strictEqual(preferences.data.locale, 'zh-CN')
const progress = new ProgressStore(session)
const attempt = progress.getOrCreate('level-1', 2)
attempt.state = 'sync_queued'; progress.save('level-1', attempt)
assert.strictEqual(progress.isCompleted('level-1', 2), true)
assert.strictEqual(progress.isCompleted('level-1', 3), false)
session.update({ user_id: 'u2', access_token: 'b', refresh_token: 'r2', expires_in: 3600 })
assert.deepStrictEqual(progress.levels(), {})

const app = new OddSpotApp()
app.scene = 'login'; app.render()
app.scene = 'home'; app.catalogData = { series: [{ id: 's1', title: '系列', enabled: true, levels: [] }] }; app.render()
app.selectedSeriesId = 's1'; app.scene = 'levels'; app.render()
app.scene = 'settings'; app.render()
app.scene = 'game'; app.game = {
  loading: false,
  level: validLevel(),
  image: { width: 1000, height: 1000 },
  baseImage: null,
  found: {}, markers: [], foundInfo: null, complete: false,
  imageRects: [], view: { zoom: 1, x: 0, y: 0 },
  attempt: { hints_used: 0, elapsed_ms: 0 },
}
app.render()

console.log('wechat unit tests passed')
