const { clamp } = require('./utils')

const COLORS = {
  background: '#102a35', card: '#173a46', cardBorder: '#5b7d87', gold: '#e6b95c', paper: '#f3e8cf',
  cinnabar: '#c84e38', jade: '#72a58f', muted: '#b8c9c5', ink: '#0b1b29', darkRed: '#87352c',
}

class Renderer {
  constructor(canvas) {
    this.canvas = canvas
    this.ctx = canvas.getContext('2d')
    this.width = 1080
    this.height = 1920
    this.pixelRatio = 1
    this.scale = 1
    this.safeTop = 0
    this.safeBottom = 0
    this.safeLeft = 0
    this.safeRight = 0
    this.hitboxes = []
    this.resize()
  }

  resize() {
    const info = wx.getWindowInfo ? wx.getWindowInfo() : wx.getSystemInfoSync()
    this.pixelRatio = info.pixelRatio || 1
    this.scale = Number(info.windowWidth) / this.width
    this.height = Number(info.windowHeight) / this.scale
    const safeArea = info.safeArea
    if (safeArea) {
      this.safeTop = safeArea.top / this.scale
      this.safeBottom = (Number(info.windowHeight) - safeArea.bottom) / this.scale
      this.safeLeft = safeArea.left / this.scale
      this.safeRight = (Number(info.windowWidth) - safeArea.right) / this.scale
    } else {
      this.safeTop = 0
      this.safeBottom = 0
      this.safeLeft = 0
      this.safeRight = 0
    }
    try {
      const menu = wx.getMenuButtonBoundingClientRect()
      if (menu) {
        const menuTopPx = Number(menu.top) + Number(menu.height) + 8
        const menuTop = menuTopPx / this.scale
        if (menuTop > this.safeTop) this.safeTop = menuTop
      }
    } catch (_) {}
    this.canvas.width = Math.round(Number(info.windowWidth) * this.pixelRatio)
    this.canvas.height = Math.round(Number(info.windowHeight) * this.pixelRatio)
  }

  begin() {
    const ctx = this.ctx
    ctx.setTransform(this.pixelRatio * this.scale, 0, 0, this.pixelRatio * this.scale, 0, 0)
    ctx.clearRect(0, 0, this.width, this.height)
    ctx.fillStyle = COLORS.background
    ctx.fillRect(0, 0, this.width, this.height)
    ctx.textBaseline = 'middle'
    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    this.hitboxes = []
  }

