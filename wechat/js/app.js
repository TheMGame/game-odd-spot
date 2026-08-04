const config = require('./config')
const { Renderer, COLORS } = require('./core/renderer')
const { I18n } = require('./core/i18n')
const { KEYS, read, write, SessionStore, Preferences, ProgressStore } = require('./core/storage')
const { clamp, dateString, pointInPolygon, formatElapsed } = require('./core/utils')
const { ApiClient } = require('./services/api')
const { AudioManager } = require('./services/audio')
const { AssetManager } = require('./services/assets')
const { SyncQueue } = require('./services/sync_queue')
const { Analytics } = require('./services/analytics')
const { CatalogRepository } = require('./services/catalog')

class OddSpotApp {
  constructor() {
    this.canvas = wx.createCanvas()
    this.renderer = new Renderer(this.canvas)
    this.session = new SessionStore()
    this.preferences = new Preferences()
    this.i18n = new I18n(this.preferences)
    this.api = new ApiClient(this.session)
    this.api.currentLocale = this.preferences.data.locale
    this.progress = new ProgressStore(this.session)
    this.sync = new SyncQueue(this.api, this.session, this.progress)
    this.analytics = new Analytics(this.api, this.session, this.preferences)
    this.assets = new AssetManager()
    this.audio = new AudioManager(this.preferences)
    this.catalog = new CatalogRepository(this.api, this.preferences)
    this.scene = 'loading'
    this.status = this.i18n.t('loading')
    this.error = ''
    this.loadingProgress = 0.15
    this.catalogData = null
    this.covers = {}
    this.selectedSeriesId = ''
    this.selectedLevelId = ''
    this.scroll = { home: 0, levels: 0, settings: 0, privacy: 0 }
    this.modal = ''
    this.touch = null
    this.game = null
    this.logo = null
    this.avatar = null
    this.running = true
    this.frame = this.frame.bind(this)
    this.api.onSessionExpired = () => this.showLogin()
  }

  async start() {
    this.bindEvents()
    this.audio.start()
    this.assets.bundled('assets/branding/guagua-rabbit-logo.png').then((image) => { this.logo = image }).catch(() => {})
    this.assets.bundled('assets/branding/default-avatar.png').then((image) => { this.avatar = image }).catch(() => {})
    this.analytics.track('app_open')
    this.scheduleFrame()
    await this.bootstrap()
  }

  bindEvents() {
    wx.onTouchStart((event) => this.onTouchStart(event))
    wx.onTouchMove((event) => this.onTouchMove(event))
    wx.onTouchEnd((event) => this.onTouchEnd(event))
    wx.onTouchCancel((event) => this.onTouchEnd(event))
    wx.onWindowResize(() => this.renderer.resize())
    wx.onHide(() => { this.audio.pause(); if (this.game) this.saveAttempt() })
    wx.onShow(() => this.audio.resume())
  }

  scheduleFrame() {
    if (!this.running) return
    if (this.canvas.requestAnimationFrame) this.canvas.requestAnimationFrame(this.frame)
    else requestAnimationFrame(this.frame)
  }
  frame() { this.render(); this.scheduleFrame() }

  async bootstrap() {
    this.scene = 'loading'; this.loadingProgress = .15; this.status = this.i18n.t('loading'); this.error = ''
    if (!this.session.hasToken()) { this.showLogin(); return }
    if (!this.session.hasValidToken()) {
      this.loadingProgress = .35; this.status = '正在恢复登录状态…'
      const refreshed = await this.api.refreshSession()
      if (!refreshed.ok) { if (this.session.hasToken()) this.showBootstrapError(refreshed.error); else this.showLogin(); return }
    }
    this.loadingProgress = .55; this.status = '正在加载启动配置…'
    const result = await this.api.bootstrap()
    if (!result.ok) { this.showBootstrapError(result.error); return }
    const bootstrapData = result.data.data || {}
    if (bootstrapData.locale) {
      this.preferences.set('locale', bootstrapData.locale)
      this.api.currentLocale = bootstrapData.locale
    }
    this.loadingProgress = .82; this.status = '正在同步本地进度…'
    await this.sync.flush()
    this.loadingProgress = 1; this.status = '一切就绪'
    await this.showHome()
  }

  showBootstrapError(error) { this.scene = 'loading'; this.error = String(error || 'BOOTSTRAP_FAILED'); this.status = `暂时无法完成启动：${this.error}\n请检查网络后重试` }
  showFatalError(error) { this.scene = 'loading'; this.error = String(error && error.message ? error.message : error); this.status = `启动失败：${this.error}` }
  showLogin() { this.scene = 'login'; this.status = ''; this.error = ''; this.modal = '' }

  async loginWechat() {
    if (this.scene !== 'login' || this.loginBusy) return
    this.audio.click(); this.loginBusy = true; this.status = this.i18n.t('loggingIn')
    const result = await this.api.loginWechat()
    this.loginBusy = false
    if (!result.ok) { this.status = this.loginError(result.error, result.message); return }
    await this.bootstrap()
  }
  loginError(error, detail) {
    const messages = { WECHAT_LOGIN_UNAVAILABLE: '当前环境不支持微信登录', WECHAT_LOGIN_TIMEOUT: '微信登录超时，请重试', WECHAT_LOGIN_CODE_MISSING: '未能取得微信登录凭证，请重试', WECHAT_LOGIN_FAILED: '未能取得微信登录凭证，请重试', USER_SERVER_UNAVAILABLE: '用户服务暂时不可用', USER_TOKEN_MISSING: '用户服务返回的登录凭证不完整' }
    const message = messages[error] || String(error || '登录失败，请稍后再试')
    return detail ? `${message}\n${detail}` : message
  }

