const { OddSpotApp } = require('./js/app')

const app = new OddSpotApp()
app.start().catch((error) => {
  console.error('[OddSpot] fatal startup error', error)
  app.showFatalError(error)
})

window.oddSpotApp = app

if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => navigator.serviceWorker.register('./service-worker.js').catch(() => {}), { once: true })
}
