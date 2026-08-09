const config = require('../config')
const { KEYS, read, write } = require('../core/storage')
const { uuid } = require('../core/utils')

class Analytics {
  constructor(api, session, preferences) {
    this.api = api; this.session = session; this.preferences = preferences
    this.events = read(KEYS.analytics, []); this.sessionId = uuid(); this.flushing = false
  }
  track(eventType, payload = {}) {
    if (!this.preferences.data.analytics) return
    this.events.push({ event_id: uuid(), session_id: this.sessionId, event_type: eventType, market: 'global', locale: this.preferences.data.locale, app_version: config.APP_VERSION, occurred_at: new Date().toISOString(), payload })
    this.events = this.events.slice(-1000); write(KEYS.analytics, this.events)
    if (this.events.length >= 20) this.flush()
  }
  async flush() {
    if (this.flushing || !this.events.length || !this.session.hasToken()) return
    this.flushing = true
    try {
      while (this.events.length) {
        const batch = this.events.slice(0, 100)
        const result = await this.api.sendEvents(batch)
        if (!result.ok) break
        this.events.splice(0, batch.length); write(KEYS.analytics, this.events)
      }
    } finally { this.flushing = false }
  }
  setEnabled(enabled) { this.preferences.set('analytics', enabled); if (!enabled) { this.events = []; write(KEYS.analytics, []) } }
}

module.exports = { Analytics }
