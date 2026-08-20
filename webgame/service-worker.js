const CACHE = 'oddspot-webgame-v0.2.2'
const SHELL = [
  './', './index.html', './styles.css', './app.bundle.js',
  './assets/branding/guagua-rabbit-logo.png', './assets/branding/default-avatar.png',
  './assets/audio/ui_click.wav', './assets/audio/correct.wav',
]

// 逐个抓取并缓存，避免 addAll 的「全有或全无」；用 cache:'reload' 绕开 HTTP 缓存里可能存在的 206 分片响应，
// 仅缓存完整的 200 响应，单个失败不影响其它资源。
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => Promise.all(SHELL.map((path) =>
      fetch(new Request(path, { cache: 'reload' }))
        .then((response) => { if (response.status === 200) return cache.put(path, response) })
        .catch(() => {})
    ))).then(() => self.skipWaiting())
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key.startsWith('oddspot-webgame-') && key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim()))
})

// 只缓存完整的 200 响应；克隆必须在返回 response 之前同步完成，否则 body 会被消费导致 clone 失败。
function cachePut(request, response) {
  const copy = response.clone()
  return caches.open(CACHE).then((cache) => cache.put(request, copy))
}

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url)
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return

  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response.status === 200) event.waitUntil(cachePut(event.request, response))
          return response
        })
        .catch(() => caches.match(event.request))
    )
    return
  }

  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request).then((response) => {
      if (response.status === 200) event.waitUntil(cachePut(event.request, response))
      return response
    }))
  )
})
