const { KEYS, read, write } = require('../core/storage')
const { uuid } = require('../core/utils')

class SyncQueue {
  constructor(api, session, progress) {
    this.api = api
    this.session = session
    this.progress = progress
    this.items = read(KEYS.syncQueue, []).filter((item) => item && item.user_id)
    this.deadLetters = read(KEYS.deadLetters, [])
    this.flushing = false
  }
  save() { write(KEYS.syncQueue, this.items) }
  pendingCount() { return this.items.filter((item) => item.user_id === this.session.data.user_id).length }
  async submit(path, body, idempotencyKey = uuid()) {
    const item = { id: uuid(), user_id: this.session.data.user_id, path, body, idempotency_key: idempotencyKey, created_at: Math.floor(Date.now() / 1000) }
    this.items.push(item); this.save()
    const results = await this.flush(item.id)
    return results[item.id] || (this.items.some((candidate) => candidate.id === item.id) ? { ok: true, state: 'queued', queued: true, status: 0, error: 'SYNC_QUEUED' } : { ok: false, state: 'rejected', status: 0, error: 'SYNC_RESULT_MISSING' })
  }
  async flush(watchedId = '') {
    const resolved = {}
    if (this.flushing || !this.session.hasToken()) return resolved
    this.flushing = true
    try {
      while (true) {
        const index = this.items.findIndex((item) => item.user_id === this.session.data.user_id)
        if (index < 0) break
        const item = this.items[index]
        const result = await this.api.writeLevel(item.path, item.body, item.idempotency_key)
        if (result.ok) {
          const state = { ok: true, state: 'synced', queued: false, status: result.status, response: result.data }
          resolved[item.id] = state; this.onResolved(item, state); this.items.splice(index, 1); this.save(); continue
        }
        if (result.status >= 400 && result.status < 500 && ![401, 408, 429].includes(result.status)) {
          const state = { ok: false, state: 'rejected', queued: false, status: result.status, error: result.error, response: result.data }
          this.deadLetters.push(Object.assign({}, item, state, { failed_at: Math.floor(Date.now() / 1000) }))
          this.deadLetters = this.deadLetters.slice(-100); write(KEYS.deadLetters, this.deadLetters)
          resolved[item.id] = state; this.onResolved(item, state); this.items.splice(index, 1); this.save(); continue
        }
        break
      }
    } finally { this.flushing = false }
    return resolved
  }
  onResolved(item, result) {
    if (!item.path.endsWith('/complete')) return
    const levelId = decodeURIComponent(item.path.split('/')[3] || '')
    this.progress.setState(levelId, result.state === 'synced' ? 'synced' : 'rejected')
  }
}

module.exports = { SyncQueue }