  async showHome() {
    this.scene = 'home'; this.status = '正在加载系列…'; this.scroll.home = 0; this.modal = ''; this.catalogData = null; this.covers = {}
    this.analytics.track('home_impression')
    const result = await this.catalog.get()
    if (!result.ok) { this.status = `系列加载失败：${result.error}`; return }
    this.catalogData = result.data.data || {}
    this.status = this.sync.pendingCount() ? `${this.sync.pendingCount()} 条进度等待联网同步` : this.i18n.t('syncDone')
    this.loadHomeCovers()
    this.sync.flush().then(() => { this.status = this.sync.pendingCount() ? `${this.sync.pendingCount()} 条进度等待联网同步` : this.i18n.t('syncDone') })
    this.analytics.flush()
    if (this.session.data.avatar_url) this.assets.loadUrl(this.session.data.avatar_url, 'avatar').then((image) => { this.avatar = image }).catch(() => {})
  }

  async loadHomeCovers() {
    for (const series of this.enabledSeries()) {
      const levels = Array.isArray(series.levels) ? series.levels : []
      const first = levels[0] || {}
      const preview = first.thumbnail_url || first.image_url || series.cover_url || ''
      const full = first.image_url || ''
      if (!preview) continue
      try { this.covers[series.id] = await this.assets.loadUrl(preview, 'series') } catch (_) {}
      if (full && full !== preview) try { this.covers[series.id] = await this.assets.loadUrl(full, 'series_full') } catch (_) {}
    }
  }

  enabledSeries() { return this.catalogData ? (Array.isArray(this.catalogData.series) ? this.catalogData.series : []).filter((series) => series.enabled !== false) : [] }
  seriesById(id) { return this.enabledSeries().find((series) => String(series.id) === String(id)) }

  async showLevelSelect(seriesId) {
    this.audio.click(); this.selectedSeriesId = seriesId; this.scene = 'levels'; this.scroll.levels = 0; this.modal = ''; this.analytics.track('series_click', { series_id: seriesId })
    if (!this.catalogData) { const result = await this.catalog.get(); if (result.ok) this.catalogData = result.data.data || {} }
    this.loadLevelPreviews()
  }
  async loadLevelPreviews() {
    const series = this.seriesById(this.selectedSeriesId); if (!series) return
    for (const level of series.levels || []) {
      const url = level.thumbnail_url || level.image_url
      if (!url || this.covers[`level:${level.id}`]) continue
      try { this.covers[`level:${level.id}`] = await this.assets.loadUrl(url, 'level_thumbnail') } catch (_) {}
    }
  }

  async openDaily() {
    const series = this.seriesById('daily_task')
    if (!series || !(series.levels || []).length) { this.status = '每日挑战系列中还没有已发布关卡'; return }
    this.selectedSeriesId = 'daily_task'; this.analytics.track('theme_click', { source: 'daily_challenge', level_id: series.levels[0].id, fallback: false }); await this.loadGame(series.levels[0].id)
  }

  async loadGame(levelId) {
    this.audio.click(); this.scene = 'game'; this.selectedLevelId = levelId; this.modal = ''; this.status = '加载关卡…'
    this.game = { loading: true, level: null, image: null, baseImage: null, found: {}, markers: [], attempt: null, startedAt: Date.now(), elapsedBefore: 0, imageRects: [], view: { zoom: 1, x: 0, y: 0 }, foundInfo: null, complete: false, finishing: false }
    const result = await this.api.getLevel(levelId)
    if (!result.ok) { this.status = `关卡加载失败：${result.error}`; return }
    const level = result.data.data || {}
    const validation = validateLevel(level)
    if (!validation.ok) { this.status = `关卡加载失败：${validation.error}`; return }
    this.game.level = level
    try {
      if (level.mode === 'find_anachronism') this.game.image = await this.assets.loadDescriptor(level.assets.image)
      else { this.game.baseImage = await this.assets.loadDescriptor(level.assets.base); this.game.image = await this.assets.loadDescriptor(level.assets.target) }
    } catch (error) { this.status = `图片加载失败：${error.message || error}`; return }
    const attempt = this.progress.getOrCreate(level.level_id, level.level_version)
    this.game.attempt = attempt; this.game.elapsedBefore = Number(attempt.elapsed_ms || 0); this.game.startedAt = Date.now()
    this.game.view = { zoom: Number(attempt.zoom || 1), x: Number(attempt.view_offset_x || 0), y: Number(attempt.view_offset_y || 0) }
    for (const id of attempt.found || []) {
      const difference = level.differences.find((item) => String(item.id) === String(id))
      if (difference) this.restoreFound(difference)
    }
    this.game.loading = false
    this.status = level.mode === 'find_anachronism' ? '滚轮或双指缩放 · 放大后拖动查看' : '找出所有不同之处；双指缩放，拖动查看'
    const started = await this.sync.submit(`/v1/levels/${encodeURIComponent(level.level_id)}/start`, { attempt_id: attempt.attempt_id, level_version: Number(level.level_version) }, attempt.start_idempotency_key)
    if (started.queued) this.status = '离线模式：进度将在后续同步'
    this.analytics.track('level_start', { level_id: level.level_id, level_version: level.level_version })
  }

