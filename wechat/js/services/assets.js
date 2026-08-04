const config = require('../config')

class AssetManager {
  constructor() {
    this.fs = wx.getFileSystemManager()
    this.root = `${wx.env.USER_DATA_PATH}/oddspot-assets`
    this.images = new Map()
    this.metaKey = 'oddspot.asset_meta.v1'
    this.meta = wx.getStorageSync(this.metaKey) || {}
    try { this.fs.mkdirSync(this.root, true) } catch (_) {}
  }

  imageFromPath(path) {
    if (this.images.has(path)) return Promise.resolve(this.images.get(path))
    return new Promise((resolve, reject) => {
      const image = wx.createImage()
      image.onload = () => { this.images.set(path, image); resolve(image) }
      image.onerror = reject
      image.src = path
    })
  }

  bundled(path) { return this.imageFromPath(path) }

  async loadDescriptor(asset) {
    if (!asset || !asset.asset_id || !asset.url) throw new Error('ASSET_DESCRIPTOR_INVALID')
    const suffix = extension(asset.content_type || asset.url)
    const path = `${this.root}/${safeName(asset.asset_id)}${suffix}`
    if (this.exists(path) && (!asset.sha256 || await this.matches(path, asset.sha256))) {
      this.touch(path)
      return this.imageFromPath(path)
    }
    return this.downloadImage(asset.url, path, asset.sha256 || '')
  }

  async loadUrl(url, variant = 'remote') {
    if (!url) throw new Error('ASSET_URL_MISSING')
    const key = simpleHash(`${variant}:${url}`)
    const path = `${this.root}/url_${key}${extension(url)}`
    if (this.exists(path)) { this.touch(path); return this.imageFromPath(path) }
    return this.downloadImage(url, path, '')
  }

  download(url) {
    return new Promise((resolve, reject) => wx.downloadFile({ url, timeout: 30000, success: (result) => result.statusCode >= 200 && result.statusCode < 300 ? resolve(result.tempFilePath) : reject(new Error(`ASSET_HTTP_${result.statusCode}`)), fail: (error) => reject(new Error(error.errMsg || 'ASSET_DOWNLOAD_FAILED')) }))
  }

  async downloadImage(url, destination, expectedHash) {
    const temp = await this.download(url)
    const info = await this.fileInfo(temp)
    if (info.size > config.MAX_ASSET_BYTES) throw new Error('ASSET_TOO_LARGE')
    if (expectedHash && info.digest && info.digest.toLowerCase() !== expectedHash.toLowerCase()) throw new Error('ASSET_HASH_MISMATCH')
    try { this.fs.unlinkSync(destination) } catch (_) {}
    await new Promise((resolve, reject) => this.fs.copyFile({ srcPath: temp, destPath: destination, success: resolve, fail: reject }))
    this.meta[destination] = { size: info.size, at: Date.now() }
    this.saveMeta()
    this.prune()
    return this.imageFromPath(destination)
  }

  fileInfo(path) {
    return new Promise((resolve) => {
      if (typeof wx.getFileInfo !== 'function') {
        try { resolve({ size: this.fs.statSync(path).size, digest: '' }) } catch (_) { resolve({ size: 0, digest: '' }) }
        return
      }
      wx.getFileInfo({ filePath: path, digestAlgorithm: 'sha256', success: resolve, fail: () => resolve({ size: 0, digest: '' }) })
    })
  }
  async matches(path, expected) { const info = await this.fileInfo(path); return !info.digest || info.digest.toLowerCase() === String(expected).toLowerCase() }
  exists(path) { try { this.fs.accessSync(path); return true } catch (_) { return false } }
  touch(path) { if (this.meta[path]) { this.meta[path].at = Date.now(); this.saveMeta() } }
  saveMeta() { try { wx.setStorageSync(this.metaKey, this.meta) } catch (_) {} }
  prune() {
    const entries = Object.entries(this.meta).sort((a, b) => a[1].at - b[1].at)
    let total = entries.reduce((sum, entry) => sum + Number(entry[1].size || 0), 0)
    for (const [path, item] of entries) {
      if (total <= config.ASSET_CACHE_LIMIT_BYTES) break
      try { this.fs.unlinkSync(path) } catch (_) {}
      total -= Number(item.size || 0)
      delete this.meta[path]
      this.images.delete(path)
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
function extension(value) { const clean = String(value).split('?')[0].toLowerCase(); if (clean.includes('png')) return '.png'; if (clean.includes('webp')) return '.webp'; return '.jpg' }

module.exports = { AssetManager }
