const assert = require('assert')

const memory = new Map()
let shareMenuOptions = null
let shareHandler = null
let sharedPayload = null
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
  showShareMenu(options) { shareMenuOptions = options },
  onShareAppMessage(handler) { shareHandler = handler },
  shareAppMessage(payload) { sharedPayload = payload },
}

const { SessionStore, Preferences, ProgressStore } = require('../js/core/storage')
const { pointInPolygon } = require('../js/core/utils')
const { OddSpotApp, validateLevel, scoreToStars } = require('../js/app')
const { validateStory, StoryRuntime } = require('../js/core/story')
const config = require('../js/config')
require('./puzzle.test')

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
assert.deepStrictEqual(validateLevel({...validLevel(),mode:'image_puzzle',differences:undefined,puzzle:{rows:2,cols:3,operations:[{type:'swap',cells:[0,3]},{type:'swap',cells:[1,4]},{type:'swap',cells:[2,5]}]}}),{ok:true})
assert.strictEqual(validateLevel({...validLevel(),mode:'spot_difference'}).ok,false)
const story={start_node:'intro',nodes:{intro:{type:'scene',next:'choice'},choice:{type:'choice',choices:[{id:'inspect',label:'调查',next:'search'}]},search:{type:'hotspot',required:1,hotspots:[{id:'clue',x:.5,y:.5,evidence_id:'e1'}],next:'ending'},ending:{type:'ending',ending_id:'solved'}}}
assert.deepStrictEqual(validateStory(story),{ok:true})
assert.deepStrictEqual(validateLevel({schema_version:1,level_id:'story-1',mode:'interactive_story',assets:{},story}),{ok:true})
const storyRuntime=new StoryRuntime(story);storyRuntime.next();storyRuntime.choose('inspect');storyRuntime.findHotspot('clue');assert.strictEqual(storyRuntime.state.completed,true);assert.deepStrictEqual(storyRuntime.state.evidence,['e1'])
const invalid = validLevel(); invalid.differences[0].radius = .5
assert.strictEqual(validateLevel(invalid).ok, false)
assert.strictEqual(pointInPolygon({ x: .5, y: .5 }, [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }]), true)
assert.deepStrictEqual([0, 17, 50, 84, 100, 120].map(scoreToStars), [0, .5, 1.5, 2.5, 3, 3])
assert.strictEqual(config.GAME_TIME_LIMIT_SECONDS, 180)
assert.strictEqual(OddSpotApp.prototype.gameTimeLimitMs({ level: validLevel() }), 180000)
assert.strictEqual(OddSpotApp.prototype.gameTimeLimitMs({ level: { ...validLevel(), time_limit_seconds: 90 } }), 90000)
assert.strictEqual(OddSpotApp.prototype.gameTimeLimitMs({ level: { ...validLevel(), mode: 'image_puzzle', puzzle: { time_limit_seconds: 45 } } }), 45000)
assert.strictEqual(OddSpotApp.prototype.gameTimeLimitMs({ level: { ...validLevel(), time_limit_seconds: 0 } }), 0)

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
const replayAttempt = progress.restart('level-1', 2)
assert.strictEqual(replayAttempt.state, 'in_progress')
assert.strictEqual(progress.isCompleted('level-1', 2), true, 'replaying must preserve historical completion')
progress.setState('level-1', 'rejected', 'previous-attempt-id')
assert.strictEqual(progress.levels()['level-1'].state, 'in_progress', 'a previous attempt must not overwrite the active replay')
session.update({ user_id: 'u2', access_token: 'b', refresh_token: 'r2', expires_in: 3600 })
assert.deepStrictEqual(progress.levels(), {})

const app = new OddSpotApp()
app.setupSharing()
assert.deepStrictEqual(shareMenuOptions, { menus: ['shareAppMessage'] })
assert.strictEqual(typeof shareHandler, 'function')
assert.strictEqual(shareHandler().query, 'from=share')
app.shareGame()
assert.strictEqual(sharedPayload.query, 'from=share')
app.scene = 'login'; app.render()
app.scene = 'home'; app.catalogData = { series: [{ id: 's1', title: '系列', enabled: true, levels: [] }] }; app.render()
app.selectedSeriesId = 's1'; app.scene = 'levels'; app.render()
app.scene = 'settings'; app.render()
app.scene = 'leaderboard'; app.playerStats = { player_level: 2, total_points: 135, completed_levels: 1, average_score: 90 }; app.leaderboard = { scope: 'overall', entries: [{ rank: 1, user_id: 'u1', display_name: '侦探·u1', score: 90, points: 135, completed_levels: 1, is_me: true }], my_entry: { rank: 1, score: 90, points: 135 } }; app.render()
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
app.game.complete = true
app.game.itemReward = { item: { id: 'scroll_luoshen', name: '洛神赋卷' }, startedAt: Date.now() }
app.render()
assert(app.renderer.hitboxes.some((item) => item.id === 'dismissReward'), 'item reward reveal must be dismissible')

console.log('wechat unit tests passed')
