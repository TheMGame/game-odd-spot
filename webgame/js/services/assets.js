const config = require('../config')

class AssetManager {
  constructor() {
    this.images = new Map()
    this.objectUrls = []
  }

  bundled(path) { return this.imageFromUrl(path, false) }

  async loadDescriptor(asset) {
    if (!asset || !asset.asset_id || !asset.url) throw new Error('ASSET_DESCRIPTOR_INVALID')
    const key = `${asset.asset_id}:${asset.sha256 || asset.url}`
    if (this.images.has(key)) return this.images.get(key)
    const image = await this.fetchImage(asset.url, asset.sha256 || '')
    this.images.set(key, image)
    return image
  }

  async loadUrl(url, variant = 'remote') {
    if (!url) throw new Error('ASSET_URL_MISSING')
    const key = `${variant}:${url}`
    if (this.images.has(key)) return this.images.get(key)
    const image = /^https?:\/\//i.test(url) ? await this.fetchImage(url, '') : await this.imageFromUrl(url, false)
    this.images.set(key, image)
    return image
  }

  imageFromUrl(url, crossOrigin = true) {
    if (this.images.has(url)) return Promise.resolve(this.images.get(url))
    return new Promise((resolve, reject) => {
      const image = new Image()
      image.decoding = 'async'
      if (crossOrigin) image.crossOrigin = 'anonymous'
      image.onload = () => { this.images.set(url, image); resolve(image) }
      image.onerror = () => reject(new Error('ASSET_IMAGE_DECODE_FAILED'))
      image.src = url
    })
  }

  async fetchImage(url, expectedHash) {
    let response
    try { response = await fetch(url, { mode: 'cors', credentials: 'omit', cache: 'force-cache' }) } catch (_) { throw new Error('ASSET_DOWNLOAD_FAILED') }
    if (!response.ok) throw new Error(`ASSET_HTTP_${response.status}`)
    const buffer = await response.arrayBuffer()
    if (buffer.byteLength > config.MAX_ASSET_BYTES) throw new Error('ASSET_TOO_LARGE')
    if (expectedHash) {
      const actual = await sha256Hex(buffer)
      if (actual && actual.toLowerCase() !== String(expectedHash).toLowerCase()) throw new Error('ASSET_HASH_MISMATCH')
    }
    const contentType = response.headers.get('Content-Type') || mimeFromUrl(url)
    const objectUrl = URL.createObjectURL(new Blob([buffer], { type: contentType }))
    this.objectUrls.push(objectUrl)
    return this.imageFromUrl(objectUrl, false)
  }
}

async function sha256Hex(buffer) {
  if (!globalThis.crypto || !globalThis.crypto.subtle) return ''
  const digest = await globalThis.crypto.subtle.digest('SHA-256', buffer)
  return Array.from(new Uint8Array(digest), (value) => value.toString(16).padStart(2, '0')).join('')
}

function mimeFromUrl(url) {
  const clean = String(url).split('?')[0].toLowerCase()
  if (clean.endsWith('.png')) return 'image/png'
  if (clean.endsWith('.webp')) return 'image/webp'
  return 'image/jpeg'
}

module.exports = { AssetManager, sha256Hex }