  elapsed() { return this.game ? this.game.elapsedBefore + Date.now() - this.game.startedAt : 0 }
  containsDifference(difference, point) {
    if (difference.shape === 'circle') return Math.hypot(point.x - Number(difference.x), point.y - Number(difference.y)) <= Number(difference.radius) + .012
    if (difference.shape === 'polygon') return pointInPolygon(point, difference.points || [])
    return false
  }
  differenceCenter(difference) {
    if (difference.shape === 'circle') return { x: Number(difference.x), y: Number(difference.y) }
    const points = difference.points || []; return points.reduce((sum, point) => ({ x: sum.x + Number(point.x) / Math.max(points.length, 1), y: sum.y + Number(point.y) / Math.max(points.length, 1) }), { x: 0, y: 0 })
  }
  restoreFound(difference) { this.game.found[String(difference.id)] = true; this.game.markers.push({ point: this.differenceCenter(difference), at: 0 }) }
  pressGameImage(point) {
    if (!this.game || this.game.complete || this.game.loading) return
    for (const difference of this.game.level.differences) {
      const id = String(difference.id)
      if (!this.game.found[id] && this.containsDifference(difference, point)) { this.markFound(difference); return }
    }
    this.status = this.i18n.t('noDifference')
    this.analytics.track('wrong_tap', { level_id: this.game.level.level_id, x: point.x, y: point.y })
  }
  markFound(difference) {
    const id = String(difference.id); this.game.found[id] = true; this.game.markers.push({ point: this.differenceCenter(difference), at: Date.now() }); this.audio.correct()
    this.game.foundInfo = { title: `已找到：${difference.label || difference.id || '时代错误'}`, era: `${this.i18n.t('clue')}：${difference.era || '暂无线索'}`, reason: `${this.i18n.t('clueReasoning')}：${String(difference.explanation || '').trim() || '这条素材尚缺少推理说明，请通过举报反馈。'}` }
    this.status = this.i18n.t('found'); this.saveAttempt()
    if (this.preferences.data.vibration && wx.vibrateShort) wx.vibrateShort({ type: 'light' })
    this.analytics.track('difference_found', { level_id: this.game.level.level_id, difference_id: id, found_at_ms: this.elapsed() })
    this.sync.submit(`/v1/levels/${encodeURIComponent(this.game.level.level_id)}/progress`, { attempt_id: this.game.attempt.attempt_id, found: [{ difference_id: id, found_at_ms: this.elapsed() }], hints_used: Number(this.game.attempt.hints_used || 0), duration_ms: this.elapsed() })
    if (Object.keys(this.game.found).length === this.game.level.differences.length) this.finishAfterFeedback()
  }
  saveAttempt() {
    if (!this.game || !this.game.attempt || !this.game.level) return
    Object.assign(this.game.attempt, { found: Object.keys(this.game.found), elapsed_ms: this.elapsed(), zoom: this.game.view.zoom, view_offset_x: this.game.view.x, view_offset_y: this.game.view.y })
    this.progress.save(this.game.level.level_id, this.game.attempt)
  }
  businessDate() { return this.api.businessDate || dateString() }
  hintsRemaining() {
    const all = read(KEYS.hints, {}); const key = this.session.data.user_id; const record = all[key] || {}
    return record.date === this.businessDate() ? Math.max(0, config.DAILY_FREE_HINTS - Number(record.used || 0)) : config.DAILY_FREE_HINTS
  }
  consumeHint() {
    const all = read(KEYS.hints, {}), key = this.session.data.user_id, today = this.businessDate(), current = all[key] || {}
    all[key] = { date: today, used: current.date === today ? Number(current.used || 0) + 1 : 1 }; write(KEYS.hints, all)
  }
  useHint() {
    if (!this.game || this.game.loading || this.game.complete) return
    if (this.hintsRemaining() <= 0) { this.status = '今天的 3 次免费提示已经用完了'; this.modal = 'hintLimit'; return }
    const difference = this.game.level.differences.find((item) => !this.game.found[String(item.id)])
    if (!difference) return
    this.consumeHint(); this.game.attempt.hints_used = Number(this.game.attempt.hints_used || 0) + 1
    this.analytics.track('hint_request', { level_id: this.game.level.level_id, source: 'daily_free', remaining: this.hintsRemaining() })
    this.markFound(difference)
  }
  finishAfterFeedback() {
    if (this.game.finishing) return
    this.game.finishing = true
    setTimeout(() => this.audio.complete(), 180)
    setTimeout(() => this.finishLevel(), 1800)
  }
  async finishLevel() {
    if (!this.game) return
    const level = this.game.level, elapsed = this.elapsed()
    const result = await this.sync.submit(`/v1/levels/${encodeURIComponent(level.level_id)}/complete`, { attempt_id: this.game.attempt.attempt_id, difference_ids: Object.keys(this.game.found), hints_used: Number(this.game.attempt.hints_used || 0), duration_ms: elapsed })
    if (result.state === 'rejected') { this.status = `完成提交被服务器拒绝：${result.error}`; this.game.attempt.state = 'rejected'; this.progress.save(level.level_id, this.game.attempt); return }
    this.game.complete = true; this.game.syncState = result.state; this.game.attempt.elapsed_ms = elapsed; this.game.attempt.state = result.state === 'synced' ? 'synced' : 'sync_queued'; this.progress.save(level.level_id, this.game.attempt)
    this.analytics.track('level_complete', { level_id: level.level_id, duration_ms: elapsed, hints_used: this.game.attempt.hints_used, sync_state: result.state }); this.analytics.flush()
    this.prefetchNext()
  }
  nextLevelId() { const series = this.seriesById(this.selectedSeriesId); if (!series) return ''; const levels = series.levels || []; const index = levels.findIndex((item) => String(item.id) === String(this.selectedLevelId)); return index >= 0 && index + 1 < levels.length ? String(levels[index + 1].id) : '' }
  prefetchNext() { const next = this.nextLevelId(); if (!next) return; this.api.getLevel(next).then((result) => { const level = result.ok ? result.data.data : null; if (level && level.assets) { const descriptor = level.mode === 'find_anachronism' ? level.assets.image : level.assets.target; this.assets.loadDescriptor(descriptor).catch(() => {}) } }) }
  replay() { if (!this.game) return; const id = this.game.level.level_id; this.progress.clear(id); this.loadGame(id) }
  nextLevel() { const id = this.nextLevelId(); if (id) this.loadGame(id); else this.showLevelSelect(this.selectedSeriesId) }

