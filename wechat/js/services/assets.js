const config = require('../config')

class AssetManager {
  constructor() {
    this.fs = wx.getFileSystemManager()
    this.root = String(wx.env.USER_DATA_PATH || '').replace(/\/$/, '')
    this.images = new Map()
    this.pending = new Map()
    this.remoteHashes = new Map()
    this.metaKey = 'oddspot.asset_meta.v5'
    this.meta = wx.getStorageSync(this.metaKey) || {}
  }

  imageFromPath(path) {
    path = imageDisplayPath(path)
    if (this.images.has(path)) return Promise.resolve(this.images.get(path))
    return new Promise((resolve, reject) => {
      const image = wx.createImage()
      image.onload = () => { this.images.set(path, image); resolve(image) }
      image.onerror = () => reject(new Error(`ASSET_IMAGE_DECODE_FAILED: ${path}`))
      image.src = path
    })
  }

  imageFromCachedFile(path) {
    const key = `cached:${path}`
    if (this.images.has(key)) return Promise.resolve(this.images.get(key))
    return new Promise((resolve, reject) => this.fs.readFile({
      filePath: path,
      encoding: 'base64',
      success: (result) => {
        const image = wx.createImage()
        image.onload = () => { this.images.set(key, image); resolve(image) }
        image.onerror = () => reject(new Error(`ASSET_IMAGE_DECODE_FAILED: ${path}`))
        image.src = `data:${mimeType(path)};base64,${result.data}`
      },
      fail: (error) => reject(new Error(error && error.errMsg || `ASSET_CACHE_READ_FAILED: ${path}`)),
    }))
  }

  bundled(path) { return this.imageFromPath(path) }

  setRemoteHashes(items) {
    for (const item of Array.isArray(items) ? items : []) {
      if (!item || !item.url) continue
      // WeChat's file-info API supports SHA-1 consistently across the
      // supported runtime versions. The server returns SHA-1 specifically for
      // this local-cache comparison.
      if (item.sha1) this.remoteHashes.set(normalizeRemoteUrl(item.url), { algorithm: 'sha1', digest: String(item.sha1).toLowerCase() })
    }
  }

  async loadDescriptor(asset) {
    if (!asset || !asset.asset_id || !asset.url) throw new Error('ASSET_DESCRIPTOR_INVALID')
    const url = normalizeRemoteUrl(asset.url), suffix = extension(asset.content_type || url)
    const cacheKey = `asset:${safeName(asset.asset_id)}${suffix}`
    const path = this.cachedPath(cacheKey)
    const expected = this.remoteHashes.get(url) || null
    if (path && this.exists(path) && (!expected || await this.cachedMatches(cacheKey, path, expected))) {
      try {
        const image = await this.imageFromCachedFile(path)
        this.touch(cacheKey)
        return image
      } catch (_) { logAsset('miss:decode', url, cacheKey, path); this.removeCached(cacheKey) }
    }
    if (!path || !this.exists(path)) logAsset('miss:file', url, cacheKey, path)
    else if (expected) logAsset('miss:hash', url, cacheKey, path)
    if (path && this.exists(path)) this.removeCached(cacheKey)
    return this.downloadImage(url, cacheKey, expected && expected.digest || '', expected && expected.algorithm || 'sha1')
  }

  async loadUrl(url, variant = 'remote') {
    if (!url) throw new Error('ASSET_URL_MISSING')
    url = normalizeRemoteUrl(url)
    const key = simpleHash(`${variant}:${url}`)
    const cacheKey = `url:${key}${extension(url)}`, path = this.cachedPath(cacheKey), expected = this.remoteHashes.get(url) || null
    if (path && this.exists(path) && (!expected || await this.cachedMatches(cacheKey, path, expected))) {
      try {
        const image = await this.imageFromCachedFile(path)
        this.touch(cacheKey)
        return image
      } catch (_) { logAsset('miss:decode', url, cacheKey, path); this.removeCached(cacheKey) }
    }
    if (!path || !this.exists(path)) logAsset('miss:file', url, cacheKey, path)
    else if (expected) logAsset('miss:hash', url, cacheKey, path)
    if (path && this.exists(path)) this.removeCached(cacheKey)
    return this.downloadImage(url, cacheKey, expected && expected.digest || '', expected && expected.algorithm || 'sha256')
  }

  download(url, filePath = '') {
    const options = { url, timeout: 30000, success: (result) => result.statusCode >= 200 && result.statusCode < 300 ? resolvePath(result) : rejectPath(result), fail: (error) => rejectPath(error) }
    if (filePath) options.filePath = filePath
    let resolvePath, rejectPath
    return new Promise((resolve, reject) => {
      resolvePath = (result) => resolve(result.tempFilePath || result.filePath || filePath)
      rejectPath = (error) => reject(new Error(error && error.statusCode ? `ASSET_HTTP_${error.statusCode}` : error && error.errMsg || 'ASSET_DOWNLOAD_FAILED'))
      wx.downloadFile(options)
    })
  }

  requestBytes(url) {
    return new Promise((resolve, reject) => wx.request({
      url,
      method: 'GET',
      responseType: 'arraybuffer',
      timeout: 30000,
      success: (result) => {
        const status = Number(result.statusCode || 0)
        if (status < 200 || status >= 300 || !(result.data instanceof ArrayBuffer)) { reject(new Error(status ? `ASSET_HTTP_${status}` : 'ASSET_BINARY_RESPONSE_INVALID')); return }
        resolve(result.data)
      },
      fail: (error) => reject(new Error(error && error.errMsg || 'ASSET_DOWNLOAD_FAILED')),
    }))
  }

