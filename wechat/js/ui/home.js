const { COLORS } = require('../core/renderer')

function progress(app, series) { const levels = series && Array.isArray(series.levels) ? series.levels : []; return { done: levels.filter((level) => app.isLevelCompleted(level)).length, total: levels.length } }
function scoreFor(app, levelId) { return ((app.playerStats && app.playerStats.level_scores) || []).find((item) => String(item.level_id) === String(levelId)) || null }
function seriesScore(app, series) { return (series.levels || []).reduce((sum, level) => sum + Number((scoreFor(app, level.id) || {}).score || 0), 0) }
function continueCase(app) { const list = app.enabledSeries(), configuredId = app.catalogData && app.catalogData.home && app.catalogData.home.hero_series_id, series = list.find((item) => configuredId && String(item.id) === String(configuredId)) || list.find((item) => Array.isArray(item.levels) && item.levels.some((level) => !app.isLevelCompleted(level))) || list.find((item) => Array.isArray(item.levels) && item.levels.length) || list[0]; return series ? { series, level: (series.levels || []).find((level) => !app.isLevelCompleted(level)) || (series.levels || [])[0], stat: progress(app, series) } : null }
function icon(r, kind, x, y, color) {
  if (kind === 'star') return r.text('★', x, y, 38, color, 'center', 'bold')
  if (kind === 'search') { r.circle(x - 7, y - 6, 15, 'transparent', color, 5); r.line(x + 4, y + 6, x + 21, y + 23, color, 6); return }
  if (kind === 'museum') { r.line(x - 24, y - 13, x, y - 28, color, 5); r.line(x, y - 28, x + 24, y - 13, color, 5); r.line(x - 29, y + 24, x + 29, y + 24, color, 5); for (let i = -1; i <= 1; i++) r.line(x + i * 18, y - 9, x + i * 18, y + 19, color, 4); return }
  if (kind === 'trophy') { r.rect(x - 20, y - 22, 40, 28, color, 6); r.rect(x - 20, y - 22, 10, 28, color, 0, color, 4); r.rect(x + 10, y - 22, 10, 28, color, 0, color, 4); r.ctx.beginPath(); r.ctx.moveTo(x - 30, y - 18); r.ctx.quadraticCurveTo(x - 44, y - 4, x - 30, y + 2); r.ctx.lineTo(x - 20, y + 2); r.ctx.lineTo(x - 20, y - 18); r.ctx.closePath(); r.ctx.fillStyle = color; r.ctx.fill(); r.ctx.beginPath(); r.ctx.moveTo(x + 30, y - 18); r.ctx.quadraticCurveTo(x + 44, y - 4, x + 30, y + 2); r.ctx.lineTo(x + 20, y + 2); r.ctx.lineTo(x + 20, y - 18); r.ctx.closePath(); r.ctx.fillStyle = color; r.ctx.fill(); r.rect(x - 8, y + 6, 16, 10, color, 2); r.rect(x - 20, y + 16, 40, 8, color, 2); return }
  r.circle(x, y - 12, 11, color); r.ctx.beginPath(); r.ctx.arc(x, y + 22, 24, Math.PI, Math.PI * 2); r.ctx.fillStyle = color; r.ctx.fill()
}
function renderBunny(app) {
  const r = app.renderer, c = r.ctx, top = r.safeTop, anim = app._homeBunnyAnim
  if (!(top > 40 && anim && anim.loaded && anim.frames.length)) { app._homeBunnyArea = null; return }
  const size = Math.max(140, Math.min(Math.round(top * 1.1), 320)), left = 18, right = r.width - 18 - size
  app._homeBunnyArea = { y: 0, h: top, left, right, size }
  anim.x = Math.max(left, Math.min(right, anim.x))
  const image = anim.frames[anim.frame % anim.frames.length]
  if (!image || !(image.width > 0 && image.height > 0)) return
  const y = (top - size) / 2, fit = Math.min(size / image.width, size / image.height), w = Math.round(image.width * fit), h = Math.round(image.height * fit), x = Math.round(anim.x + (size - w) / 2), dy = Math.round(y + (size - h) / 2)
  c.save(); c.globalCompositeOperation = 'source-over'; c.globalAlpha = 1
  if (anim.dir < 0) { const cx = anim.x + size / 2, cy = y + size / 2; c.translate(cx, cy); c.scale(-1, 1); c.translate(-cx, -cy) }
  c.drawImage(image, 0, 0, image.width, image.height, x, dy, w, h); c.restore()
}
function renderHome(app) {
  const r = app.renderer, c = r.ctx, h = r.height, top = r.safeTop, art = app.homeArt || {}, home = app.catalogData && app.catalogData.home || {}, scroll = app.scroll.home || 0
  r.rect(0, 0, 1080, h, '#f4ead7'); r.rect(0, 0, 1080, 214 + top, '#0e1b2b')
  if (art.header) { c.save(); c.globalAlpha = .08; r.image(art.header, { x: 0, y: 0, w: 1080, h: 214 + top }, 'cover'); c.restore() }
  renderBunny(app)
  if (art.logo) r.image(art.logo, { x: 38, y: 24 + top, w: 104, h: 104 }, 'contain')
  r.text(home.brand_title || '', 154, 67 + top, 45, '#f1d28e', 'left', 'bold'); r.text(home.brand_subtitle || '', 157, 112 + top, 14, '#e4c879', 'left', 'bold')
  const stats = app.homeStats || { completed: 0, total: 0 }, player = app.playerStats || {}, exp = Number(player.level_progress || 0), expMax = Math.max(1, Number(player.next_level_points || 100)), level = Math.max(1, Number(player.player_level || 1))
  r.text(`Lv.${level}`, 408, 58 + top, 27, '#f3d899', 'left', 'bold'); r.text(home.detective_title || '', 493, 58 + top, 24, '#fff8e9'); r.progress(408, 91 + top, 232, 12, exp, expMax); r.text(`${exp}/${expMax} 等级积分`, 524, 119 + top, 18, '#efe5d0', 'center')
  icon(r, 'star', 724, 74 + top, '#f5c44c'); r.text(String(Number(player.total_points || 0)), 757, 75 + top, 30, '#fff', 'left', 'bold'); r.register('topLeaderboard', { x: 700, y: 28 + top, w: 205, h: 100 }); r.headerIconButton('settings', 931, 30 + top, 82, 'settings')
  const navH = 118 + r.safeBottom, contentTop = 150 + top, clip = { x: 18, y: contentTop, w: 1044, h: h - contentTop - navH }
  c.save(); c.beginPath(); c.rect(clip.x, clip.y, clip.w, clip.h); c.clip(); let y = contentTop + 6 - scroll
  const active = continueCase(app), hero = { x: 42, y, w: 996, h: 510 }; r.rect(hero.x, hero.y, hero.w, hero.h, '#162638', 28, '#cfb16f', 4)
  const heroImage = active && app.covers[active.series.id] ? app.covers[active.series.id] : art.hero; if (heroImage) r.image(heroImage, { x: hero.x + 4, y: hero.y + 4, w: hero.w - 8, h: hero.h - 8 }, 'cover')
  const g = c.createLinearGradient(hero.x, 0, hero.x + hero.w * .72, 0); if (g && g.addColorStop) { g.addColorStop(0, 'rgba(8,19,29,.94)'); g.addColorStop(.6, 'rgba(8,19,29,.42)'); g.addColorStop(1, 'rgba(8,19,29,0)'); c.fillStyle = g } else c.fillStyle = 'rgba(8,19,29,.58)'; c.fillRect(hero.x + 4, hero.y + 4, hero.w - 8, hero.h - 8)
  const activeTitle = active && (active.series.title || active.series.display_name || active.series.id) || '暂无可用章节', activeDescription = active && (active.series.description || active.level && active.level.title) || '请在内容后台发布章节与关卡'
  r.rect(hero.x + 4, hero.y + 4, 210, 58, '#a83a2d'); r.text(home.hero_badge || '', hero.x + 108, hero.y + 34, 28, '#fff5df', 'center', 'bold'); r.text(home.hero_label || '', hero.x + 42, hero.y + 128, 24, '#f5e9ce')
  r.text(activeTitle, hero.x + 42, hero.y + 194, 58, '#fff4d6', 'left', 'bold', 470); r.text(activeDescription, hero.x + 42, hero.y + 250, 25, '#eee4d2', 'left', 'normal', 470)
  const done = active ? active.stat.done : 0, total = active && active.stat.total ? active.stat.total : 8; r.text(`第 ${Math.min(done + 1, total)} / ${total} 案`, hero.x + 42, hero.y + 316, 25, '#fff'); icon(r, 'star', hero.x + 250, hero.y + 316, '#f5c44c'); r.text(`${active ? seriesScore(app, active.series) : 0} 分`, hero.x + 280, hero.y + 316, 25, '#f1d28e'); r.progress(hero.x + 42, hero.y + 353, 340, 15, done, total); r.text(`${Math.round(done / Math.max(total, 1) * 100)}%`, hero.x + 398, hero.y + 361, 22, '#fff')
  r.button('continueCase', { x: hero.x + 40, y: hero.y + 398, w: 310, h: 78 }, `${home.hero_button || ''}  ▶`, { fill: '#efc86f', border: '#b58a39', color: '#172233', size: 30, weight: 'bold', radius: 16 }); y += 540
  const dailyTarget = Math.max(1, Number(home.daily_target || 1)), dailyDone = Math.min(stats.completed, dailyTarget), daily = { x: 42, y, w: 996, h: 128 }; r.rect(daily.x, daily.y, daily.w, daily.h, '#f7eddc', 18, '#decaa5', 2); icon(r, 'search', daily.x + 55, daily.y + 62, '#664d2b'); r.text(home.daily_title || '', daily.x + 105, daily.y + 64, 32, '#211e1b', 'left', 'bold'); r.text(home.daily_description || '', daily.x + 318, daily.y + 38, 20, '#4b4032'); r.progress(daily.x + 318, daily.y + 72, 250, 12, dailyDone, dailyTarget); r.text(`${dailyDone} / ${dailyTarget}`, daily.x + 582, daily.y + 78, 20, '#2d2923'); r.text(home.daily_reward || '', daily.x + 664, daily.y + 63, 21, '#362d24'); r.button('daily', { x: daily.x + 815, y: daily.y + 30, w: 155, h: 70 }, home.hero_button || '', { fill: '#162236', border: '#344155', size: 22, radius: 12 })
  y += 172; r.text(home.worlds_title || '', 45, y, 32, '#28231d', 'left', 'bold'); r.text(`${home.worlds_link_text || ''}  ›`, 1018, y, 22, '#786a58', 'right'); y += 42
  const worldEntries = app.enabledSeries().map((series) => ({ series, title: series.title || series.display_name || series.id, subtitle: series.description || '' }))
  worldEntries.forEach(({ series, title, subtitle }, index) => { const col = index % 3, row = Math.floor(index / 3), rect = { x: 42 + col * 332, y: y + row * 282, w: 310, h: 258 }; r.rect(rect.x, rect.y, rect.w, rect.h, '#1a2633', 18, '#d4b975', 2); const cover = app.covers[series.id]; if (cover) r.image(cover, rect, 'cover'); r.gradientRect(rect.x, rect.y + 125, rect.w, 133, [[0, 'rgba(8,13,18,0)'], [1, 'rgba(7,12,18,.88)']], 16); r.text(title, rect.x + 18, rect.y + 170, 29, '#fff4d8', 'left', 'bold', rect.w - 36); r.text(subtitle, rect.x + 18, rect.y + 205, 18, '#fff', 'left', 'normal', rect.w - 36); icon(r, 'star', rect.x + 31, rect.y + 235, '#f4c14c'); r.text(`${seriesScore(app, series)} 分`, rect.x + 52, rect.y + 237, 18, '#fff'); r.register(`series:${series.id}`, rect) })
  y += Math.max(1, Math.ceil(worldEntries.length / 3)) * 282 + 25; r.text(home.museum_title || '', 45, y, 32, '#28231d', 'left', 'bold'); r.text(`${home.museum_link_text || ''}  ›`, 1018, y, 22, '#786a58', 'right'); y += 38
  const configuredMuseum = app.catalogData && app.catalogData.museum, recent = configuredMuseum && Array.isArray(configuredMuseum.items) ? configuredMuseum.items.find(item => item.unlocked) : null
  const museum = { x: 42, y, w: 996, h: 150 }; r.rect(museum.x, museum.y, museum.w, museum.h, '#f2e2c4', 16, '#dcc59d', 2); const recentImage = recent && app.covers[`museum:${recent.id}`] || art.collection; if (recentImage) r.image(recentImage, { x: museum.x + 14, y: museum.y + 8, w: 132, h: 132 }, 'contain'); r.text(recent ? recent.name : '', museum.x + 150, museum.y + 55, 25, '#2d261f', 'left', 'bold'); r.text(recent ? recent.description : '', museum.x + 150, museum.y + 93, 18, '#746554')
  for (let i = 0; i < 2; i++) { const x = museum.x + 485 + i * 225; if (art.collection) { c.save(); c.globalAlpha = .24; r.image(art.collection, { x, y: museum.y + 22, w: 92, h: 92 }, 'contain'); c.restore() } r.text('???', x + 112, museum.y + 52, 23, '#635748'); r.text('收集进度', x + 112, museum.y + 88, 17, '#766956') }
  r.register('museum', museum); y += 178; c.restore(); app.maxScroll = Math.max(0, y + scroll - clip.y - clip.h)
  const navY = h - navH; r.rect(0, navY, 1080, navH, '#0d1a2a', 0, '#c3a769', 2); [['home', 'search', '案件', '开始调查'], ['museum', 'museum', '博物馆', '珍藏与成就'], ['leaderboard', 'trophy', '排行榜', '侦探风云榜'], ['profile', 'profile', '我的', '侦探档案']].forEach((n, i) => { const x = i * 270, activeNav = i === 0; if (activeNav) r.rect(x + 15, navY + 12, 240, 82, 'rgba(255,246,222,.14)', 13, 'rgba(239,211,150,.4)', 1); icon(r, n[1], x + 60, navY + 53, '#f0d28f'); r.text(n[2], x + 100, navY + 41, 25, activeNav ? '#f2d68f' : '#fff', 'left', 'bold'); r.text(n[3], x + 100, navY + 72, 17, activeNav ? '#dbae4d' : '#9ea7b0'); r.register(n[0], { x, y: navY, w: 270, h: navH }) })
}