  showSettings() { this.audio.click(); this.scene = 'settings'; this.scroll.settings = 0; this.modal = ''; this.loadLocales() }
  async loadLocales() { const result = await this.api.getLocales(); this.locales = result.ok ? ((result.data.data || {}).locales || []) : [{ locale: 'zh-CN', native_name: '简体中文' }, { locale: 'en-US', native_name: 'English' }] }
  async toggleLanguage() {
    const next = this.preferences.data.locale === 'zh-CN' ? 'en-US' : 'zh-CN'
    this.preferences.set('locale', next); this.preferences.set('localeMode', 'manual'); this.api.currentLocale = next; this.catalog.clear(); this.catalogData = null
    await this.api.updateLocale(next); this.status = next === 'zh-CN' ? '语言已更新' : 'Language updated'
  }
  async logout() { this.audio.click(); await this.api.logout(); this.showLogin() }

  render() {
    const r = this.renderer; r.begin()
    if (this.scene === 'loading') this.renderLoading()
    else if (this.scene === 'login') this.renderLogin()
    else if (this.scene === 'home') this.renderHome()
    else if (this.scene === 'levels') this.renderLevels()
    else if (this.scene === 'settings') this.renderSettings()
    else if (this.scene === 'game') this.renderGame()
    if (this.modal) this.renderModal()
  }

  renderLoading() {
    const r = this.renderer, h = r.height
    if (this.logo) r.image(this.logo, { x: 390, y: h * .22, w: 300, h: 300 }, 'contain')
    r.text(this.i18n.t('app'), 540, h * .44, 62, COLORS.gold, 'center', 'bold')
    r.wrappedText(this.status, 540, h * .55, 800, 28, COLORS.muted, 42, 4, 'center')
    r.progress(180, h * .65, 720, 18, this.loadingProgress, 1)
    if (this.error) r.button('retry', { x: 300, y: h * .72, w: 480, h: 92 }, this.i18n.t('retry'), { fill: COLORS.cinnabar, border: COLORS.gold, size: 30 })
  }
  renderLogin() {
    const r = this.renderer, h = r.height
    if (this.logo) r.image(this.logo, { x: 390, y: 90, w: 300, h: 250 }, 'contain')
    r.text(this.i18n.t('app'), 540, 390, 60, COLORS.gold, 'center', 'bold')
    r.text(this.i18n.t('tagline'), 540, 465, 25, COLORS.muted, 'center')
    const card = { x: 64, y: 570, w: 952, h: 480 }
    r.rect(card.x, card.y, card.w, card.h, COLORS.card, 24, COLORS.cardBorder, 2)
    r.text(this.i18n.t('wechatTitle'), 110, 635, 40, COLORS.paper, 'left', 'bold')
    r.wrappedText(this.i18n.t('wechatDescription'), 110, 715, 860, 25, COLORS.muted, 38, 4)
    r.button('wechatLogin', { x: 110, y: 840, w: 860, h: 96 }, this.loginBusy ? this.i18n.t('loggingIn') : this.i18n.t('wechatLogin'), { fill: COLORS.cinnabar, border: COLORS.gold, size: 30, disabled: this.loginBusy })
    if (this.status) r.wrappedText(this.status, 540, 990, 820, 22, '#d9ad64', 32, 3, 'center')
    r.text(this.i18n.t('loginAgreement'), 540, Math.min(h - 70, 1150), 18, '#9bb5b0', 'center')
  }
  renderHome() {
    const r = this.renderer, h = r.height
    const identity = this.session.data.username || `玩家 · ${String(this.session.data.user_id || '').slice(-6)}`
    const identityRect = { x: 38, y: 44, w: 300, h: 76 }
    r.rect(identityRect.x, identityRect.y, identityRect.w, identityRect.h, '#1b4350', 18, COLORS.cardBorder, 1)
    if (this.avatar) {
      const c = r.ctx; c.save(); c.beginPath(); c.arc(77, 82, 25, 0, Math.PI * 2); c.clip(); r.image(this.avatar, { x: 52, y: 57, w: 50, h: 50 }, 'cover'); c.restore()
    }
    r.text(identity, 112, 82, 25, COLORS.paper, 'left', 'normal', 208); r.register('identity', identityRect)
    r.button('daily', { x: 430, y: 44, w: 220, h: 76 }, this.i18n.t('daily'), { fill: '#3f7565', border: '#8bb09f', size: 28 })
    r.iconButton('settings', 946, 34, 96, 'settings')
    const clip = { x: 38, y: 150, w: 1004, h: h - 250 }; const c = r.ctx; c.save(); c.beginPath(); c.rect(clip.x, clip.y, clip.w, clip.h); c.clip()
    let y = clip.y - this.scroll.home
    if (!this.catalogData) r.text(this.status, 540, 260, 28, COLORS.muted, 'center')
    for (const series of this.enabledSeries()) {
      const levels = Array.isArray(series.levels) ? series.levels : []
      const rect = { x: 38, y, w: 1004, h: 450 }
      r.rect(rect.x, rect.y, rect.w, rect.h, COLORS.card, 22, '#d9aa4f', 3)
      if (this.covers[series.id]) r.image(this.covers[series.id], { x: rect.x + 3, y: rect.y + 3, w: rect.w - 6, h: 300 }, 'cover')
      r.text(series.title || series.display_name || series.id, rect.x + 24, rect.y + 345, 34, COLORS.gold, 'left', 'bold', 650)
      const detail = `${levels.length} ${this.i18n.t('levels')}${series.description ? ` · ${series.description}` : ''}`
      r.text(detail, rect.x + 24, rect.y + 402, 25, COLORS.muted, 'left', 'normal', 680)
      if (rect.y + rect.h >= clip.y && rect.y <= clip.y + clip.h) r.register(`series:${series.id}`, rect)
      if (rect.y + rect.h >= clip.y && rect.y <= clip.y + clip.h) r.button(`series:${series.id}`, { x: rect.x + rect.w - 156, y: rect.y + 342, w: 128, h: 80 }, this.i18n.t('enter'), { fill: '#3f7565', border: '#8bb09f', size: 28 })
      y += 472
    }
    c.restore(); this.maxScroll = Math.max(0, y + this.scroll.home - clip.y - clip.h)
    r.text(this.status, 540, h - 60, 20, '#a8c2bd', 'center')
  }
  renderLevels() {
    const r = this.renderer, h = r.height, series = this.seriesById(this.selectedSeriesId)
    r.iconButton('home', 28, 34, 96, 'back'); r.iconButton('settings', 956, 34, 96, 'settings')
    r.text(series ? series.title : '系列关卡', 540, 68, 42, COLORS.gold, 'center', 'bold')
    if (series && series.description) r.text(series.description, 540, 112, 23, COLORS.muted, 'center', 'normal', 760)
    const levels = series && Array.isArray(series.levels) ? series.levels : []
    let firstUnfinished = levels.findIndex((level) => !this.isLevelCompleted(level)); if (firstUnfinished < 0) firstUnfinished = levels.length
    const clip = { x: 28, y: 155, w: 1024, h: h - 180 }; const c = r.ctx; c.save(); c.beginPath(); c.rect(clip.x, clip.y, clip.w, clip.h); c.clip(); let y = clip.y - this.scroll.levels
    levels.forEach((level, index) => {
      const completed = this.isLevelCompleted(level), locked = this.selectedSeriesId !== 'daily_task' && !completed && index > firstUnfinished
      const rect = { x: 28, y, w: 1024, h: 250 }; r.rect(rect.x, rect.y, rect.w, rect.h, locked ? '#183039' : COLORS.card, 18, locked ? '#52666b' : '#c49a4a', 2)
      if (this.covers[`level:${level.id}`]) r.image(this.covers[`level:${level.id}`], { x: rect.x + 16, y: rect.y + 16, w: 250, h: 218 }, 'cover')
      const tx = rect.x + 292
      r.text(`第 ${String(index + 1).padStart(2, '0')} 关`, tx, rect.y + 38, 26, '#d2ad69')
      r.wrappedText(level.title || level.id, tx, rect.y + 90, 650, 35, locked ? 'rgba(243,232,207,.38)' : COLORS.paper, 45, 2)
      r.text(`${Number(level.difference_count || 0)} ${this.i18n.t('targets')}`, tx, rect.y + 166, 25, COLORS.muted)
      r.text(`${this.i18n.t('difficulty')} ${'◆'.repeat(clamp(Number(level.difficulty || 1), 1, 5))}`, tx, rect.y + 205, 25, locked ? '#555' : COLORS.cinnabar)
      r.text(completed ? this.i18n.t('completed') : locked ? this.i18n.t('locked') : this.i18n.t('current'), rect.x + rect.w - 30, rect.y + 205, 25, completed ? COLORS.jade : COLORS.gold, 'right')
      if (rect.y + rect.h >= clip.y && rect.y <= clip.y + clip.h) r.register(locked ? `locked:${level.id}` : `level:${level.id}`, rect)
      y += 268
    })
    c.restore(); this.maxScroll = Math.max(0, y + this.scroll.levels - clip.y - clip.h)
  }
  isLevelCompleted(level) { return Boolean(level.completed) || this.progress.isCompleted(String(level.id), Number(level.version || 1)) }

