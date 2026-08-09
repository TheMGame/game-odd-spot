const runtime = typeof window !== 'undefined' && window.ODDSPOT_CONFIG ? window.ODDSPOT_CONFIG : {}

module.exports = {
  APP_NAME: '错位大侦探',
  APP_VERSION: '0.2.0',
  API_BASE_URL: String(runtime.API_BASE_URL || 'https://oddspot.guaguatu.com').replace(/\/$/, ''),
  USER_SERVER_BASE_URL: String(runtime.USER_SERVER_BASE_URL || 'https://api.guaguatu.com').replace(/\/$/, ''),
  USER_SERVER_APP_ID: 'game_odd_spot',
  CATALOG_TTL_SECONDS: 300,
  DAILY_FREE_HINTS: 3,
  MAX_ASSET_BYTES: 25 * 1024 * 1024,
}