  async downloadImage(url, destination, expectedHash, hashAlgorithm = 'sha256') {
    if (this.pending.has(destination)) return this.pending.get(destination)
    const task = this.downloadAndPersist(url, destination, expectedHash, hashAlgorithm)
    this.pending.set(destination, task)
    try { return await task } finally { this.pending.delete(destination) }
  }

  async downloadAndPersist(url, cacheKey, expectedHash, hashAlgorithm) {
    let bytes = null
    try {
      this.removeCached(cacheKey)
      bytes = await this.requestBytes(url)
      if (bytes.byteLength > config.MAX_ASSET_BYTES) throw new Error('ASSET_TOO_LARGE')
      const savedPath = `${this.root}/oddspot_v5_${safeName(cacheKey)}`
      await this.writeFile(savedPath, bytes)
      const persisted = await this.fileInfo(savedPath, '')
      if (!this.exists(savedPath)) throw new Error('ASSET_CACHE_WRITE_FAILED')
      const image = await this.imageFromCachedFile(savedPath)
      this.meta[cacheKey] = { path: savedPath, size: persisted.size || bytes.byteLength, hash: expectedHash || '', hash_algorithm: expectedHash ? hashAlgorithm : '', source_url: url, at: Date.now() }
      this.saveMeta()
      this.prune()
      return image
    } catch (error) {
      this.removeCached(cacheKey)
      console.warn('asset cache fallback', cacheKey, error && error.message || error && error.errMsg || String(error))
      const temp = await this.download(url)
      return this.imageFromPath(temp)
    }
  }

  writeFile(path, data) {
    return new Promise((resolve, reject) => this.fs.writeFile({ filePath: path, data, success: resolve, fail: reject }))
  }

  fileInfo(path, digestAlgorithm = '') {
    return new Promise((resolve) => {
      const stat = () => { try { const value = this.fs.statSync(path); resolve({ size: Number(value.size || value.stats && value.stats.size || 0), digest: '' }) } catch (_) { resolve({ size: 0, digest: '' }) } }
      if (!digestAlgorithm) { stat(); return }
      const legacy = () => {
        if (typeof wx.getFileInfo !== 'function') { stat(); return }
        wx.getFileInfo({ filePath: path, digestAlgorithm, success: resolve, fail: stat })
      }
      if (typeof this.fs.getFileInfo !== 'function') { legacy(); return }
      this.fs.getFileInfo({ filePath: path, digestAlgorithm, success: resolve, fail: legacy })
    })
  }
  cachedPath(cacheKey) { const item = this.meta[cacheKey]; return item && item.path || '' }
  async cachedMatches(cacheKey, path, expected) {
    const item = this.meta[cacheKey]
    if (item && item.hash_algorithm === expected.algorithm && String(item.hash || '').toLowerCase() === expected.digest) return true
    return this.matches(path, expected.digest, expected.algorithm)
  }
  async matches(path, expected, algorithm = 'sha256') { const info = await this.fileInfo(path, algorithm); return !!info.digest && info.digest.toLowerCase() === String(expected).toLowerCase() }
  exists(path) { try { this.fs.accessSync(path); return true } catch (_) { return false } }
  removeCached(cacheKey) { const path = this.cachedPath(cacheKey); if (path) try { this.fs.unlinkSync(path) } catch (_) {}; delete this.meta[cacheKey]; if (path) { this.images.delete(imageDisplayPath(path)); this.images.delete(`cached:${path}`) }; this.saveMeta() }
  touch(cacheKey) { if (this.meta[cacheKey]) { this.meta[cacheKey].at = Date.now(); this.saveMeta() } }
  saveMeta() { try { wx.setStorageSync(this.metaKey, this.meta) } catch (_) {} }
  prune() {
    const entries = Object.entries(this.meta).sort((a, b) => a[1].at - b[1].at)
    let total = entries.reduce((sum, entry) => sum + Number(entry[1].size || 0), 0)
    for (const [cacheKey, item] of entries) {
      if (total <= config.ASSET_CACHE_LIMIT_BYTES) break
      try { this.fs.unlinkSync(item.path) } catch (_) {}
      total -= Number(item.size || 0)
      delete this.meta[cacheKey]
      this.images.delete(imageDisplayPath(item.path))
      this.images.delete(`cached:${item.path}`)
    }
    this.saveMeta()
  }
}

function simpleHash(value) {
  let hash = 2166136261
  for (let i = 0; i < value.length; i += 1) { hash ^= value.charCodeAt(i); hash = Math.imul(hash, 16777619) }
  return (hash >>> 0).toString(16).padStart(8, '0')
}
function safeName(value) { return String(value).replace(/[^a-zA-Z0-9._-]/g, '_') }
function imageDisplayPath(value) { return String(value || '') }
function normalizeRemoteUrl(value) { return String(value).replace(/^https?:\/\/(?:127\.0\.0\.1|localhost)(?::\d+)?(?=\/)/i, String(config.API_BASE_URL || '').replace(/\/$/, '')) }
function extension(value) { const clean = String(value).split('?')[0].toLowerCase(); if (clean.includes('png')) return '.png'; if (clean.includes('webp')) return '.webp'; return '.jpg' }
function mimeType(value) { const suffix = extension(value); return suffix === '.png' ? 'image/png' : suffix === '.webp' ? 'image/webp' : 'image/jpeg' }
function logAsset(source, url, cacheKey, path = '') {
  const safeUrl = String(url || '').split('?')[0]
  console.log(`[AssetCache] ${source} url=${safeUrl} key=${cacheKey}${path ? ` path=${path}` : ''}`)
}

module.exports = { AssetManager }
