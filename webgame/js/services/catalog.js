const config = require('../config')
const { read, write, remove } = require('../core/storage')

class CatalogRepository {
  constructor(api, preferences) { this.api = api; this.preferences = preferences; this.loading = null }
  key() { return `oddspot.catalog.${this.preferences.data.locale}` }
  cached() { return read(this.key(), null) }
  clear() { remove(this.key()) }
  async get(force = false) {
    const cache = this.cached()
    const now = Math.floor(Date.now() / 1000)
    if (!force && cache && cache.catalog) {
      if (now - Number(cache.loaded_at || 0) >= config.CATALOG_TTL_SECONDS && !this.loading) this.refresh()
      return { ok: true, data: cache.catalog, source: 'cache' }
    }
    return this.refresh()
  }
  async refresh() {
    if (this.loading) return this.loading
    this.loading = (async () => {
      const result = await this.api.getCatalog()
      if (result.ok) { write(this.key(), { loaded_at: Math.floor(Date.now() / 1000), catalog: result.data }); return result }
      const cache = this.cached()
      return cache && cache.catalog ? { ok: true, data: cache.catalog, source: 'stale_cache' } : result
    })()
    try { return await this.loading } finally { this.loading = null }
  }
}

module.exports = { CatalogRepository }
