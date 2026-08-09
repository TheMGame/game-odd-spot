function uuid() {
  const bytes = new Uint8Array(16)
  if (globalThis.crypto && globalThis.crypto.getRandomValues) globalThis.crypto.getRandomValues(bytes)
  else for (let i = 0; i < bytes.length; i += 1) bytes[i] = Math.floor(Math.random() * 256)
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (value) => value.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function deepClone(value) {
  return value == null ? value : JSON.parse(JSON.stringify(value))
}

function normalizeLocale(locale) {
  const value = String(locale || '').trim().replace(/_/g, '-').toLowerCase()
  if (['zh', 'zh-cn', 'zh-hans', 'zh-hans-cn'].includes(value)) return 'zh-CN'
  if (['en', 'en-us'].includes(value)) return 'en-US'
  if (/^[a-z]{2}-[a-z]{2}$/.test(value)) return `${value.slice(0, 2)}-${value.slice(3).toUpperCase()}`
  return value || 'en-US'
}

function dateString(date = new Date()) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function pointInPolygon(point, vertices) {
  let inside = false
  for (let i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
    const a = vertices[i]
    const b = vertices[j]
    const crossing = (a.y > point.y) !== (b.y > point.y)
      && point.x < ((b.x - a.x) * (point.y - a.y)) / ((b.y - a.y) || Number.EPSILON) + a.x
    if (crossing) inside = !inside
  }
  return inside
}

function formatElapsed(milliseconds) {
  const seconds = Math.max(0, Math.floor(milliseconds / 1000))
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`
}

module.exports = { uuid, sleep, clamp, deepClone, normalizeLocale, dateString, pointInPolygon, formatElapsed }