function renderMuseum(app) {
  const r = app.renderer, c = r.ctx, h = r.height, top = r.safeTop, art = app.homeArt || {}, scroll = app.scroll.museum || 0
  r.rect(0, 0, 1080, h, '#f4ead7'); r.rect(0, 0, 1080, 166 + top, '#0e1b2b')
  if (art.header) { c.save(); c.globalAlpha = .08; r.image(art.header, { x: 0, y: 0, w: 1080, h: 166 + top }, 'cover'); c.restore() }
  r.headerIconButton('home', 34, 30 + top, 82, 'back')
  const config = app.catalogData && app.catalogData.museum || { title: '大侦探博物馆', subtitle: '珍藏每一段被还原的历史', items: [] }, configuredItems = Array.isArray(config.items) ? config.items.slice().sort((a, b) => Number(a.sort_order || 0) - Number(b.sort_order || 0)) : []
  icon(r, 'museum', 170, 76 + top, '#f0d28f'); r.text(config.title || '大侦探博物馆', 222, 66 + top, 42, '#f1d28e', 'left', 'bold'); r.text(config.subtitle || '', 224, 112 + top, 19, '#c9b990')
  const navH = 118 + r.safeBottom, clip = { x: 18, y: 166 + top, w: 1044, h: h - 166 - top - navH }
  c.save(); c.beginPath(); c.rect(clip.x, clip.y, clip.w, clip.h); c.clip(); let y = clip.y + 36 - scroll
  const unlockedCount = configuredItems.filter(item => item.unlocked).length, totalCount = configuredItems.length
  r.rect(42, y, 996, 164, '#182638', 22, '#c7a86b', 2); r.text('收藏总览', 76, y + 42, 25, '#ead8ac'); r.text(String(unlockedCount), 78, y + 103, 52, '#f4ce75', 'left', 'bold'); r.text(`/ ${totalCount} 件珍藏`, 116, y + 110, 23, '#fff5df'); r.progress(600, y + 78, 370, 16, unlockedCount, Math.max(totalCount, 1)); r.text('完成配置的调查条件即可解锁', 785, y + 119, 18, '#c9b990', 'center'); y += 210
  r.text(configuredItems[0] && configuredItems[0].group || '博物馆藏品', 44, y, 32, '#28231d', 'left', 'bold'); r.text('主题收藏', 1018, y, 20, '#786a58', 'right'); y += 38
  configuredItems.forEach((item, index) => {
    const title = item.name || item.id, desc = item.description || '', unlocked = !!item.unlocked
    const col = index % 2, row = Math.floor(index / 2), rect = { x: 42 + col * 506, y: y + row * 250, w: 486, h: 224 }
    r.rect(rect.x, rect.y, rect.w, rect.h, unlocked ? '#f1dfbc' : '#e6dccb', 18, unlocked ? '#c6a25a' : '#cfc3ae', 2)
    const image = app.covers[`museum:${item.id}`] || (unlocked ? art.scroll : art.collection)
    if (image) { c.save(); c.globalAlpha = unlocked ? 1 : .22; r.image(image, { x: rect.x + 20, y: rect.y + 18, w: 170, h: 170 }, 'contain'); c.restore() }
    if (!unlocked) { r.circle(rect.x + 104, rect.y + 105, 31, 'rgba(20,28,38,.72)'); r.text('锁', rect.x + 104, rect.y + 106, 22, '#f5dfaa', 'center', 'bold') }
    r.text(unlocked ? '已收藏' : '尚未解锁', rect.x + 210, rect.y + 43, 18, unlocked ? '#9b3428' : '#817667', 'left', 'bold'); r.text(title, rect.x + 210, rect.y + 88, 27, '#2d261f', 'left', 'bold', 245); r.wrappedText(desc, rect.x + 210, rect.y + 130, 240, 17, '#746554', 26, 2)
  })
  if (!configuredItems.length) r.text('后台尚未配置藏品', 540, y + 100, 26, '#786a58', 'center')
  y += Math.max(1, Math.ceil(configuredItems.length / 2)) * 250 + 30; c.restore(); app.maxScroll = Math.max(0, y + scroll - clip.y - clip.h)
  const navY = h - navH; r.rect(0, navY, 1080, navH, '#0d1a2a', 0, '#c3a769', 2)
  ;[['home', 'search', '案件', '开始调查'], ['museum', 'museum', '博物馆', '珍藏与成就'], ['leaderboard', 'trophy', '排行榜', '侦探风云榜'], ['profile', 'profile', '我的', '侦探档案']].forEach((n, i) => { const x = i * 270, active = i === 1; if (active) r.rect(x + 15, navY + 12, 240, 82, 'rgba(255,246,222,.14)', 13, 'rgba(239,211,150,.4)', 1); icon(r, n[1], x + 60, navY + 53, '#f0d28f'); r.text(n[2], x + 100, navY + 41, 25, active ? '#f2d68f' : '#fff', 'left', 'bold'); r.text(n[3], x + 100, navY + 72, 17, active ? '#dbae4d' : '#9ea7b0'); r.register(n[0], { x, y: navY, w: 270, h: navH }) })
}

module.exports = { renderHome, renderMuseum }