  renderSettings() {
    const r = this.renderer, h = r.height
    r.iconButton('home', 28, 26, 80, 'back'); r.text(this.i18n.t('settings'), 540, 56, 44, COLORS.gold, 'center', 'bold'); r.text(this.i18n.t('settingsSubtitle'), 540, 104, 21, COLORS.muted, 'center')
    const clip = { x: 36, y: 145, w: 1008, h: h - 165 }, c = r.ctx; c.save(); c.beginPath(); c.rect(clip.x, clip.y, clip.w, clip.h); c.clip(); let y = clip.y - this.scroll.settings
    const section = (title) => { r.text(title, 36, y + 24, 24, '#d7aa57'); y += 54 }
    section(this.i18n.t('account')); r.rect(36, y, 1008, 205, COLORS.card, 20, COLORS.cardBorder, 1); r.text(this.session.data.username || this.i18n.t('signedIn'), 66, y + 55, 32, COLORS.paper, 'left', 'bold'); r.wrappedText(this.i18n.t('accountDesc'), 66, y + 112, 940, 22, COLORS.muted, 32, 3); y += 235
    section(this.i18n.t('gameExperience')); r.rect(36, y, 1008, 620, COLORS.card, 20, COLORS.cardBorder, 1)
    r.toggle('toggle:vibration', 70, y + 25, this.i18n.t('vibration'), this.preferences.data.vibration)
    r.toggle('toggle:music', 70, y + 145, this.i18n.t('music'), this.preferences.data.music)
    r.toggle('toggle:effects', 70, y + 265, this.i18n.t('effects'), this.preferences.data.effects)
    r.toggle('toggle:largeMarkers', 70, y + 385, this.i18n.t('largeMarkers'), this.preferences.data.largeMarkers)
    r.text(this.i18n.t('language'), 70, y + 555, 28, COLORS.paper); r.button('language', { x: 680, y: y + 512, w: 320, h: 78 }, this.preferences.data.locale === 'zh-CN' ? '简体中文' : 'English', { fill: '#255462', border: '#81a59f', size: 24 }); y += 650
    section(this.i18n.t('privacySupport')); r.rect(36, y, 1008, 340, COLORS.card, 20, COLORS.cardBorder, 1)
    r.toggle('toggle:analytics', 70, y + 20, this.i18n.t('analytics'), this.preferences.data.analytics); r.wrappedText(this.i18n.t('analyticsNote'), 70, y + 130, 890, 20, COLORS.muted, 30, 2)
    r.button('privacy', { x: 70, y: y + 220, w: 930, h: 78 }, this.i18n.t('privacyPolicy'), { fill: '#1b4350', border: COLORS.cardBorder, size: 24 }); y += 375
    r.button('logout', { x: 36, y, w: 1008, h: 76 }, this.i18n.t('logout'), { fill: '#1b4350', border: COLORS.cardBorder, color: '#d5614e', size: 24 }); y += 105
    r.text(`${this.i18n.t('app')} · 版本 ${config.APP_VERSION}`, 540, y, 18, '#94aeaa', 'center'); y += 55
    if (this.status) r.text(this.status, 540, y, 20, '#d8b470', 'center')
    c.restore(); this.maxScroll = Math.max(0, y + this.scroll.settings - clip.y - clip.h)
  }

