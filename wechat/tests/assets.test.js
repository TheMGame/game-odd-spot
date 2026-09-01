const assert = require('assert')
const crypto = require('crypto')

const files = new Map()
const storage = new Map()
const remote = new Map([['https://oddspot.guaguatu.com/content/thumb.jpg', Buffer.from('version-one')]])
let downloads = 0
let failCopies = false
let saves = 0
let lastSaveSource = ''
let requests = 0

function sha1(value) { return crypto.createHash('sha1').update(value).digest('hex') }

global.wx = {
  env: { USER_DATA_PATH: 'http://usr' },
  getStorageSync(key) { return storage.get(key) || '' },
  setStorageSync(key, value) { storage.set(key, JSON.parse(JSON.stringify(value))) },
  saveFile({ tempFilePath, success, fail }) {
    lastSaveSource = tempFilePath
    if (failCopies) { fail(new Error('copy denied')); return }
    const value = files.get(tempFilePath)
    if (!value) { fail(new Error('missing source')); return }
    const savedFilePath = `http://usr/saved-${++saves}.jpg`
    files.set(savedFilePath, Buffer.from(value)); files.delete(tempFilePath); success({ savedFilePath })
  },
  getFileSystemManager() {
    return {
      accessSync(path) { if (path !== 'http://usr' && !files.has(path)) throw new Error('missing') },
      unlinkSync(path) { files.delete(path) },
      statSync(path) { const value = files.get(path); if (!value) throw new Error('missing'); return { size: value.length } },
      getFileInfo({ filePath, digestAlgorithm, success, fail }) {
        const value = files.get(filePath)
        if (!value) { fail(new Error('missing')); return }
        success({ size: value.length, digest: crypto.createHash(digestAlgorithm).update(value).digest('hex') })
      },
      writeFile({ filePath, data, success, fail }) {
        if (failCopies) { fail(new Error('write denied')); return }
        files.set(filePath, Buffer.from(data)); success()
      },
      readFile({ filePath, encoding, success, fail }) {
        const value = files.get(filePath)
        if (!value) { fail({ errMsg: 'missing cached file' }); return }
        success({ data: encoding === 'base64' ? value.toString('base64') : Buffer.from(value) })
      },
      saveFile({ tempFilePath, filePath, success, fail }) {
        lastSaveSource = tempFilePath
        if (failCopies) { fail(new Error('copy denied')); return }
        const displayTempPath = tempFilePath.replace(/^\/tmp/, 'http://tmp')
        const value = files.get(displayTempPath)
        if (!value) { fail(new Error('missing source')); return }
        const savedFilePath = filePath || `http://usr/saved-${++saves}.jpg`
        files.set(savedFilePath, Buffer.from(value)); files.delete(displayTempPath); success({ savedFilePath })
      },
    }
  },
  request({ url, responseType, success, fail }) {
    const value = remote.get(url)
    if (!value || responseType !== 'arraybuffer') { fail({ errMsg: 'missing remote' }); return }
    requests += 1
    const copy = Buffer.from(value)
    success({ statusCode: 200, data: copy.buffer.slice(copy.byteOffset, copy.byteOffset + copy.byteLength) })
  },
  downloadFile({ url, filePath, success, fail }) {
    const value = remote.get(url)
    if (!value) { fail({ errMsg: 'missing remote' }); return }
    downloads += 1
    const destination = filePath || `http://tmp/download-${downloads}`
    files.set(destination, Buffer.from(value))
    success({ statusCode: 200, filePath: `http://tmp/display-${downloads}`, tempFilePath: destination })
  },
  createImage() {
    const image = {}
    Object.defineProperty(image, 'src', { set(value) { image.path = value; queueMicrotask(() => image.onload()) } })
    return image
  },
}

const { AssetManager } = require('../js/services/assets')

async function run() {
  const url = 'https://oddspot.guaguatu.com/content/thumb.jpg'
  const firstHash = sha1(remote.get(url))
  const first = new AssetManager()
  first.setRemoteHashes([{ url, sha1: firstHash }])
  const firstImage = await first.loadUrl(url, 'thumbnail')
  assert.strictEqual(requests, 1, 'first load requests the image bytes')
  assert.strictEqual(first.root, 'http://usr')
  assert.match(firstImage.path, /^data:image\/jpeg;base64,/, 'cached images are decoded from FileSystemManager.readFile data')

  const second = new AssetManager()
  second.setRemoteHashes([{ url, sha1: firstHash }])
  await second.loadUrl(url, 'thumbnail')
  assert.strictEqual(requests, 1, 'same hash reuses the persistent cache')

  remote.set(url, Buffer.from('version-two'))
  second.setRemoteHashes([{ url, sha1: sha1(remote.get(url)) }])
  const changedImage = await second.loadUrl(url, 'thumbnail')
  assert.strictEqual(requests, 2, 'changed hash requests only the changed image')
  assert.notStrictEqual(changedImage, firstImage, 'changed hash invalidates the decoded image cache')

  failCopies = true
  const beforeFallback = requests
  await second.loadUrl(url, 'copy_failure')
  assert.strictEqual(requests, beforeFallback + 1, 'persistence failure makes only one binary request')

  console.log('wechat asset cache tests passed')
}

run().catch((error) => { console.error(error); process.exitCode = 1 })
