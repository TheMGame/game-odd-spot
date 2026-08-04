const { OddSpotApp } = require('./js/app')

const app = new OddSpotApp()
app.start().catch((error) => {
  console.error('[OddSpot] fatal startup error', error)
  app.showFatalError(error)
})

if (typeof GameGlobal !== 'undefined') GameGlobal.oddSpotApp = app