  renderGame() {
    const r = this.renderer, h = r.height, game = this.game
    r.iconButton('levels', 14, 12, 96, 'back')
    r.text(game && game.level ? game.level.title || '时代寻错' : '加载关卡', 540, 52, 42, COLORS.gold, 'center', 'bold', 660)
    const total = game && game.level ? game.level.differences.length : 0, found = game ? Object.keys(game.found).length : 0
    r.text(`${found} / ${total}`, 540, 96, 27, '#d6e3df', 'center'); r.iconButton('hint', 956, 12, 96, 'hint', true, found === total && total > 0)
    r.progress(18, 125, 1044, 16, found, total || 1)
    if (!game || game.loading || !game.level || !game.image) { r.text(this.status, 540, 320, 28, COLORS.muted, 'center'); return }
    r.text(game.level.instruction || '圈出不属于这个年代的物件', 540, 175, 29, '#caaa66', 'center', 'normal', 940)
    const bottomReserve = game.foundInfo ? 330 : 110
    const imageTop = 215, imageBottom = h - bottomReserve, available = Math.max(300, imageBottom - imageTop)
    game.imageRects = []
    if (game.level.mode === 'spot_difference') {
      const each = (available - 16) / 2
      game.imageRects.push(this.renderGameImage(game.baseImage, { x: 18, y: imageTop, w: 1044, h: each }, game, 0))
      game.imageRects.push(this.renderGameImage(game.image, { x: 18, y: imageTop + each + 16, w: 1044, h: each }, game, 1))
    } else game.imageRects.push(this.renderGameImage(game.image, { x: 18, y: imageTop, w: 1044, h: available }, game, 0))
    if (game.foundInfo) {
      const y = h - 300; r.rect(18, y, 1044, 225, '#eadbbd', 14, '#a53b2b', 2)
      r.text(game.foundInfo.title, 42, y + 42, 36, '#d47b48', 'left', 'bold', 990); r.text(game.foundInfo.era, 42, y + 91, 27, '#886e48', 'left', 'normal', 990); r.wrappedText(game.foundInfo.reason, 42, y + 140, 990, 27, '#2b3335', 37, 3)
    }
    r.text(this.status, 540, h - 35, 25, '#c2d3cf', 'center', 'normal', 980)
    if (game.complete) this.renderComplete()
  }
  renderGameImage(image, rect, game) {
    const r = this.renderer; r.rect(rect.x, rect.y, rect.w, rect.h, COLORS.card, 14, '#d9aa4f', 3)
    const inner = { x: rect.x + 4, y: rect.y + 4, w: rect.w - 8, h: rect.h - 8 }
    const draw = r.image(image, inner, 'contain', game.view.zoom, { x: game.view.x, y: game.view.y })
    if (draw) for (const marker of game.markers) this.renderMarker(draw, marker)
    return { panel: inner, draw }
  }
  renderMarker(draw, marker) {
    const r = this.renderer, center = { x: draw.x + marker.point.x * draw.w, y: draw.y + marker.point.y * draw.h }, radius = this.preferences.data.largeMarkers ? 38 : 28
    const age = marker.at ? Math.min(1, (Date.now() - marker.at) / 1000) : 1
    if (age < .65) r.circle(center.x, center.y, radius + age * 75, 'rgba(0,0,0,0)', `rgba(245,173,56,${.75 - age})`, 4)
    const pulse = age < 1 ? 1 + Math.sin(age * 9) * .08 : 1
    r.circle(center.x, center.y, radius * pulse, 'rgba(168,36,20,.20)', '#c64b2f', 5); r.circle(center.x, center.y, radius * pulse + 4, 'rgba(0,0,0,0)', 'rgba(242,171,64,.72)', 2)
  }
  renderComplete() {
    const r = this.renderer, h = r.height; r.rect(0, 0, 1080, h, 'rgba(4,9,13,.78)')
    const rect = { x: 245, y: h / 2 - 285, w: 590, h: 570 }; r.rect(rect.x, rect.y, rect.w, rect.h, '#eadbbd', 24, '#d0a04c', 4)
    r.text(this.i18n.t('complete'), 540, rect.y + 115, 72, '#b33321', 'center', 'bold')
    r.text(this.game.syncState === 'synced' ? this.i18n.t('allFound') : this.i18n.t('localComplete'), 540, rect.y + 225, 32, '#2e2921', 'center')
    r.text(`发现 ${Object.keys(this.game.found).length}/${this.game.level.differences.length} · 提示 ${this.game.attempt.hints_used || 0} · 用时 ${formatElapsed(this.game.attempt.elapsed_ms)}`, 540, rect.y + 295, 22, '#574d3d', 'center')
    r.iconButton('replay', 340, rect.y + 380, 88, 'replay'); r.iconButton('map', 496, rect.y + 380, 88, 'map'); r.iconButton('next', 648, rect.y + 376, 96, 'next', true)
  }

