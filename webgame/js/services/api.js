const config = require('../config')
const { sleep, uuid } = require('../core/utils')

class ApiClient {
  constructor(session) {
    this.session = session
    this.businessDate = ''
    this.appTimezone = ''
    this.currentLocale = 'zh-CN'
    this.onSessionExpired = null
  }

  async fetchJson(url, options = {}, timeout = 10000) {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeout)
    try {
      const response = await fetch(url, Object.assign({ credentials: 'omit', cache: 'no-store' }, options, { signal: controller.signal }))
      const text = await response.text()
      let data = null
      try { data = text ? JSON.parse(text) : {} } catch (_) { data = { message: text } }
      return { statusCode: response.status, data }
    } catch (error) {
      return { statusCode: 0, data: null, errMsg: error && error.name === 'AbortError' ? 'REQUEST_TIMEOUT' : (error.message || 'NETWORK_ERROR') }
    } finally {
      clearTimeout(timer)
    }
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
    const response = await this.fetchJson(config.API_BASE_URL + path, {
      method,
      headers,
      body: method === 'GET' ? undefined : JSON.stringify(body),
    }, path.startsWith('/v1/sessions/') ? 10000 : method === 'GET' ? 10000 : 15000)
    const status = Number(response.statusCode || 0)
    if (status === 401 && authenticated && allowRefresh) {
      const refreshed = await this.refreshSession()
      if (refreshed.ok) return this.request(method, path, body, true, false, idempotencyKey, attempt)
    }
    if (status >= 200 && status < 300 && response.data && typeof response.data === 'object') return { ok: true, status, data: response.data, retryable: false }
    const retryable = status === 0 || status === 408 || status === 429 || status >= 500
    const failure = { ok: false, status, error: response.data && response.data.error_code ? response.data.error_code : status ? `HTTP_${status}` : response.errMsg || 'NETWORK_ERROR', data: response.data || {}, retryable }
    if ((method === 'GET' || idempotencyKey) && retryable && attempt < 3) {
      await sleep((attempt === 1 ? 500 : 1500) + Math.random() * 250)
      return this.request(method, path, body, authenticated, allowRefresh, idempotencyKey, attempt + 1)
    }
    return failure
  }

  async userRequest(path, body) {
    const response = await this.fetchJson(config.USER_SERVER_BASE_URL + path, {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }, 10000)
    if (response.statusCode >= 200 && response.statusCode < 300 && response.data && Number(response.data.code) === 0) return { ok: true, data: response.data }
    return { ok: false, status: Number(response.statusCode || 0), error: response.data && response.data.message ? String(response.data.message) : response.errMsg || 'USER_SERVER_UNAVAILABLE', data: response.data || {} }
  }

  async uploadUserAvatar(fileOrBlob) {
    if (!this.session.data.user_server_token) return { ok: false, error: 'USER_PROFILE_SESSION_MISSING' }
    const formData = new FormData()
    formData.append('avatar', fileOrBlob)
    const response = await this.fetchJson(`${config.USER_SERVER_BASE_URL}/api/v1/user/avatar/upload`, {
      method: 'POST',
      headers: { Accept: 'application/json', Authorization: `Bearer ${this.session.data.user_server_token}` },
      body: formData,
    }, 30000)
    if (!(response.statusCode >= 200 && response.statusCode < 300 && response.data && Number(response.data.code) === 0)) return { ok: false, error: response.data && response.data.message ? response.data.message : 'AVATAR_UPLOAD_FAILED' }
    const data = response.data.data || {}
    const url = data.avatar_url || data.url || ''
    if (url) this.session.update({ avatar_url: url })
    return { ok: true, data: { avatar_url: url } }
  }

  async loginUser(accountName, password, mode = 'auto') {
    const account = String(accountName || '').trim()
    const body = { app_id: config.USER_SERVER_APP_ID, login_type: 1, password }
    const isPhone = mode === 'phone' || /^1[3-9]\d{9}$/.test(account.replace(/^\+?86/, '').replace(/[\s-]/g, ''))
    if (isPhone) body.tel_num = account.replace(/^\+?86/, '').replace(/[\s-]/g, '')
    else if (account.includes('@')) body.email = account.toLowerCase()
    else body.username = account
    const login = await this.userRequest('/api/v1/user/login', body)
    if (!login.ok) return login
    return this.exchangeUserToken(login.data.data || {})
  }

  async sendEmailCode(email) {
    return this.userRequest('/api/v1/user/email/send-code', { app_id: config.USER_SERVER_APP_ID, email: String(email || '').trim().toLowerCase(), purpose: 'login' })
  }

  async sendPhoneCode(phone) {
    const normalized = String(phone || '').replace(/^\+?86/, '').replace(/[\s-]/g, '').trim()
    return this.userRequest('/api/v1/user/phone/send-code', { app_id: config.USER_SERVER_APP_ID, phone: normalized })
  }

  async verifyEmailCode(email, code) {
    const result = await this.userRequest('/api/v1/user/email/verify', { app_id: config.USER_SERVER_APP_ID, email: String(email || '').trim().toLowerCase(), code: String(code || '').trim() })
    if (!result.ok) return result
    const verification = result.data.data || {}
    if (verification.login_info) {
      const exchanged = await this.exchangeUserToken(verification.login_info)
      if (exchanged.ok) exchanged.logged_in = true
      return exchanged
    }
    return { ok: true, data: verification, logged_in: false }
  }

  async verifyPhoneCode(phone, code) {
    const normalized = String(phone || '').replace(/^\+?86/, '').replace(/[\s-]/g, '').trim()
    const result = await this.userRequest('/api/v1/user/phone/verify', { app_id: config.USER_SERVER_APP_ID, phone: normalized, code: String(code || '').trim() })
    if (!result.ok) return result
    const verification = result.data.data || {}
    if (verification.login_info) {
      const exchanged = await this.exchangeUserToken(verification.login_info)
      if (exchanged.ok) exchanged.logged_in = true
      return exchanged
    }
    return { ok: true, data: verification, logged_in: false }
  }

  async completeEmailRegistration(ticket, nickname, password, email) {
    const username = generateUsername(String(nickname || ''), String(email || ''))
    const result = await this.userRequest('/api/v1/user/email/complete-registration', {
      app_id: config.USER_SERVER_APP_ID,
      registration_ticket: String(ticket || ''),
      username,
      nickname: String(nickname || '').trim(),
      password,
    })
    if (!result.ok) return result
    return this.exchangeUserToken(result.data.data || {})
  }

  async completePhoneRegistration(ticket, nickname, password) {
    const result = await this.userRequest('/api/v1/user/phone/complete-registration', {
      app_id: config.USER_SERVER_APP_ID,
      registration_ticket: String(ticket || ''),
      nickname: String(nickname || '').trim(),
      password,
    })
    if (!result.ok) return result
    return this.exchangeUserToken(result.data.data || {})
  }

  async exchangeUserToken(loginData) {
    const token = String(loginData.token || '')
    if (!token) return { ok: false, error: 'USER_TOKEN_MISSING' }
    const result = await this.request('POST', '/v1/sessions/user-server', { token, locale: this.currentLocale || 'zh-CN' }, false, false)
    if (result.ok) {
      const user = loginData.user_info || loginData.user || loginData.profile || loginData
      this.session.update(Object.assign({}, result.data.data || {}, {
        username: user.nickname || user.username || user.name || user.display_name || '',
        avatar_url: user.avatar_url || user.avatar || user.avatarUrl || '',
        user_server_token: token,
        user_server_refresh_token: loginData.refresh_token || '',
      }))
    }
    return result
  }

  async updateUserProfile(nickname) {
    if (!this.session.data.user_id || !this.session.data.user_server_token) return { ok: false, error: 'USER_PROFILE_SESSION_MISSING' }
    const response = await this.fetchJson(`${config.USER_SERVER_BASE_URL}/api/v1/user/info/${encodeURIComponent(this.session.data.user_id)}`, {
      method: 'PUT',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json', Authorization: `Bearer ${this.session.data.user_server_token}` },
      body: JSON.stringify({ nickname: String(nickname || '').trim() }),
    }, 8000)
    return response.statusCode >= 200 && response.statusCode < 300 && response.data && Number(response.data.code) === 0
      ? { ok: true, data: response.data }
      : { ok: false, error: response.data && response.data.message ? response.data.message : 'USER_PROFILE_FAILED' }
  }

  async refreshUserProfile() {
    if (!this.session.data.user_id || !this.session.data.user_server_token) return { ok: false, error: 'USER_PROFILE_SESSION_MISSING' }
    const response = await this.fetchJson(`${config.USER_SERVER_BASE_URL}/api/v1/user/info/${encodeURIComponent(this.session.data.user_id)}`, {
      method: 'GET',
      headers: { Accept: 'application/json', Authorization: `Bearer ${this.session.data.user_server_token}` },
    }, 8000)
    if (!(response.statusCode >= 200 && response.statusCode < 300 && response.data && Number(response.data.code) === 0)) return { ok: false, error: response.data && response.data.message ? response.data.message : 'USER_PROFILE_UNAVAILABLE' }
    let profile = response.data.data || {}
    if (profile.user_info) profile = profile.user_info
    this.session.update({ username: profile.nickname || profile.username || profile.name || '', avatar_url: profile.avatar || profile.avatar_url || '' })
    return { ok: true, data: profile }
  }

  async refreshSession() {
    if (!this.session.data.refresh_token) return { ok: false, error: 'REFRESH_TOKEN_MISSING' }
    const result = await this.request('POST', '/v1/sessions/refresh', { refresh_token: this.session.data.refresh_token }, true, false)
    if (result.ok) this.session.update(result.data.data || {})
    else if ([400, 401, 403].includes(result.status) && /INVALID|EXPIRED|REVOKED|NOT_FOUND/.test(String(result.error).toUpperCase())) {
      this.session.clear()
      if (this.onSessionExpired) this.onSessionExpired()
    }
    return result
  }

  async logout() {
    if (this.session.hasToken() && this.session.data.refresh_token) await this.request('POST', '/v1/sessions/logout', { refresh_token: this.session.data.refresh_token }, true, false)
    if (this.session.data.user_server_refresh_token) {
      await this.userRequest('/api/v1/user/logout', { app_id: config.USER_SERVER_APP_ID, refresh_token: this.session.data.user_server_refresh_token }).catch(() => {})
    }
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

function generateUsername(nickname, email) {
  let candidate = ''
  if (email) {
    const at = email.indexOf('@')
    candidate = at > 0 ? email.slice(0, at) : email
  }
  if (!candidate && nickname) candidate = nickname
  candidate = candidate.replace(/[^A-Za-z0-9_]/g, '_').replace(/^_+|_+$/g, '')
  if (candidate.length < 3) candidate = (candidate + 'user').slice(0, 8)
  if (candidate.length > 32) candidate = candidate.slice(0, 32)
  const rand = Math.floor(Math.random() * 9000 + 1000)
  return `${candidate}_${rand}`
}

module.exports = { ApiClient }
