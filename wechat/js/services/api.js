const config = require('../config')
const { sleep, uuid } = require('../core/utils')

class ApiClient {
  constructor(session) {
    this.session = session
    this.businessDate = ''
    this.appTimezone = ''
    this.onSessionExpired = null
  }

  requestWx(options) {
    return new Promise((resolve) => wx.request(Object.assign({}, options, {
      success: resolve,
      fail: (error) => resolve({ statusCode: 0, data: null, errMsg: error.errMsg || 'NETWORK_ERROR' }),
    })))
  }

  async request(method, path, body = {}, authenticated = true, allowRefresh = true, idempotencyKey = '', attempt = 1) {
    if (authenticated && allowRefresh && !this.session.hasValidToken()) {
      const refreshed = await this.refreshSession()
      if (!refreshed.ok) return refreshed
    }
    const headers = { Accept: 'application/json' }
    if (method !== 'GET') headers['Content-Type'] = 'application/json'
    if (authenticated) headers.Authorization = `Bearer ${this.session.data.access_token}`
    if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey
    const response = await this.requestWx({ url: config.API_BASE_URL + path, method, data: method === 'GET' ? undefined : body, header: headers, timeout: path.startsWith('/v1/sessions/') ? 10000 : method === 'GET' ? 10000 : 15000 })
    const status = Number(response.statusCode || 0)
    if (status === 401 && authenticated && allowRefresh) {
      const refreshed = await this.refreshSession()
      if (refreshed.ok) return this.request(method, path, body, true, false, idempotencyKey, attempt)
    }
    if (status >= 200 && status < 300 && response.data && typeof response.data === 'object') return { ok: true, status, data: response.data, retryable: false }
    const retryable = status === 0 || status === 408 || status === 429 || status >= 500
    const failure = { ok: false, status, error: response.data && response.data.error_code ? response.data.error_code : status ? `HTTP_${status}` : 'NETWORK_ERROR', data: response.data || {}, retryable }
    if ((method === 'GET' || idempotencyKey) && retryable && attempt < 3) {
      await sleep((attempt === 1 ? 500 : 1500) + Math.random() * 250)
      return this.request(method, path, body, authenticated, allowRefresh, idempotencyKey, attempt + 1)
    }
    return failure
  }

  async userRequest(path, body) {
    const response = await this.requestWx({ url: config.USER_SERVER_BASE_URL + path, method: 'POST', data: body, header: { Accept: 'application/json', 'Content-Type': 'application/json' }, timeout: 10000 })
    if (response.statusCode >= 200 && response.statusCode < 300 && response.data && Number(response.data.code) === 0) return { ok: true, data: response.data }
    return { ok: false, status: Number(response.statusCode || 0), error: response.data && response.data.message ? String(response.data.message) : 'USER_SERVER_UNAVAILABLE', data: response.data || {} }
  }

  wechatLoginCode(withProfile = true) {
    return new Promise((resolve) => {
      const login = (profile) => wx.login({
        timeout: 10000,
        success: (result) => resolve(result.code ? { ok: true, code: result.code, profile } : { ok: false, error: 'WECHAT_LOGIN_CODE_MISSING' }),
        fail: (error) => resolve({ ok: false, error: 'WECHAT_LOGIN_FAILED', message: error.errMsg || '' }),
      })
      if (!withProfile || typeof wx.getUserProfile !== 'function') { login({}); return }
      wx.getUserProfile({
        desc: '用于在游戏中展示你的昵称和头像',
        success: (result) => { const user = result.userInfo || {}; login({ nickname: user.nickName || '', avatar_url: user.avatarUrl || '' }) },
        fail: () => login({}),
      })
    })
  }

  async loginWechat() {
    const codeResult = await this.wechatLoginCode(true)
    if (!codeResult.ok) return codeResult
    const wxInfo = { code: codeResult.code }
    if (codeResult.profile.nickname) wxInfo.nickname = codeResult.profile.nickname
    if (codeResult.profile.avatar_url) { wxInfo.avatar = codeResult.profile.avatar_url; wxInfo.avatar_url = codeResult.profile.avatar_url }
    const login = await this.userRequest('/api/v1/user/login', { app_id: config.USER_SERVER_APP_ID, login_type: 2, wx_info: wxInfo })
    if (!login.ok) return login
    return this.exchangeUserToken(login.data.data || {}, codeResult.profile)
  }