  renderModal() {
    const r = this.renderer, h = r.height; r.rect(0, 0, 1080, h, 'rgba(3,7,10,.82)')
    if (this.modal === 'locked') {
      const rect = { x: 180, y: h / 2 - 305, w: 720, h: 610 }; r.rect(rect.x, rect.y, rect.w, rect.h, COLORS.paper, 24, COLORS.gold, 4)
      r.text('· 案件锁定 ·', 540, rect.y + 60, 27, COLORS.cinnabar, 'center'); r.circle(540, rect.y + 155, 52, '#8f352c', COLORS.gold, 4); r.text('锁', 540, rect.y + 157, 40, COLORS.paper, 'center')
      r.text(this.i18n.t('lockedTitle'), 540, rect.y + 265, 40, COLORS.ink, 'center', 'bold'); r.wrappedText(this.i18n.t('lockedMessage'), 540, rect.y + 340, 620, 27, '#725c45', 40, 4, 'center')
      r.button('modalClose', { x: 230, y: rect.y + 475, w: 620, h: 82 }, this.i18n.t('continueExplore'), { fill: '#ad3f30', border: COLORS.gold, size: 30 })
    } else if (this.modal === 'hintLimit') {
      const rect = { x: 190, y: h / 2 - 295, w: 700, h: 590 }; r.rect(rect.x, rect.y, rect.w, rect.h, '#f3e5c4', 30, '#d5a84d', 5)
      r.text('· 线索 ·', 540, rect.y + 50, 30, '#c4772e', 'center'); r.iconButton('', 476, rect.y + 80, 128, 'hint', true, true)
      r.text(this.i18n.t('hintLimitUsage'), 540, rect.y + 240, 30, '#a33826', 'center'); r.text(this.i18n.t('hintLimitTitle'), 540, rect.y + 305, 44, '#30291f', 'center', 'bold')
      r.wrappedText(this.i18n.t('hintLimitMessage'), 540, rect.y + 365, 610, 28, '#574a3b', 40, 3, 'center'); r.button('modalClose', { x: 235, y: rect.y + 475, w: 610, h: 82 }, this.i18n.t('continueSearching'), { fill: '#a33d2e', border: '#f2cf78', size: 31 })
    } else if (this.modal === 'privacy') {
      const rect = { x: 42, y: 80, w: 996, h: h - 160 }; r.rect(rect.x, rect.y, rect.w, rect.h, COLORS.card, 24, COLORS.gold, 2)
      r.text(this.i18n.t('privacyPolicy'), 540, rect.y + 58, 38, COLORS.gold, 'center', 'bold')
      const clip = { x: 76, y: rect.y + 105, w: 928, h: rect.h - 220 }, c = r.ctx; c.save(); c.beginPath(); c.rect(clip.x, clip.y, clip.w, clip.h); c.clip(); const textHeight = r.wrappedText(this.i18n.t('privacy'), clip.x, clip.y + 20 - this.scroll.privacy, clip.w, 23, COLORS.muted, 35, 200); c.restore(); this.privacyMaxScroll = Math.max(0, textHeight - clip.h + 40)
      r.button('modalClose', { x: 200, y: rect.y + rect.h - 95, w: 680, h: 70 }, this.i18n.t('privacyClose'), { fill: COLORS.cinnabar, border: COLORS.gold, size: 26 })
    }
  }

