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
    const rect = this.canvas.getBoundingClientRect()
    const width = Math.max(1, Number(rect.width || window.innerWidth))
    const height = Math.max(1, Number(rect.height || window.innerHeight))
    this.pixelRatio = Math.min(3, Math.max(1, Number(window.devicePixelRatio || 1)))
    this.scale = width / this.width
    this.height = height / this.scale
    const safe = readSafeInsets()
    this.safeTop = Math.max(100, safe.top / this.scale)
    this.safeBottom = safe.bottom / this.scale
    this.safeLeft = safe.left / this.scale
    this.safeRight = safe.right / this.scale
    this.canvas.width = Math.round(width * this.pixelRatio)
    this.canvas.height = Math.round(height * this.pixelRatio)
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

  logicalTouch(touch) {
    const rect = this.canvas.getBoundingClientRect()
    return { x: (touch.clientX - rect.left) / this.scale, y: (touch.clientY - rect.top) / this.scale, id: touch.identifier != null ? touch.identifier : touch.pointerId }
  }
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
    else if (kind === 'book') { c.strokeRect(x - size * .34, y - size * .42, size * .68, size * .84); this.line(x - size * .16, y - size * .18, x + size * .16, y - size * .18, color, 3); this.line(x - size * .16, y, x + size * .16, y, color, 3); this.line(x - size * .16, y + size * .18, x + size * .04, y + size * .18, color, 3) }
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
  puzzleImage(image, rect, rows, cols, order, selectedGroup, groups, zoom = 1, offset = { x: 0, y: 0 }, drag = null) {
    if (!image || !image.width || !image.height) return null
    const fit = Math.min(rect.w / image.width, rect.h / image.height), w = image.width * fit * zoom, h = image.height * fit * zoom
    const draw = { x: rect.x + (rect.w - w) / 2 + offset.x, y: rect.y + (rect.h - h) / 2 + offset.y, w, h }, c = this.ctx, dw = w / cols, dh = h / rows
    c.save(); c.beginPath(); c.rect(rect.x, rect.y, rect.w, rect.h); c.clip()
    for (let cell = 0; cell < order.length; cell++) { const piece = order[cell], dc = cell % cols, dr = Math.floor(cell / cols), sc = piece % cols, sr = Math.floor(piece / cols); c.drawImage(image, sc * image.width / cols, sr * image.height / rows, image.width / cols, image.height / rows, draw.x + dc * dw, draw.y + dr * dh, dw, dh) }
    const cellGroup = new Array(order.length).fill(-1), groupSize = []
    ;(groups && groups.length ? groups : order.map((_, i) => [i])).forEach((group, gi) => { groupSize[gi] = group.length; for (const cell of group) cellGroup[cell] = gi })
    const strokeEdges = (predicate, color, lineWidth) => { c.strokeStyle = color; c.lineWidth = lineWidth; c.beginPath(); for (let cell = 0; cell < order.length; cell++) { const g = cellGroup[cell]; if (!predicate(g)) continue; const dc = cell % cols, dr = Math.floor(cell / cols), x = draw.x + dc * dw, y = draw.y + dr * dh; if (dr === 0 || cellGroup[cell - cols] !== g) { c.moveTo(x, y); c.lineTo(x + dw, y) } if (dc === cols - 1 || cellGroup[cell + 1] !== g) { c.moveTo(x + dw, y); c.lineTo(x + dw, y + dh) } if (dr === rows - 1 || cellGroup[cell + cols] !== g) { c.moveTo(x, y + dh); c.lineTo(x + dw, y + dh) } if (dc === 0 || cellGroup[cell - 1] !== g) { c.moveTo(x, y); c.lineTo(x, y + dh) } } c.stroke() }
    strokeEdges(g => groupSize[g] <= 1, 'rgba(255,255,255,.45)', 1.5)
    strokeEdges(g => groupSize[g] > 1, COLORS.gold, 5)
    const perimeter = (cells, ox, oy) => { const sel = new Set(cells); c.beginPath(); for (const cell of cells) { const dc2 = cell % cols, dr2 = Math.floor(cell / cols), x = draw.x + dc2 * dw + ox, y = draw.y + dr2 * dh + oy; if (dr2 === 0 || !sel.has(cell - cols)) { c.moveTo(x, y); c.lineTo(x + dw, y) } if (dc2 === cols - 1 || !sel.has(cell + 1)) { c.moveTo(x + dw, y); c.lineTo(x + dw, y + dh) } if (dr2 === rows - 1 || !sel.has(cell + cols)) { c.moveTo(x, y + dh); c.lineTo(x + dw, y + dh) } if (dc2 === 0 || !sel.has(cell - 1)) { c.moveTo(x, y); c.lineTo(x, y + dh) } } c.stroke() }
    if (drag && selectedGroup && selectedGroup.length) {
      c.fillStyle = 'rgba(16,42,53,.5)'
      for (const cell of selectedGroup) { const dc2 = cell % cols, dr2 = Math.floor(cell / cols); c.fillRect(draw.x + dc2 * dw, draw.y + dr2 * dh, dw, dh) }
      if (drag.target && drag.target.length) { c.strokeStyle = drag.valid ? 'rgba(120,220,140,.95)' : 'rgba(232,90,66,.95)'; c.lineWidth = 5; c.beginPath(); for (const t of drag.target) { if (t < 0) continue; const dc2 = t % cols, dr2 = Math.floor(t / cols); c.rect(draw.x + dc2 * dw + 3, draw.y + dr2 * dh + 3, dw - 6, dh - 6) } c.stroke() }
      c.save(); c.globalAlpha = 0.95
      for (const cell of selectedGroup) { const piece = order[cell], dc2 = cell % cols, dr2 = Math.floor(cell / cols), sc = piece % cols, sr = Math.floor(piece / cols); c.drawImage(image, sc * image.width / cols, sr * image.height / rows, image.width / cols, image.height / rows, draw.x + dc2 * dw + drag.dx, draw.y + dr2 * dh + drag.dy, dw, dh) }
      c.restore()
      c.strokeStyle = 'rgba(255,255,255,.98)'; c.lineWidth = 5; perimeter(selectedGroup, drag.dx, drag.dy)
    } else if (selectedGroup && selectedGroup.length) {
      c.strokeStyle = 'rgba(255,255,255,.95)'; c.lineWidth = 5; perimeter(selectedGroup, 0, 0)
    }
    c.restore(); return draw
  }
  progress(x, y, w, h, value, maximum) { this.rect(x, y, w, h, '#203d47', h / 2); this.rect(x, y, w * clamp(value / Math.max(maximum, 1), 0, 1), h, COLORS.gold, h / 2) }
}

function roundedPath(c, x, y, w, h, radius) {
  const r = Math.min(radius, w / 2, h / 2); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r); c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath()
}

function readSafeInsets() {
  const probe = document.getElementById('safe-area-probe')
  if (!probe) return { top: 0, right: 0, bottom: 0, left: 0 }
  const style = getComputedStyle(probe)
  return {
    top: parseFloat(style.paddingTop) || 0,
    right: parseFloat(style.paddingRight) || 0,
    bottom: parseFloat(style.paddingBottom) || 0,
    left: parseFloat(style.paddingLeft) || 0,
  }
}

module.exports = { Renderer, COLORS }