  logicalTouch(touch) { return { x: touch.clientX / this.scale, y: touch.clientY / this.scale, id: touch.identifier } }
  register(id, rect, data = null) { this.hitboxes.push({ id, rect, data }) }
  hit(point) { for (let i = this.hitboxes.length - 1; i >= 0; i -= 1) { const item = this.hitboxes[i]; if (point.x >= item.rect.x && point.x <= item.rect.x + item.rect.w && point.y >= item.rect.y && point.y <= item.rect.y + item.rect.h) return item } return null }
  rect(x, y, w, h, fill, radius = 0, stroke = '', lineWidth = 0) {
    const c = this.ctx; c.beginPath(); roundedPath(c, x, y, w, h, radius); c.fillStyle = fill; c.fill()
    if (stroke && lineWidth) { c.strokeStyle = stroke; c.lineWidth = lineWidth; c.stroke() }
  }
  line(x1, y1, x2, y2, color, width = 2) { const c = this.ctx; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.strokeStyle = color; c.lineWidth = width; c.stroke() }
  circle(x, y, radius, fill, stroke = '', lineWidth = 0) { const c = this.ctx; c.beginPath(); c.arc(x, y, radius, 0, Math.PI * 2); c.fillStyle = fill; c.fill(); if (stroke && lineWidth) { c.strokeStyle = stroke; c.lineWidth = lineWidth; c.stroke() } }
  text(value, x, y, size = 28, color = COLORS.paper, align = 'left', weight = 'normal', maxWidth) {
    const c = this.ctx; c.font = `${weight} ${size}px sans-serif`; c.fillStyle = color; c.textAlign = align
    if (maxWidth) c.fillText(String(value), x, y, maxWidth); else c.fillText(String(value), x, y)
  }
  wrappedText(value, x, y, maxWidth, size = 26, color = COLORS.paper, lineHeight = size * 1.45, maxLines = 99, align = 'left') {
    const lines = this.wrap(String(value), maxWidth, size)
    const c = this.ctx; c.textAlign = align; c.fillStyle = color; c.font = `${size}px sans-serif`
    lines.slice(0, maxLines).forEach((line, index) => c.fillText(line, x, y + index * lineHeight))
    return Math.min(lines.length, maxLines) * lineHeight
  }
  wrap(value, maxWidth, size) {
    const c = this.ctx; c.font = `${size}px sans-serif`; const output = []
    for (const paragraph of value.split('\n')) {
      if (!paragraph) { output.push(''); continue }
      let line = ''
      for (const char of paragraph) { const next = line + char; if (line && c.measureText(next).width > maxWidth) { output.push(line); line = char } else line = next }
      if (line) output.push(line)
    }
    return output
  }
  button(id, rect, label, options = {}) {
    const fill = options.fill || '#1b4350'; const border = options.border || COLORS.cardBorder
    this.rect(rect.x, rect.y, rect.w, rect.h, fill, options.radius || 16, border, options.lineWidth || 2)
    this.text(label, rect.x + rect.w / 2, rect.y + rect.h / 2, options.size || 28, options.color || COLORS.paper, 'center', options.weight || 'normal', rect.w - 24)
    if (!options.disabled) this.register(id, rect, options.data)
  }
  toggle(id, x, y, label, enabled) {
    this.text(label, x, y + 35, 34, COLORS.paper)
    const rx = 790, rect = { x: rx, y, w: 210, h: 70 }
    this.rect(rect.x, rect.y, rect.w, rect.h, enabled ? '#3f7565' : '#263f48', 35, enabled ? COLORS.gold : COLORS.cardBorder, 2)
    this.circle(enabled ? rect.x + rect.w - 36 : rect.x + 36, rect.y + 35, 27, enabled ? COLORS.gold : '#8ca09e')
    this.register(id, rect)
  }
  iconButton(id, x, y, size, kind, glow = false, disabled = false) {
    const radius = size * 0.38, cx = x + size / 2, cy = y + size / 2
    if (glow) this.circle(cx, cy, radius + 9, 'rgba(230,185,92,.16)', COLORS.gold, 2)
    this.circle(cx, cy + 3, radius + 2, 'rgba(11,27,41,.34)')
    this.circle(cx, cy, radius, disabled ? '#5b4a47' : COLORS.gold)
    this.circle(cx, cy, radius - 4, disabled ? '#493938' : COLORS.darkRed, disabled ? 'rgba(243,232,207,.35)' : '#f0cd83', 2)
    this.drawIcon(kind, cx, cy, radius * 0.78, disabled ? 'rgba(243,232,207,.35)' : COLORS.paper)
    if (!disabled) this.register(id, { x, y, w: size, h: size })
  }
  drawIcon(kind, x, y, size, color) {
    const c = this.ctx; c.strokeStyle = color; c.fillStyle = color; c.lineWidth = 5; c.beginPath()
    if (kind === 'back') { c.moveTo(x + size * .4, y - size * .42); c.lineTo(x - size * .35, y); c.lineTo(x + size * .4, y + size * .42); c.stroke() }
    else if (kind === 'next') { c.moveTo(x - size * .45, y); c.lineTo(x + size * .28, y); c.stroke(); c.beginPath(); c.moveTo(x + size * .1, y - size * .4); c.lineTo(x + size * .5, y); c.lineTo(x + size * .1, y + size * .4); c.fill() }
    else if (kind === 'hint') { c.arc(x, y - size * .08, size * .34, Math.PI, Math.PI * 2); c.stroke(); this.line(x - size * .34, y - size * .08, x - size * .1, y + size * .34, color, 5); this.line(x + size * .34, y - size * .08, x + size * .1, y + size * .34, color, 5); this.line(x - size * .12, y + size * .48, x + size * .12, y + size * .48, color, 5) }
    else if (kind === 'settings') { c.arc(x, y, size * .42, 0, Math.PI * 2); c.stroke(); this.circle(x, y, size * .14, color) }
    else if (kind === 'replay') { c.arc(x, y, size * .42, -Math.PI * .65, Math.PI * 1.18); c.stroke(); c.beginPath(); c.moveTo(x - size * .49, y - size * .18); c.lineTo(x - size * .48, y + size * .23); c.lineTo(x - size * .12, y + size * .06); c.fill() }
    else if (kind === 'map') { c.strokeRect(x - size * .42, y - size * .35, size * .84, size * .7); this.line(x - size * .14, y - size * .35, x - size * .14, y + size * .35, color, 3); this.line(x + size * .14, y - size * .35, x + size * .14, y + size * .35, color, 3) }
    else { this.text('!', x, y + 1, size, color, 'center', 'bold') }
  }
  image(image, rect, mode = 'cover', zoom = 1, offset = { x: 0, y: 0 }) {
    if (!image || !image.width || !image.height) return null
    const fit = mode === 'contain' ? Math.min(rect.w / image.width, rect.h / image.height) : Math.max(rect.w / image.width, rect.h / image.height)
    const w = image.width * fit * zoom, h = image.height * fit * zoom
    const draw = { x: rect.x + (rect.w - w) / 2 + offset.x, y: rect.y + (rect.h - h) / 2 + offset.y, w, h }
    const c = this.ctx; c.save(); c.beginPath(); c.rect(rect.x, rect.y, rect.w, rect.h); c.clip(); c.drawImage(image, draw.x, draw.y, draw.w, draw.h); c.restore()
    return draw
  }
  puzzleImage(image, rect, rows, cols, order, selectedGroup, zoom = 1, offset = { x: 0, y: 0 }) {
    if (!image || !image.width || !image.height) return null
    const fit = Math.min(rect.w / image.width, rect.h / image.height), w = image.width * fit * zoom, h = image.height * fit * zoom
    const draw = { x: rect.x + (rect.w - w) / 2 + offset.x, y: rect.y + (rect.h - h) / 2 + offset.y, w, h }, c = this.ctx
    c.save(); c.beginPath(); c.rect(rect.x, rect.y, rect.w, rect.h); c.clip()
    for (let cell = 0; cell < order.length; cell++) { const piece = order[cell], dc = cell % cols, dr = Math.floor(cell / cols), sc = piece % cols, sr = Math.floor(piece / cols), dw = w / cols, dh = h / rows; c.drawImage(image, sc * image.width / cols, sr * image.height / rows, image.width / cols, image.height / rows, draw.x + dc * dw, draw.y + dr * dh, dw, dh); c.strokeStyle = 'rgba(255,255,255,.45)'; c.lineWidth = 1.5; c.strokeRect(draw.x + dc * dw, draw.y + dr * dh, dw, dh) }
    for(const selected of selectedGroup||[]){const col=selected%cols,row=Math.floor(selected/cols);c.strokeStyle=COLORS.gold;c.lineWidth=5;c.strokeRect(draw.x+col*w/cols+2,draw.y+row*h/rows+2,w/cols-4,h/rows-4)}
    c.restore(); return draw
  }
  progress(x, y, w, h, value, maximum) { this.rect(x, y, w, h, '#203d47', h / 2); this.rect(x, y, w * clamp(value / Math.max(maximum, 1), 0, 1), h, COLORS.gold, h / 2) }
  watermark(rect, config) {
    if (!config || !config.ENABLED || !config.TEXT) return
    const mode = config.MODE || 'corner'
    if (mode === 'tile') { this.watermarkTile(rect, config); return }
    this.watermarkCorner(rect, config)
  }
  watermarkCorner(rect, config) {
    const c = this.ctx
    const text = String(config.TEXT)
    const fontSize = config.FONT_SIZE || 22
    const color = config.COLOR || 'rgba(255,255,255,0.85)'
    const shadowColor = config.SHADOW_COLOR || 'rgba(0,0,0,0.6)'
    const paddingX = config.PADDING_X || 16
    const paddingY = config.PADDING_Y || 10
    const bgColor = config.BG_COLOR || 'rgba(11,27,41,0.55)'
    const borderColor = config.BORDER_COLOR || 'rgba(230,185,92,0.5)'
    const radius = config.RADIUS || 10
    const placement = config.PLACEMENT || 'top-right'
    c.save()
    c.beginPath()
    c.rect(rect.x, rect.y, rect.w, rect.h)
    c.clip()
    c.font = `bold ${fontSize}px sans-serif`
    const metrics = c.measureText(text)
    const textW = metrics.width
    const textH = fontSize
    const boxW = textW + paddingX * 2
    const boxH = textH + paddingY * 2
    const edge = config.MARGIN || 18
    let bx, by, tx, ty, textAlign = 'left', textBaseline = 'top'
    if (placement === 'top-right') { bx = rect.x + rect.w - boxW - edge; by = rect.y + edge; tx = bx + paddingX; ty = by + paddingY + textH * 0.1 }
    else if (placement === 'top-left') { bx = rect.x + edge; by = rect.y + edge; tx = bx + paddingX; ty = by + paddingY + textH * 0.1 }
    else if (placement === 'bottom-right') { bx = rect.x + rect.w - boxW - edge; by = rect.y + rect.h - boxH - edge; tx = bx + paddingX; ty = by + paddingY + textH * 0.1 }
    else if (placement === 'bottom-left') { bx = rect.x + edge; by = rect.y + rect.h - boxH - edge; tx = bx + paddingX; ty = by + paddingY + textH * 0.1 }
    else if (placement === 'four-corners') {
      ;['top-right', 'top-left', 'bottom-right', 'bottom-left'].forEach((p) => this.watermarkCorner(rect, Object.assign({}, config, { PLACEMENT: p })))
      c.restore(); return
    }
    else { bx = rect.x + rect.w - boxW - edge; by = rect.y + edge; tx = bx + paddingX; ty = by + paddingY + textH * 0.1 }
    c.beginPath()
    const r = Math.min(radius, boxW / 2, boxH / 2)
    c.moveTo(bx + r, by)
    c.arcTo(bx + boxW, by, bx + boxW, by + boxH, r)
    c.arcTo(bx + boxW, by + boxH, bx, by + boxH, r)
    c.arcTo(bx, by + boxH, bx, by, r)
    c.arcTo(bx, by, bx + boxW, by, r)
    c.closePath()
    if (bgColor) { c.fillStyle = bgColor; c.fill() }
    if (borderColor) { c.strokeStyle = borderColor; c.lineWidth = 1.5; c.stroke() }
    c.textAlign = textAlign; c.textBaseline = textBaseline
    c.shadowColor = shadowColor; c.shadowBlur = 3
    c.fillStyle = color
    c.fillText(text, tx, ty)
    c.restore()
  }
  watermarkTile(rect, config) {
    const c = this.ctx
    const text = String(config.TEXT)
    const fontSize = config.FONT_SIZE || 22
    const color = config.COLOR || 'rgba(255,255,255,0.45)'
    const shadowColor = config.SHADOW_COLOR || 'rgba(0,0,0,0.3)'
    const angle = (config.ANGLE || -25) * Math.PI / 180
    const marginX = config.MARGIN_X || 40
    const marginY = config.MARGIN_Y || 60
    c.save()
    c.beginPath()
    c.rect(rect.x, rect.y, rect.w, rect.h)
    c.clip()
    c.font = `bold ${fontSize}px sans-serif`
    const metrics = c.measureText(text)
    const textW = metrics.width
    const textH = fontSize * 1.4
    const stepX = textW + marginX
    const stepY = textH + marginY
    const diag = Math.hypot(rect.w, rect.h)
    const rows = Math.ceil(diag / stepY) + 2
    const cols = Math.ceil(diag / stepX) + 2
    const cx = rect.x + rect.w / 2
    const cy = rect.y + rect.h / 2
    c.translate(cx, cy)
    c.rotate(angle)
    c.fillStyle = color
    c.shadowColor = shadowColor
    c.shadowBlur = 2
    c.textAlign = 'center'
    c.textBaseline = 'middle'
    for (let row = -rows; row <= rows; row += 1) {
      for (let col = -cols; col <= cols; col += 1) {
        const offsetX = (row % 2 === 0 ? 0 : stepX / 2)
        const x = col * stepX + offsetX
        const y = row * stepY
        c.fillText(text, x, y)
      }
    }
    c.restore()
  }
}

function roundedPath(c, x, y, w, h, radius) {
  const r = Math.min(radius, w / 2, h / 2); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r); c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath()
}

module.exports = { Renderer, COLORS }
