const { uuid, deepClone } = require('./utils')

const KEYS = {
  session: 'oddspot.session.v1',
  preferences: 'oddspot.preferences.v1',
  progress: 'oddspot.progress.v1',
  syncQueue: 'oddspot.sync_queue.v1',
  deadLetters: 'oddspot.dead_letters.v1',
  analytics: 'oddspot.analytics.v1',
  hints: 'oddspot.daily_hints.v1',
}

function read(key, fallback) {
  try {
    const value = wx.getStorageSync(key)
    return value === '' || value == null ? deepClone(fallback) : value
  } catch (_) {
    return deepClone(fallback)
  }
}

function write(key, value) {
  try {
    wx.setStorageSync(key, value)
    return true
  } catch (error) {
    console.warn('[OddSpot] storage write failed', key, error)
    return false
  }
}

class SessionStore {
  constructor() {
    this.data = Object.assign({
      installation_id: uuid().replace(/-/g, '') + uuid().replace(/-/g, ''),
      user_id: '', access_token: '', refresh_token: '', access_expires_at: 0,
      username: '', avatar_url: '', user_server_token: '', user_server_refresh_token: '',
    }, read(KEYS.session, {}))
    write(KEYS.session, this.data)
  }

  update(data) {
    const next = Object.assign({}, this.data)
    for (const key of ['user_id', 'access_token', 'refresh_token', 'username', 'avatar_url', 'user_server_token', 'user_server_refresh_token']) {
      if (data[key] != null && data[key] !== '') next[key] = String(data[key])
    }
    if (data.expires_in != null && Number(data.expires_in) > 0) {
      next.access_expires_at = Math.floor(Date.now() / 1000) + Number(data.expires_in)
    } else if (data.access_expires_at != null) next.access_expires_at = Number(data.access_expires_at)
    this.data = next
    write(KEYS.session, next)
  }

  clear() {
    const installationId = this.data.installation_id
    this.data = { installation_id: installationId, user_id: '', access_token: '', refresh_token: '', access_expires_at: 0, username: '', avatar_url: '', user_server_token: '', user_server_refresh_token: '' }
    write(KEYS.session, this.data)
  }

  hasToken() { return Boolean(this.data.access_token) }
  hasValidToken() { return this.hasToken() && Math.floor(Date.now() / 1000) + 30 < Number(this.data.access_expires_at || 0) }
}

class Preferences {
  constructor() {
    const system = wx.getAppBaseInfo ? wx.getAppBaseInfo() : wx.getSystemInfoSync()
    this.data = Object.assign({
      analytics: true, vibration: true, music: true, effects: true,
      largeMarkers: false, locale: String(system.language || '').startsWith('zh') ? 'zh-CN' : 'en-US',
      localeMode: 'automatic', localePackVersion: 0,
      watermarkEnabled: true, watermarkText: '',
    }, read(KEYS.preferences, {}))
  }

  set(key, value) { this.data[key] = value; write(KEYS.preferences, this.data) }
}

class ProgressStore {
  constructor(session) { this.session = session; this.users = read(KEYS.progress, {}) }
  levels() { return deepClone(this.users[this.session.data.user_id] || {}) }
  saveLevels(levels) { if (this.session.data.user_id) { this.users[this.session.data.user_id] = deepClone(levels); write(KEYS.progress, this.users) } }
  getOrCreate(levelId, version) {
    const levels = this.levels()
    const existing = levels[levelId]
    if (existing && !['synced', 'completed'].includes(existing.state) && Number(existing.level_version) === Number(version)) return deepClone(existing)
    const created = { attempt_id: uuid(), start_idempotency_key: uuid(), level_version: Number(version), state: 'in_progress', found: [], hints_used: 0, elapsed_ms: 0, zoom: 1, view_offset_x: 0, view_offset_y: 0 }
    levels[levelId] = created
    this.saveLevels(levels)
    return deepClone(created)
  }
  save(levelId, attempt) { const levels = this.levels(); levels[levelId] = deepClone(attempt); this.saveLevels(levels) }
  clear(levelId) { const levels = this.levels(); delete levels[levelId]; this.saveLevels(levels) }
  isCompleted(levelId, version) {
    const saved = this.levels()[levelId] || {}
    return ['local_completed', 'sync_queued', 'synced', 'completed'].includes(saved.state) && Number(saved.level_version) === Number(version)
  }
  setState(levelId, state) { const levels = this.levels(); if (levels[levelId]) { levels[levelId].state = state; this.saveLevels(levels) } }
}

module.exports = { KEYS, read, write, SessionStore, Preferences, ProgressStore }
