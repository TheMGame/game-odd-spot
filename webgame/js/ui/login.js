class LoginView {
  constructor(app) {
    this.app = app
    this.root = document.getElementById('login-panel')
    this.userPanel = document.getElementById('user-panel')
    this.form = document.getElementById('login-form')
    this.registration = document.getElementById('registration-form')
    this.profile = document.getElementById('registration-profile')
    this.statusNode = document.getElementById('login-status')
    this.userStatusNode = document.getElementById('user-status')
    this.ticket = ''
    this.registerAvatarURL = ''
    this.currentMode = 'phone'
    this.h5PhoneOneClickReady = false
    this.h5PhoneOneClickFailed = false
    this.bind()
    this.initAvatarUploaders()
    this.setMode(this.currentMode)
  }

  bind() {
    document.getElementById('tab-email').addEventListener('click', () => this.setMode('email'))
    document.getElementById('tab-phone').addEventListener('click', () => this.setMode('phone'))
    document.getElementById('login-submit').addEventListener('click', () => this.login())
    document.getElementById('phone-oneclick-login').addEventListener('click', () => this.runH5OneClick(false))
    document.getElementById('phone-oneclick-register').addEventListener('click', () => this.runH5OneClick(true))
    document.getElementById('show-registration').addEventListener('click', () => this.showRegistration())
    document.getElementById('back-to-login').addEventListener('click', () => this.showLogin())
    document.getElementById('send-code').addEventListener('click', () => this.sendCode())
    document.getElementById('verify-code').addEventListener('click', () => this.verifyCode())
    document.getElementById('complete-registration').addEventListener('click', () => this.completeRegistration())

    document.getElementById('user-save-profile').addEventListener('click', () => this.saveUserProfile())
    document.getElementById('user-close-panel').addEventListener('click', () => this.hideUserPanel())
    document.getElementById('user-logout').addEventListener('click', async () => {
      this.app.audio.click()
      await this.app.api.logout()
      this.hideUserPanel()
      this.show()
    })

    this.root.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return
      if (!this.form.hidden) this.login()
      else if (!this.profile.hidden) this.completeRegistration()
      else this.verifyCode()
    })
  }

  initAvatarUploaders() {
    const registerUploader = document.getElementById('register-avatar-uploader')
    const registerFile = document.getElementById('register-avatar-file')
    const registerPreview = document.getElementById('register-avatar-preview')
    registerUploader.addEventListener('click', () => registerFile.click())
    registerFile.addEventListener('change', (e) => {
      const file = e.target.files && e.target.files[0]
      if (!file) return
      const reader = new FileReader()
      reader.onload = () => {
        registerPreview.innerHTML = ''
        const img = document.createElement('img')
        img.src = reader.result
        registerPreview.appendChild(img)
      }
      reader.readAsDataURL(file)
      this.registerAvatarFile = file
    })

    const userUploader = document.getElementById('user-avatar-uploader')
    const userFile = document.getElementById('user-avatar-file')
    userUploader.addEventListener('click', () => userFile.click())
    userFile.addEventListener('change', async (e) => {
      const file = e.target.files && e.target.files[0]
      if (!file) return
      this.app.audio.click()
      this.setUserStatus('正在上传头像…', false)
      const result = await this.app.api.uploadUserAvatar(file)
      if (!result.ok) { this.setUserStatus(`上传失败：${result.error || '未知错误'}`, true); return }
      this.setUserStatus('头像上传成功')
      this.refreshUserAvatarPreview()
      await this.app.api.refreshUserProfile().catch(() => {})
      if (this.app.updateUserHeader) this.app.updateUserHeader()
    })
  }

  refreshUserAvatarPreview() {
    const preview = document.getElementById('user-avatar-preview')
    const url = this.app.session.data.avatar_url || ''
    preview.innerHTML = ''
    if (url) {
      const img = document.createElement('img')
      img.src = url
      preview.appendChild(img)
    } else {
      preview.innerHTML = '<span class="avatar-placeholder">+</span>'
    }
  }

  setMode(mode) {
    this.currentMode = mode
    document.querySelectorAll('.tab-btn').forEach(btn => {
      const active = btn.dataset.mode === mode
      btn.classList.toggle('active', active)
      btn.setAttribute('aria-selected', active ? 'true' : 'false')
    })
    const isPhone = mode === 'phone'
    const emailLabel = '邮箱'
    const phoneLabel = '手机号'
    const loginAccountInput = document.getElementById('login-email')
    const registerAccountInput = document.getElementById('register-email')

    document.querySelector('#label-login-account').firstChild.textContent = isPhone ? phoneLabel : emailLabel
    loginAccountInput.type = isPhone ? 'tel' : 'email'
    loginAccountInput.inputMode = isPhone ? 'numeric' : 'email'
    loginAccountInput.placeholder = isPhone ? '11 位手机号' : 'name@example.com'
    loginAccountInput.setAttribute('autocomplete', isPhone ? 'tel' : 'email')
    loginAccountInput.value = ''

    document.querySelector('#label-register-account').firstChild.textContent = isPhone ? phoneLabel : emailLabel
    registerAccountInput.type = isPhone ? 'tel' : 'email'
    registerAccountInput.inputMode = isPhone ? 'numeric' : 'email'
    registerAccountInput.placeholder = isPhone ? '11 位手机号' : 'name@example.com'
    registerAccountInput.value = ''

    const showRegBtn = document.getElementById('show-registration')
    showRegBtn.textContent = showRegBtn.dataset[isPhone ? 'textPhone' : 'textEmail']

    const sendBtn = document.getElementById('send-code')
    sendBtn.textContent = sendBtn.dataset[isPhone ? 'textPhone' : 'textEmail']

    const verifyBtn = document.getElementById('verify-code')
    verifyBtn.textContent = verifyBtn.dataset[isPhone ? 'textPhone' : 'textEmail']

    const title = document.getElementById('login-title').textContent
    if (title.includes('创建')) {
      document.getElementById('login-description').textContent = isPhone
        ? '验证手机号后设置密码，昵称可稍后完善。'
        : '验证邮箱后设置密码，昵称可稍后完善。'
    } else {
      document.getElementById('login-description').textContent = isPhone
        ? '使用手机号和密码登录，同步关卡进度与游戏权益。'
        : '使用邮箱和密码登录，同步关卡进度与游戏权益。'
    }
    if (isPhone) {
      if (!this.h5PhoneOneClickFailed && !this.h5PhoneOneClickReady) {
        this.tryEnableH5OneClick().catch(() => {})
      } else {
        this.updateOneClickButtons(this.h5PhoneOneClickReady)
      }
    } else {
      this.updateOneClickButtons(false)
    }
  }

  updateOneClickButtons(visible) {
    const loginBtn = document.getElementById('phone-oneclick-login')
    const registerBtn = document.getElementById('phone-oneclick-register')
    if (loginBtn) loginBtn.hidden = !visible
    if (registerBtn) registerBtn.hidden = !visible
  }

  async tryEnableH5OneClick() {
    this.h5PhoneOneClickFailed = false
    const available = this.h5OneClickEnvironmentAvailable()
    if (!available) {
      this.h5PhoneOneClickFailed = true
      this.updateOneClickButtons(false)
      return
    }
    try {
      const info = await this.fetchH5AuthInfo()
      if (!info) {
        this.h5PhoneOneClickFailed = true
        this.updateOneClickButtons(false)
        return
      }
      this.h5PhoneAuthInfo = info
      this.h5PhoneOneClickReady = true
      this.updateOneClickButtons(true)
    } catch (err) {
      this.h5PhoneOneClickFailed = true
      this.updateOneClickButtons(false)
    }
  }

  // 向服务端换取 H5 鉴权 token。access_token 有效期仅 10 分钟，所以每次取号前都要重新拉一份，不能长期缓存。
  // userRequest 返回 { ok, data: <完整响应体> }，token 在响应体的 data 字段下：data.data.{access_token,jwt_token}
  async fetchH5AuthInfo() {
    const pageURL = (window.location.href || '').split('#')[0]
    const tokenResult = await this.app.api.getPhoneH5AuthToken(pageURL)
    const payload = tokenResult.ok && tokenResult.data ? (tokenResult.data.data || {}) : {}
    if (!payload.access_token || !payload.jwt_token) return null
    return { accessToken: payload.access_token, jwtToken: payload.jwt_token, pageURL }
  }

  h5OneClickEnvironmentAvailable() {
    if (!window.location || !/^https:$/i.test(window.location.protocol)) return false
    const ua = String(navigator && navigator.userAgent || '').toLowerCase()
    if (/iphone|ipad|ipod|android|harmony|hongmeng/.test(ua) === false) return false
    // 阿里云号码认证 H5 网页端 SDK 通过 UMD 将构造函数挂载到 window.PhoneNumberServer
    return typeof window.PhoneNumberServer === 'function'
  }

  async runH5OneClick(isRegistrationContext) {
    if (!this.h5PhoneOneClickReady || !this.h5PhoneAuthInfo) {
      this.updateOneClickButtons(false)
      this.setStatus('当前环境不支持一键登录，请使用短信验证码或密码登录', true)
      return
    }
    if (typeof window.PhoneNumberServer !== 'function') {
      this.setStatus('一键登录 SDK 未加载，请使用短信验证码或密码登录', true)
      this.h5PhoneOneClickFailed = true
      this.updateOneClickButtons(false)
      return
    }
    const buttonId = isRegistrationContext ? 'phone-oneclick-register' : 'phone-oneclick-login'
    this.app.audio.click()
    this.setBusy(buttonId, true, '', '正在获取本机号码…')
    this.setStatus('')
    try {
      // 每次点击都重新取一份新鲜 token（access_token 仅 10 分钟有效），避免用过期 token 取号失败（600011）
      const fresh = await this.fetchH5AuthInfo()
      if (!fresh) {
        this.setBusy(buttonId, false, '', '')
        this.setStatus('一键登录初始化失败，请使用短信验证码或密码登录', true)
        this.h5PhoneOneClickFailed = true
        this.updateOneClickButtons(false)
        return
      }
      this.h5PhoneAuthInfo = fresh
      const phoneNumberServer = new window.PhoneNumberServer()
      // 打开 SDK 日志，便于在 Safari Web 检查器里看到运营商取号的真实流程与错误码
      if (typeof phoneNumberServer.setLoggerEnable === 'function') phoneNumberServer.setLoggerEnable(true)
      const spToken = await this.acquireSpToken(phoneNumberServer)
      const loginResult = await this.app.api.h5PhoneLogin(spToken)
      this.setBusy(buttonId, false, '', '')
      if (!loginResult.ok) {
        const message = loginError(loginResult.error)
        this.setStatus(`一键登录失败：${message}，请使用短信验证码或密码登录`, true)
        this.h5PhoneOneClickFailed = true
        this.updateOneClickButtons(false)
        return
      }
      this.setStatus('本机号码认证成功')
      await this.app.api.refreshUserProfile().catch(() => {})
      await this.app.bootstrap()
    } catch (err) {
      this.setBusy(buttonId, false, '', '')
      const message = err && (err.message || String(err))
      this.setStatus(`本机号码认证失败：${message || '未知错误'}。请使用短信验证码或密码登录`, true)
      this.h5PhoneOneClickFailed = true
      this.updateOneClickButtons(false)
    }
  }

  // 阿里云号码认证 H5 两步流程：先 checkLoginAvailable 鉴权，再 getLoginToken 拉起授权页取号。
  // 成功回调返回 { code: '600000', vender, spToken }，其中 spToken 交由服务端 GetPhoneWithToken 取真实号码。
  acquireSpToken(phoneNumberServer) {
    const { accessToken, jwtToken } = this.h5PhoneAuthInfo
    // #game-shell 无 z-index 不成层叠上下文，导致 #login-panel(z-index:5) 会盖住运营商授权页。
    // 取号期间临时隐藏游戏登录卡片，让授权页独占屏幕可交互，结束后恢复。
    const panel = this.root
    return new Promise((resolve, reject) => {
      let settled = false
      let timer = null
      const finish = (fn, arg) => { if (settled) return; settled = true; if (timer) clearTimeout(timer); if (panel) panel.hidden = false; fn(arg) }
      const arm = (ms, msg) => { if (timer) clearTimeout(timer); timer = setTimeout(() => finish(reject, new Error(msg)), ms) }
      // 附带 SDK 返回的 code，并把完整结果打到 console（600011/600012 的真实原因在运营商子码里）
      const messageOf = (res, fallback) => {
        try { console.warn('[oddspot h5]', JSON.stringify(res)) } catch (_) { console.warn('[oddspot h5]', res) }
        const base = (res && (res.msg || res.message)) ? String(res.msg || res.message) : fallback
        const code = res && (res.code !== undefined && res.code !== null) ? `（${res.code}）` : ''
        const carrierObj = res && (res.carrier || res.carrierFailedResultData)
        const carrier = carrierObj ? `[运营商:${typeof carrierObj === 'string' ? carrierObj : JSON.stringify(carrierObj)}]` : ''
        const vender = res && res.vender ? `[${res.vender}]` : ''
        return base + code + vender + carrier
      }
      // 阶段一：鉴权，给 15s；这一步是纯网络，超时说明运营商网关不通（多为未走蜂窝数据）
      arm(15000, '运营商鉴权超时（请关闭 WiFi、仅用蜂窝数据后重试）')
      phoneNumberServer.checkLoginAvailable({
        accessToken,
        jwtToken,
        timeout: 15,
        success: (authRes) => {
          if (settled) return
          if (!authRes || String(authRes.code) !== '600000') {
            finish(reject, new Error(messageOf(authRes, '鉴权失败')))
            return
          }
          // 阶段二：授权页展示 + 用户点击 + 取号；放宽到 90s，避免把用户阅读/点击时间算成超时
          arm(90000, '取号超时（未收到运营商回调）')
          if (panel) panel.hidden = true // 让运营商授权页独占屏幕，避免被登录卡片遮挡
          phoneNumberServer.getLoginToken({
            authPageOption: { privacyAlertIsNeedShow: true, isShowPreviewPrivacy: true },
            timeout: 15,
            success: (tokenRes) => {
              const token = tokenRes && (tokenRes.spToken || tokenRes.token)
              if (token) finish(resolve, token)
              else finish(reject, new Error(messageOf(tokenRes, '取号失败')))
            },
            error: (errRes) => finish(reject, new Error(messageOf(errRes, '取号失败'))),
          })
        },
        error: (errRes) => finish(reject, new Error(messageOf(errRes, '鉴权失败'))),
      })
    })
  }

  show() { this.root.hidden = false; this.setMode(this.currentMode); this.showLogin() }
  hide() { this.root.hidden = true; this.setStatus('') }
  setStatus(value, error = false) { this.statusNode.textContent = value || ''; this.statusNode.classList.toggle('error', error) }
  setUserStatus(value, error = false) { this.userStatusNode.textContent = value || ''; this.userStatusNode.classList.toggle('error', error) }
  setBusy(buttonId, busy, label, busyLabel) {
    const button = document.getElementById(buttonId)
    if (!button) return
    button.disabled = busy
    button.textContent = busy ? busyLabel : label
  }

  showLogin() {
    const registerAccount = document.getElementById('register-email').value.trim()
    this.ticket = ''
    this.form.hidden = false
    this.registration.hidden = true
    this.profile.hidden = true
    document.getElementById('login-title').textContent = '欢迎回来'
    document.getElementById('login-description').textContent = this.currentMode === 'phone'
      ? '使用手机号和密码登录，同步关卡进度与游戏权益。'
      : '使用邮箱和密码登录，同步关卡进度与游戏权益。'
    const loginInput = document.getElementById('login-email')
    if (registerAccount && !loginInput.value.trim()) loginInput.value = registerAccount
    this.setStatus('')
    setTimeout(() => {
      const passwordField = document.getElementById('login-password')
      if (loginInput.value.trim() && !passwordField.value) passwordField.focus()
      else loginInput.focus()
    }, 0)
  }

  showRegistration() {
    const loginAccount = document.getElementById('login-email').value.trim()
    this.form.hidden = true
    this.registration.hidden = false
    this.profile.hidden = true
    document.getElementById('login-title').textContent = '创建账号'
    document.getElementById('login-description').textContent = this.currentMode === 'phone'
      ? '验证手机号后设置密码，昵称可稍后完善。'
      : '验证邮箱后设置密码，昵称可稍后完善。'
    if (loginAccount) document.getElementById('register-email').value = loginAccount
    this.setStatus('')
    setTimeout(() => {
      const field = document.getElementById('register-email')
      if (field.value.trim()) document.getElementById('send-code').focus()
      else field.focus()
    }, 0)
  }

  async login() {
    const account = document.getElementById('login-email').value.trim()
    const password = document.getElementById('login-password').value
    if (this.currentMode === 'phone') {
      const normalized = account.replace(/^\+?86/, '').replace(/[\s-]/g, '')
      if (!/^1[3-9]\d{9}$/.test(normalized)) { this.setStatus('请输入 11 位中国大陆手机号', true); return }
    } else if (!validEmail(account)) { this.setStatus('请输入有效邮箱', true); return }
    if (password.length < 10) { this.setStatus('密码至少需要 10 个字符', true); return }
    this.app.audio.click()
    this.setBusy('login-submit', true, '登录', '正在登录…')
    this.setStatus('')
    const result = await this.app.api.loginUser(account, password, this.currentMode)
    this.setBusy('login-submit', false, '登录', '正在登录…')
    if (!result.ok) { this.setStatus(loginError(result.error), true); return }
    await this.app.api.refreshUserProfile().catch(() => {})
    await this.app.bootstrap()
  }

  async sendCode() {
    const account = document.getElementById('register-email').value.trim()
    let normalized = account
    if (this.currentMode === 'phone') {
      normalized = account.replace(/^\+?86/, '').replace(/[\s-]/g, '')
      if (!/^1[3-9]\d{9}$/.test(normalized)) { this.setStatus('请输入 11 位中国大陆手机号', true); return }
    } else {
      if (!validEmail(account)) { this.setStatus('请输入有效邮箱', true); return }
      normalized = account.toLowerCase()
    }
    this.app.audio.click()
    this.setBusy('send-code', true, '重新发送验证码', '正在发送…')
    const result = this.currentMode === 'phone'
      ? await this.app.api.sendPhoneCode(normalized)
      : await this.app.api.sendEmailCode(account.toLowerCase())
    this.setBusy('send-code', false, '重新发送验证码', '正在发送…')
    if (!result.ok) { this.setStatus(`发送失败：${loginError(result.error)}`, true); return }
    this.setStatus('验证码已发送，请在 5 分钟内填写')
    document.getElementById('email-code').focus()
  }

  async verifyCode() {
    const account = document.getElementById('register-email').value.trim()
    const code = document.getElementById('email-code').value.trim()
    let normalized = account
    let result = null
    if (this.currentMode === 'phone') {
      normalized = account.replace(/^\+?86/, '').replace(/[\s-]/g, '')
      if (!/^1[3-9]\d{9}$/.test(normalized)) { this.setStatus('请输入 11 位中国大陆手机号', true); return }
    } else {
      if (!validEmail(account)) { this.setStatus('请输入有效邮箱', true); return }
      normalized = account.toLowerCase()
    }
    if (code.length !== 6) { this.setStatus('请输入 6 位验证码', true); return }
    this.app.audio.click()
    const isPhone = this.currentMode === 'phone'
    const verifyBtnLabel = isPhone ? '验证手机号' : '验证邮箱'
    this.setBusy('verify-code', true, verifyBtnLabel, '正在验证…')
    result = isPhone
      ? await this.app.api.verifyPhoneCode(normalized, code)
      : await this.app.api.verifyEmailCode(account.toLowerCase(), code)
    this.setBusy('verify-code', false, verifyBtnLabel, '正在验证…')
    if (!result.ok) { this.setStatus(`验证失败：${loginError(result.error)}`, true); return }
    if (result.logged_in) { await this.app.api.refreshUserProfile().catch(() => {}); await this.app.bootstrap(); return }
    this.ticket = String((result.data || {}).registration_ticket || '')
    if (!this.ticket) { this.setStatus((isPhone ? '手机号' : '邮箱') + '验证结果不完整，请重新发送验证码', true); return }
    this.registration.hidden = true
    this.profile.hidden = false
    this.setStatus((isPhone ? '手机号' : '邮箱') + '验证成功，请设置密码完成注册')
    document.getElementById('register-password').focus()
  }

  async completeRegistration() {
    const nickname = document.getElementById('register-nickname').value.trim()
    const password = document.getElementById('register-password').value
    const passwordConfirm = document.getElementById('register-password-confirm').value
    if (password.length < 10) { this.setStatus('密码至少需要 10 个字符', true); return }
    if (password !== passwordConfirm) { this.setStatus('两次输入的密码不一致', true); return }
    this.app.audio.click()
    this.setBusy('complete-registration', true, '完成注册并登录', '正在注册…')
    let result
    if (this.currentMode === 'phone') {
      result = await this.app.api.completePhoneRegistration(this.ticket, nickname, password)
    } else {
      const email = document.getElementById('register-email').value.trim().toLowerCase()
      result = await this.app.api.completeEmailRegistration(this.ticket, nickname, password, email)
    }
    this.setBusy('complete-registration', false, '完成注册并登录', '正在注册…')
    if (!result.ok) { this.setStatus(`注册失败：${loginError(result.error)}`, true); return }
    if (this.registerAvatarFile) {
      try { await this.app.api.uploadUserAvatar(this.registerAvatarFile) } catch (_) {}
    }
    if (nickname) await this.app.api.updateUserProfile(nickname).catch(() => {})
    await this.app.api.refreshUserProfile().catch(() => {})
    await this.app.bootstrap()
  }

  async showUserPanel() {
    await this.app.api.refreshUserProfile().catch(() => {})
    this.userPanel.hidden = false
    this.refreshUserAvatarPreview()
    document.getElementById('user-nickname').value = this.app.session.data.username || ''
    this.setUserStatus('')
  }
  hideUserPanel() { this.userPanel.hidden = true; this.setUserStatus('') }

  async saveUserProfile() {
    const nickname = document.getElementById('user-nickname').value.trim()
    this.app.audio.click()
    this.setUserStatus('正在保存…', false)
    const ok = await this.app.api.updateUserProfile(nickname)
    if (!ok.ok) { this.setUserStatus('保存失败，请稍后重试', true); return }
    await this.app.api.refreshUserProfile().catch(() => {})
    if (this.app.updateUserHeader) this.app.updateUserHeader()
    this.setUserStatus('已保存')
  }
}

function validEmail(value) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || '')) }
function loginError(error) {
  const messages = {
    HTTP_404: '游戏登录服务尚未更新，请联系管理员',
    USER_LOGIN_INVALID: '账号或密码不正确',
    IDENTITY_UNAVAILABLE: '用户服务暂时不可用',
    USER_SERVER_UNAVAILABLE: '用户服务暂时不可用',
    USER_TOKEN_MISSING: '用户服务返回的登录凭证不完整',
    REQUEST_TIMEOUT: '请求超时，请检查网络后重试',
    NETWORK_ERROR: '网络连接失败，请稍后重试',
    AVATAR_UPLOAD_FAILED: '头像上传失败，请稍后重试',
  }
  return messages[error] || String(error || '登录失败，请稍后再试')
}

module.exports = { LoginView, validEmail, loginError }
