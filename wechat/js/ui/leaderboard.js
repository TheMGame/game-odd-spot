const { COLORS } = require('../core/renderer')

function medal(rank) {
  if (rank === 1) return { mark: '冠', fill: '#c89b35', text: '#fff8df' }
  if (rank === 2) return { mark: '银', fill: '#89939b', text: '#ffffff' }
  if (rank === 3) return { mark: '铜', fill: '#a96d45', text: '#fff6ea' }
  return { mark: String(rank), fill: '#27394c', text: '#e9d49b' }
}
function icon(r, kind, x, y, color) {
  if (kind === 'search') { r.circle(x - 7, y - 6, 15, 'transparent', color, 5); r.line(x + 4, y + 6, x + 21, y + 23, color, 6); return }
  if (kind === 'museum') { r.line(x - 24, y - 13, x, y - 28, color, 5); r.line(x, y - 28, x + 24, y - 13, color, 5); r.line(x - 29, y + 24, x + 29, y + 24, color, 5); for (let i = -1; i <= 1; i++) r.line(x + i * 18, y - 9, x + i * 18, y + 19, color, 4); return }
  if (kind === 'trophy') { r.rect(x - 20, y - 22, 40, 28, color, 6); r.rect(x - 20, y - 22, 10, 28, color, 0, color, 4); r.rect(x + 10, y - 22, 10, 28, color, 0, color, 4); r.ctx.beginPath(); r.ctx.moveTo(x - 30, y - 18); r.ctx.quadraticCurveTo(x - 44, y - 4, x - 30, y + 2); r.ctx.lineTo(x - 20, y + 2); r.ctx.lineTo(x - 20, y - 18); r.ctx.closePath(); r.ctx.fillStyle = color; r.ctx.fill(); r.ctx.beginPath(); r.ctx.moveTo(x + 30, y - 18); r.ctx.quadraticCurveTo(x + 44, y - 4, x + 30, y + 2); r.ctx.lineTo(x + 20, y + 2); r.ctx.lineTo(x + 20, y - 18); r.ctx.closePath(); r.ctx.fillStyle = color; r.ctx.fill(); r.rect(x - 8, y + 6, 16, 10, color, 2); r.rect(x - 20, y + 16, 40, 8, color, 2); return }
  r.circle(x, y - 12, 11, color); r.ctx.beginPath(); r.ctx.arc(x, y + 22, 24, Math.PI, Math.PI * 2); r.ctx.fillStyle = color; r.ctx.fill()
}
function renderBottomNav(app, activeIndex) {
  const r = app.renderer, h = r.height, navH = 118 + r.safeBottom, navY = h - navH
  r.rect(0, navY, 1080, navH, '#0d1a2a', 0, '#c3a769', 2)
  ;[['home', 'search', '案件', '开始调查'], ['museum', 'museum', '博物馆', '珍藏与成就'], ['leaderboard', 'trophy', '排行榜', '侦探风云榜'], ['profile', 'profile', '我的', '侦探档案']].forEach((n, i) => { const x = i * 270, active = i === activeIndex; if (active) r.rect(x + 15, navY + 12, 240, 82, 'rgba(255,246,222,.14)', 13, 'rgba(239,211,150,.4)', 1); icon(r, n[1], x + 60, navY + 53, '#f0d28f'); r.text(n[2], x + 100, navY + 41, 25, active ? '#f2d68f' : '#fff', 'left', 'bold'); r.text(n[3], x + 100, navY + 72, 17, active ? '#dbae4d' : '#9ea7b0'); r.register(n[0], { x, y: navY, w: 270, h: navH }) })
  return navH
}

