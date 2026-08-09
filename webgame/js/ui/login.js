class LoginView {
  constructor(app) {
    this.app = app
    this.root = document.getElementById('login-panel')
    this.form = document.getElementById('login-form')
    this.registration = document.getElementById('registration-form')
    this.profile = document.getElementById('registration-profile')
    this.statusNode = document.getElementById('login-status')
    this.ticket = ''
    this.bind()
  }

  bind() {
    document.getElementById('login-submit').addEventListener('click', () => this.login())
    document.getElementById('show-registration').addEventListener('click', () => this.showRegistration())
    document.getElementById('back-to-login').addEventListener('click', () => this.showLogin())
    document.getElementById('send-code').addEventListener('click', () => this.sendCode())
    document.getElementById('verify-code').addEventListener('click', () => this.verifyCode())
    document.getElementById('complete-registration').addEventListener('click', () => this.completeRegistration())
    this.root.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return
      if (!this.form.hidden) this.login()
      else if (!this.profile.hidden) this.completeRegistration()
      else this.verifyCode()
    })
  }

  show() { this.root.hidden = false; this.showLogin() }
  hide() { this.root.hidden = true; this.setStatus('') }
  setStatus(value, error = false) { this.statusNode.textContent = value || ''; this.statusNode.classList.toggle('error', error) }
  setBusy(buttonId, busy, label, busyLabel) {
    const button = document.getElementById(buttonId)
    button.disabled = busy
    button.textContent = busy ? busyLabel : label
  }

  showLogin() {
    const registerEmail = document.getElementById('register-email').value.trim()
    this.ticket = ''
    this.form.hidden = false
    this.registration.hidden = true
    this.profile.hidden = true
    document.getElementById('login-title').textContent = '欢迎回来'
    document.getElementById('login-description').textContent = '使用邮箱和密码登录，同步关卡进度与游戏权益。'
    if (registerEmail && !document.getElementById('login-email').value.trim()) {
      document.getElementById('login-email').value = registerEmail
    }
    this.setStatus('')
    setTimeout(() => {
      const passwordField = document.getElementById('login-password')
      if (document.getElementById('login-email').value.trim() && !passwordField.value) {
        passwordField.focus()
      } else {
        document.getElementById('login-email').focus()
      }
    }, 0)
  }

  showRegistration() {
    const loginEmail = document.getElementById('login-email').value.trim()
    this.form.hidden = true
    this.registration.hidden = false
    this.profile.hidden = true
    document.getElementById('login-title').textContent = '创建账号'
    document.getElementById('login-description').textContent = '验证邮箱后设置密码，昵称可稍后完善。'
    if (loginEmail) document.getElementById('register-email').value = loginEmail
    this.setStatus('')
    setTimeout(() => {
      const emailField = document.getElementById('register-email')
      if (emailField.value.trim()) {
        document.getElementById('send-code').focus()
      } else {
        emailField.focus()
      }
    }, 0)
  }

  async login() {
    const email = document.getElementById('login-email').value.trim()
    const password = document.getElementById('login-password').value
    if (!validEmail(email)) { this.setStatus('请输入有效邮箱', true); return }
    if (password.length < 10) { this.setStatus('密码至少需要 10 个字符', true); return }
    this.app.audio.click()
    this.setBusy('login-submit', true, '登录', '正在登录…')
    this.setStatus('')
    const result = await this.app.api.loginUser(email, password)
    this.setBusy('login-submit', false, '登录', '正在登录…')
    if (!result.ok) { this.setStatus(loginError(result.error), true); return }
    await this.app.api.refreshUserProfile().catch(() => {})
    await this.app.bootstrap()
  }

  async sendCode() {
    const email = document.getElementById('register-email').value.trim().toLowerCase()
    if (!validEmail(email)) { this.setStatus('请输入有效邮箱', true); return }
    this.app.audio.click()
    this.setBusy('send-code', true, '重新发送验证码', '正在发送…')
    const result = await this.app.api.sendEmailCode(email)
    this.setBusy('send-code', false, '重新发送验证码', '正在发送…')
    if (!result.ok) { this.setStatus(`发送失败：${loginError(result.error)}`, true); return }
    this.setStatus('验证码已发送，请在 5 分钟内填写')
    document.getElementById('email-code').focus()
  }

  async verifyCode() {
    const email = document.getElementById('register-email').value.trim().toLowerCase()
    const code = document.getElementById('email-code').value.trim()
    if (!validEmail(email)) { this.setStatus('请输入有效邮箱', true); return }
    if (code.length !== 6) { this.setStatus('请输入 6 位邮箱验证码', true); return }
    this.app.audio.click()
    this.setBusy('verify-code', true, '验证邮箱', '正在验证…')
    const result = await this.app.api.verifyEmailCode(email, code)
    this.setBusy('verify-code', false, '验证邮箱', '正在验证…')
    if (!result.ok) { this.setStatus(`验证失败：${loginError(result.error)}`, true); return }
    if (result.logged_in) { await this.app.api.refreshUserProfile().catch(() => {}); await this.app.bootstrap(); return }
    this.ticket = String((result.data || {}).registration_ticket || '')
    if (!this.ticket) { this.setStatus('邮箱验证结果不完整，请重新发送验证码', true); return }
    this.registration.hidden = true
    this.profile.hidden = false
    this.setStatus('邮箱验证成功，请设置密码完成注册')
    document.getElementById('register-password').focus()
  }

  async completeRegistration() {
    const nickname = document.getElementById('register-nickname').value.trim()
    const password = document.getElementById('register-password').value
    const passwordConfirm = document.getElementById('register-password-confirm').value
    const email = document.getElementById('register-email').value.trim().toLowerCase()
    if (password.length < 10) { this.setStatus('密码至少需要 10 个字符', true); return }
    if (password !== passwordConfirm) { this.setStatus('两次输入的密码不一致', true); return }
    this.app.audio.click()
    this.setBusy('complete-registration', true, '完成注册并登录', '正在注册…')
    const result = await this.app.api.completeEmailRegistration(this.ticket, nickname, password, email)
    this.setBusy('complete-registration', false, '完成注册并登录', '正在注册…')
    if (!result.ok) { this.setStatus(`注册失败：${loginError(result.error)}`, true); return }
    if (nickname) await this.app.api.updateUserProfile(nickname).catch(() => {})
    await this.app.api.refreshUserProfile().catch(() => {})
    await this.app.bootstrap()
  }
}

function validEmail(value) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || '')) }
function loginError(error) {
  const messages = {
    HTTP_404: '游戏登录服务尚未更新，请联系管理员',
    USER_LOGIN_INVALID: '邮箱或密码不正确',
    IDENTITY_UNAVAILABLE: '用户服务暂时不可用',
    USER_SERVER_UNAVAILABLE: '用户服务暂时不可用',
    USER_TOKEN_MISSING: '用户服务返回的登录凭证不完整',
    REQUEST_TIMEOUT: '请求超时，请检查网络后重试',
    NETWORK_ERROR: '网络连接失败，请稍后重试',
  }
  return messages[error] || String(error || '登录失败，请稍后再试')
}

module.exports = { LoginView, validEmail, loginError }