  onTouchStart(event) {
    const points = Array.from(event.touches || []).map((touch) => this.renderer.logicalTouch(touch)); if (!points.length) return
    const point = points[0], hit = this.renderer.hit(point)
    this.touch = { start: point, last: point, moved: 0, hit, points, scrollStart: this.currentScroll(), gameViewStart: this.game ? Object.assign({}, this.game.view) : null, pinchDistance: points.length >= 2 ? distance(points[0], points[1]) : 0, pinchZoom: this.game ? this.game.view.zoom : 1 }
  }
  onTouchMove(event) {
    if (!this.touch) return
    const points = Array.from(event.touches || []).map((touch) => this.renderer.logicalTouch(touch)); if (!points.length) return
    const point = points[0], dy = point.y - this.touch.start.y, dx = point.x - this.touch.start.x; this.touch.moved = Math.max(this.touch.moved, Math.hypot(dx, dy)); this.touch.last = point; this.touch.points = points
    if (this.modal === 'privacy') { this.scroll.privacy = clamp(this.touch.scrollStart - dy, 0, this.privacyMaxScroll || 0); return }
    if (!this.modal && ['home', 'levels', 'settings'].includes(this.scene)) { this.setCurrentScroll(clamp(this.touch.scrollStart - dy, 0, this.maxScroll || 0)); return }
    if (!this.modal && this.scene === 'game' && this.game && this.game.imageRects.some((item) => item && inside(point, item.panel))) {
      if (points.length >= 2 && this.touch.pinchDistance > 1) {
        const next = clamp(this.touch.pinchZoom * distance(points[0], points[1]) / this.touch.pinchDistance, 1, 4); this.game.view.zoom = next
      } else if (this.game.view.zoom > 1) { this.game.view.x = this.touch.gameViewStart.x + dx; this.game.view.y = this.touch.gameViewStart.y + dy; this.clampGameView() }
    }
  }
  onTouchEnd() {
    if (!this.touch) return
    const touch = this.touch; this.touch = null
    if (this.scene === 'game' && this.game) this.saveAttempt()
    if (touch.moved > 12) return
    if (this.modal && (!touch.hit || touch.hit.id !== 'modalClose')) return
    const hit = touch.hit || this.renderer.hit(touch.last)
    if (hit) { this.handleAction(hit.id, hit.data); return }
    if (this.scene === 'game' && this.game && !this.modal) {
      for (const item of this.game.imageRects) if (item && item.draw && inside(touch.last, item.panel) && inside(touch.last, item.draw)) { this.pressGameImage({ x: (touch.last.x - item.draw.x) / item.draw.w, y: (touch.last.y - item.draw.y) / item.draw.h }); return }
    }
  }
  currentScroll() { return this.modal === 'privacy' ? this.scroll.privacy : this.scroll[this.scene] || 0 }
  setCurrentScroll(value) { if (this.scroll[this.scene] != null) this.scroll[this.scene] = value }
  clampGameView() {
    if (!this.game || this.game.view.zoom <= 1.001) { if (this.game) { this.game.view.x = 0; this.game.view.y = 0 }; return }
    const rect = this.game.imageRects[0]; if (!rect || !rect.draw) return
    const limitX = Math.max(0, (rect.draw.w - rect.panel.w) / 2), limitY = Math.max(0, (rect.draw.h - rect.panel.h) / 2)
    this.game.view.x = clamp(this.game.view.x, -limitX, limitX); this.game.view.y = clamp(this.game.view.y, -limitY, limitY)
  }
  handleAction(id) {
    if (this.scene === 'game' && this.game && this.game.complete && !['replay', 'map', 'next'].includes(id)) return
    if (id) this.audio.click()
    if (id === 'retry') this.bootstrap()
    else if (id === 'wechatLogin') this.loginWechat()
    else if (id === 'identity' || id === 'settings') this.showSettings()
    else if (id === 'daily') this.openDaily()
    else if (id === 'home') this.showHome()
    else if (id === 'levels') this.showLevelSelect(this.selectedSeriesId)
    else if (id.startsWith('series:')) this.showLevelSelect(id.slice(7))
    else if (id.startsWith('level:')) this.loadGame(id.slice(6))
    else if (id.startsWith('locked:')) this.modal = 'locked'
    else if (id === 'hint') this.useHint()
    else if (id === 'replay') this.replay()
    else if (id === 'map') this.showLevelSelect(this.selectedSeriesId)
    else if (id === 'next') this.nextLevel()
    else if (id === 'language') this.toggleLanguage()
    else if (id === 'privacy') { this.scroll.privacy = 0; this.modal = 'privacy' }
    else if (id === 'logout') this.logout()
    else if (id === 'modalClose') this.modal = ''
    else if (id.startsWith('toggle:')) this.togglePreference(id.slice(7))
  }
  togglePreference(key) {
    const enabled = !this.preferences.data[key]
    if (key === 'music') this.audio.setMusic(enabled)
    else if (key === 'effects') this.audio.setEffects(enabled)
    else if (key === 'analytics') this.analytics.setEnabled(enabled)
    else this.preferences.set(key, enabled)
  }
}

function validateLevel(level) {
  if (!level || !level.level_id) return { ok: false, error: 'LEVEL_ID_MISSING' }
  if (Number(level.schema_version) !== 1) return { ok: false, error: 'LEVEL_SCHEMA_UNSUPPORTED' }
  if (!['spot_difference', 'find_anachronism'].includes(level.mode)) return { ok: false, error: 'LEVEL_MODE_UNSUPPORTED' }
  if (!level.assets || Number(level.assets.width) < 1 || Number(level.assets.width) > 8192 || Number(level.assets.height) < 1 || Number(level.assets.height) > 8192) return { ok: false, error: 'LEVEL_ASSETS_INVALID' }
  const required = level.mode === 'find_anachronism' ? ['image'] : ['base', 'target']
  for (const key of required) if (!level.assets[key] || !level.assets[key].asset_id || !String(level.assets[key].url || '').startsWith('https://')) return { ok: false, error: `LEVEL_ASSET_INVALID_${key.toUpperCase()}` }
  if (!Array.isArray(level.differences) || level.differences.length < 3 || level.differences.length > 12) return { ok: false, error: 'LEVEL_DIFFERENCES_INVALID' }
  const ids = new Set()
  for (const difference of level.differences) {
    if (!difference.id || ids.has(String(difference.id))) return { ok: false, error: 'LEVEL_DIFFERENCE_ID_INVALID' }; ids.add(String(difference.id))
    if (difference.shape === 'circle') { if (![difference.x, difference.y, difference.radius].every(Number.isFinite) || difference.x < 0 || difference.x > 1 || difference.y < 0 || difference.y > 1 || difference.radius <= 0 || difference.radius > .25) return { ok: false, error: 'LEVEL_CIRCLE_INVALID' } }
    else if (difference.shape === 'polygon') { if (!Array.isArray(difference.points) || difference.points.length < 3 || difference.points.some((point) => !Number.isFinite(point.x) || !Number.isFinite(point.y))) return { ok: false, error: 'LEVEL_POLYGON_INVALID' } }
    else return { ok: false, error: 'LEVEL_SHAPE_UNSUPPORTED' }
  }
  return { ok: true }
}
function inside(point, rect) { return point.x >= rect.x && point.x <= rect.x + rect.w && point.y >= rect.y && point.y <= rect.y + rect.h }
function distance(a, b) { return Math.hypot(a.x - b.x, a.y - b.y) }

module.exports = { OddSpotApp, validateLevel }