function renderLeaderboard(app) {
  const r = app.renderer, h = r.height, top = r.safeTop, board = app.leaderboard || {}, stats = app.playerStats || {}, levelScope = board.scope === 'level'
  r.rect(0, 0, 1080, h, '#f4ead7')
  r.rect(0, 0, 1080, 176 + top, '#0e1b2b')
  r.iconButton('home', 28, 34 + top, 88, 'back')
  r.text('侦探排行榜', 540, 65 + top, 44, '#f1d28e', 'center', 'bold')
  r.text(levelScope ? '当前案件 · 单关最高分' : '全球永久榜 · 难度积分', 540, 116 + top, 22, '#c9b990', 'center')

  const mine = board.my_entry || null, myY = 196 + top
  r.rect(42, myY, 996, 170, '#182638', 22, '#c7a86b', 3)
  r.circle(112, myY + 85, 48, '#a63c2d', '#e1bd70', 3)
  r.text(`Lv.${Number(stats.player_level || 1)}`, 112, myY + 85, 25, '#fff6dd', 'center', 'bold')
  r.text(app.session.data.username || stats.display_name || '我的侦探档案', 184, myY + 56, 30, '#fff4d6', 'left', 'bold', 430)
  r.text(mine ? `全球第 ${mine.rank} 名` : '完成关卡后参与排名', 184, myY + 105, 22, '#cab98f')
  const mineValue = mine ? (levelScope ? `${mine.score} 分` : `${mine.points} 积分`) : (levelScope ? '—' : `${Number(stats.total_points || 0)} 积分`)
  r.text(mineValue, 990, myY + 73, 38, '#f2ca6c', 'right', 'bold')
  if (!levelScope) r.text(`${Number(stats.completed_levels || 0)} 关 · 均分 ${Number(stats.average_score || 0)}`, 990, myY + 118, 20, '#c9b990', 'right')

  const navH = renderBottomNav(app, 2)
  const clip = { x: 30, y: myY + 195, w: 1020, h: h - myY - 225 - navH }, c = r.ctx
  c.save(); c.beginPath(); c.rect(clip.x, clip.y, clip.w, clip.h); c.clip()
  let y = clip.y - (app.scroll.leaderboard || 0)
  if (board.loading) r.text('正在整理侦探档案…', 540, y + 110, 28, '#786a58', 'center')
  else if (board.error) r.text(String(board.error), 540, y + 110, 28, '#a33d2e', 'center')
  else if (!(board.entries || []).length) r.text('暂无排名，成为第一位破案的侦探吧', 540, y + 110, 27, '#786a58', 'center')
  else (board.entries || []).forEach((entry) => {
    const row = { x: 42, y, w: 996, h: 116 }, style = medal(Number(entry.rank || 0))
    r.rect(row.x, row.y, row.w, row.h, entry.is_me ? '#f2e3bf' : '#fffaf0', 16, entry.is_me ? '#b98e3f' : '#ded0b7', entry.is_me ? 3 : 1)
    r.circle(row.x + 58, row.y + 58, 34, style.fill)
    r.text(style.mark, row.x + 58, row.y + 58, Number(entry.rank) <= 3 ? 20 : 24, style.text, 'center', 'bold')
    r.text(entry.is_me ? (app.session.data.username || '我') : (entry.display_name || `侦探·${String(entry.user_id || '').slice(-6)}`), row.x + 112, row.y + 42, 27, '#27231e', 'left', 'bold', 470)
    const detail = levelScope ? `提示 ${Number(entry.hints_used || 0)} · 误触 ${Number(entry.wrong_taps || 0)}` : `${Number(entry.completed_levels || 0)} 关 · 均分 ${Number(entry.score || 0)}`
    r.text(detail, row.x + 112, row.y + 79, 19, '#786a58')
    r.text(levelScope ? `${Number(entry.score || 0)} 分` : `${Number(entry.points || 0)} 积分`, row.x + row.w - 28, row.y + 57, 31, entry.is_me ? '#9e3528' : '#26384a', 'right', 'bold')
    y += 132
  })
  c.restore()
  app.maxScroll = Math.max(0, y + (app.scroll.leaderboard || 0) - clip.y - clip.h + 20)
}

module.exports = { renderLeaderboard }
