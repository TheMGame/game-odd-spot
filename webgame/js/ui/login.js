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
      const pageURL = (window.location.href || '').split('#')[0]
      const tokenResult = await this.app.api.getPhoneH5AuthToken(pageURL)
      if (!tokenResult.ok || !tokenResult.data || !tokenResult.data.access_token || !tokenResult.data.jwt_token) {
        this.h5PhoneOneClickFailed = true
        this.updateOneClickButtons(false)
        return
      }
      this.h5PhoneAuthInfo = {
        accessToken: tokenResult.data.access_token,
        jwtToken: tokenResult.data.jwt_token,
        pageURL,
      }
      this.h5PhoneOneClickReady = true
      this.updateOneClickButtons(true)
    } catch (err) {
      this.h5PhoneOneClickFailed = true
      this.updateOneClickButtons(false)
    }
  }

  h5OneClickEnvironmentAvailable() {
    if (!window.location || !/^https:$/i.test(window.location.protocol)) return false
    const ua = String(navigator && navigator.userAgent || '').toLowerCase()
    if (/iphone|ipad|ipod|android|harmony|hongmeng/.test(ua) === false) return false
    if (typeof window.NumberAuthSdk !== 'undefined' && typeof window.NumberAuthSdk.getVerifyToken === 'function') return true
    if (typeof window.Alibaba !== 'undefined' && typeof window.Alibaba.NumberAuthSdk !== 'undefined') return true
    return false
  }

  async runH5OneClick(isRegistrationContext) {
    if (!this.h5PhoneOneClickReady || !this.h5PhoneAuthInfo) {
      this.updateOneClickButtons(false)
      this.setStatus('当前环境不支持一键登录，请使用短信验证码或密码登录', true)
      return
    }
    this.app.audio.click()
    this.setBusy(isRegistrationContext ? 'phone-oneclick-register' : 'phone-oneclick-login', true, '', '正在获取本机号码…')
    this.setStatus('')
    try {
      const sdk = (window.NumberAuthSdk && typeof window.NumberAuthSdk.getVerifyToken === 'function')
        ? window.NumberAuthSdk
        : (window.Alibaba && window.Alibaba.NumberAuthSdk)
      if (!sdk) {
        this.setStatus('一键登录 SDK 未加载，请使用短信验证码或密码登录', true)
        this.h5PhoneOneClickFailed = true
        this.updateOneClickButtons(false)
        this.setBusy(isRegistrationContext ? 'phone-oneclick-register' : 'phone-oneclick-login', false, '', '')
        return
      }
      sdk.setLogLevel && sdk.setLogLevel('error')
      const spToken = await new Promise((resolve, reject) => {
        try {
          const timeoutTimer = setTimeout(() => reject(new Error('运营商取号超时')), 15000)
          const onResult = (result) => {
            clearTimeout(timeoutTimer)
            const token = (result && (result.spToken || result.token || result.data && (result.data.spToken || result.data.token))) || ''
            if (!token) reject(new Error(result && (result.msg || result.message || '取号失败')))
            else resolve(token)
          }
          const onFailed = (err) => {
            clearTimeout(timeoutTimer)
            reject(err)
          }
          const config = {
            accessToken: this.h5PhoneAuthInfo.accessToken,
            jwtToken: this.h5PhoneAuthInfo.jwtToken,
            sceneType: 'h5',
            timeout: 15000,
          }
          const sceneId = String((this.app && this.app.config ? this.app.config.PHONE_H5_SCENE_ID : '') || '').trim()
          if (sceneId) {
            config.sceneId = sceneId
            config.scene = sceneId
            config.schemeCode = sceneId
            config.planCode = sceneId
          }
          if (typeof sdk.getVerifyToken === 'function') {
            sdk.getVerifyToken(config, onResult, onFailed)
          } else if (typeof sdk.getLoginToken === 'function') {
            sdk.getLoginToken(config, onResult, onFailed)
          } else {
            reject(new Error('未找到支持的取号方法'))
          }
        } catch (err) { reject(err) }
      })
      const loginResult = await this.app.api.h5PhoneLogin(spToken)
      this.setBusy(isRegistrationContext ? 'phone-oneclick-register' : 'phone-oneclick-login', false, '', '')
      if (!loginResult.ok) {
        const message = loginError(loginResult.error)
        if (/已注册|用户存在|phone_otp|phone_login/.test(message) || false) {
          this.setStatus(`一键登录：${message}，请使用密码登录或短信验证码`, true)
        } else {
          this.setStatus(`一键登录失败：${message}，请使用短信验证码或密码登录`, true)
        }
        this.h5PhoneOneClickFailed = true
        this.updateOneClickButtons(false)
        return
      }
      this.setStatus('本机号码认证成功')
      await this.app.api.refreshUserProfile().catch(() => {})
      await this.app.bootstrap()
    } catch (err) {
      this.setBusy(isRegistrationContext ? 'phone-oneclick-register' : 'phone-oneclick-login', false, '', '')
      const message = err && (err.message || String(err))
      this.setStatus(`本机号码认证失败：${message || '未知错误'}。请使用短信验证码或密码登录`, true)
      this.h5PhoneOneClickFailed = true
      this.updateOneClickButtons(false)
    }
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