  async exchangeUserToken(loginData, profile = {}) {
    const token = String(loginData.token || '')
    if (!token) return { ok: false, error: 'USER_TOKEN_MISSING' }
    const result = await this.request('POST', '/v1/sessions/user-server', { token, locale: this.currentLocale || 'zh-CN' }, false, false)
    if (result.ok) {
      const user = loginData.user_info || loginData.user || loginData.profile || loginData
      const session = Object.assign({}, result.data.data || {}, {
        username: profile.nickname || user.nickname || user.username || user.name || '',
        avatar_url: profile.avatar_url || user.avatar_url || user.avatar || '',
        user_server_token: token,
        user_server_refresh_token: loginData.refresh_token || '',
      })
      this.session.update(session)
      if (profile.nickname || profile.avatar_url) await this.updateUserProfile(profile.nickname || '', profile.avatar_url || '')
    }
    return result
  }

  async updateUserProfile(nickname, avatar) {
    if (!this.session.data.user_id || !this.session.data.user_server_token) return { ok: false, error: 'USER_PROFILE_SESSION_MISSING' }
    const response = await this.requestWx({
      url: `${config.USER_SERVER_BASE_URL}/api/v1/user/info/${encodeURIComponent(this.session.data.user_id)}`,
      method: 'PUT',
      data: { nickname: String(nickname || '').trim(), avatar: String(avatar || '').trim() },
      header: { Accept: 'application/json', 'Content-Type': 'application/json', Authorization: `Bearer ${this.session.data.user_server_token}` },
      timeout: 8000,
    })
    return response.statusCode >= 200 && response.statusCode < 300 && response.data && Number(response.data.code) === 0
      ? { ok: true, data: response.data }
      : { ok: false, error: response.data && response.data.message ? response.data.message : 'USER_PROFILE_FAILED' }
  }

  async refreshSession() {
    if (!this.session.data.refresh_token) return { ok: false, error: 'REFRESH_TOKEN_MISSING' }
    const result = await this.request('POST', '/v1/sessions/refresh', { refresh_token: this.session.data.refresh_token }, false, false)
    if (result.ok) this.session.update(result.data.data || {})
    else if ([400, 401, 403].includes(result.status) && /INVALID|EXPIRED|REVOKED|NOT_FOUND/.test(String(result.error).toUpperCase())) {
      this.session.clear()
      if (this.onSessionExpired) this.onSessionExpired()
    }
    return result
  }

  async logout() {
    if (this.session.hasToken() && this.session.data.refresh_token) await this.request('POST', '/v1/sessions/logout', { refresh_token: this.session.data.refresh_token }, true, false)
    this.session.clear()
  }

  async bootstrap() {
    const result = await this.request('GET', '/v1/bootstrap')
    if (result.ok) { const data = result.data.data || {}; this.businessDate = data.business_date || ''; this.appTimezone = data.app_timezone || '' }
    return result
  }
  getCatalog() { return this.request('GET', '/v1/catalog') }
  getHome() { return this.request('GET', '/v1/home') }
  getLevel(id) { return this.request('GET', `/v1/levels/${encodeURIComponent(id)}`) }
  getLocales() { return this.request('GET', '/v1/locales', {}, false, false) }
  updateLocale(locale) { return this.request('PUT', '/v1/session/locale', { locale }) }
  sendEvents(events) { return this.request('POST', '/v1/events/batch', { events }) }
  reportLevel(id) { return this.request('POST', '/v1/reports', { level_id: id, category: 'other', description: '玩家从游戏内提交的关卡问题' }) }
  writeLevel(path, body, key = uuid()) { return this.request('POST', path, body, true, true, key) }
}

module.exports = { ApiClient }
