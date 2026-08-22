class AudioManager {
  constructor(preferences) {
    this.preferences = preferences
    this.players = {}
    this.lastClickAt = 0
  }

  start() {
    this.players.click = this.create('assets/audio/ui_click.wav', false, 0.56)
    this.players.correct = this.create('assets/audio/correct.wav', false, 0.63)
    this.loadMediaSubpackage()
  }

  loadMediaSubpackage() {
    const ready = () => {
      this.players.complete = this.create('subpackages/media/assets/audio/complete.wav', false, 0.56)
      this.players.music = this.create('subpackages/media/assets/audio/quiet_search_loop.wav', true, 0.13)
      if (this.preferences.data.music) this.players.music.play()
    }
    if (typeof wx.loadSubpackage !== 'function') { ready(); return }
    const task = wx.loadSubpackage({ name: 'media', success: ready, fail: (error) => console.warn('[OddSpot] media subpackage failed', error) })
    if (task && task.onProgressUpdate) task.onProgressUpdate(() => {})
  }

  create(src, loop, volume) {
    const audio = wx.createInnerAudioContext({ useWebAudioImplement: true })
    audio.src = src
    audio.loop = loop
    audio.volume = volume
    audio.onError((error) => console.warn('[OddSpot] optional audio failed', src, error))
    return audio
  }

  click() {
    const now = Date.now()
    if (now - this.lastClickAt < 50) return
    this.lastClickAt = now
    this.effect('click')
  }
  correct() { this.effect('correct') }
  complete() { this.effect('complete') }
  effect(name) { if (this.preferences.data.effects && this.players[name]) { this.players[name].stop(); this.players[name].play() } }
  currentMusic() { return this.players.levelMusic || this.players.music }
  setMusic(enabled) { this.preferences.set('music', enabled); if (enabled) { const track = this.currentMusic(); if (track) track.play() } else { if (this.players.music) this.players.music.pause(); if (this.players.levelMusic) this.players.levelMusic.pause() } }
  setEffects(enabled) { this.preferences.set('effects', enabled) }
  // Play a level's custom background music (looping). Falsy url reverts to the default track.
  setLevelMusic(url, volume = 0.4) {
    if (!url) { this.clearLevelMusic(); return }
    if (this.levelMusicUrl !== url) { this.destroyLevelMusic(); this.players.levelMusic = this.create(url, true, volume); this.levelMusicUrl = url }
    if (this.players.music) this.players.music.pause()
    if (this.preferences.data.music) this.players.levelMusic.play()
  }
  clearLevelMusic() {
    this.destroyLevelMusic()
    if (this.preferences.data.music && this.players.music) this.players.music.play()
  }
  destroyLevelMusic() { if (this.players.levelMusic) { this.players.levelMusic.stop(); if (this.players.levelMusic.destroy) this.players.levelMusic.destroy(); this.players.levelMusic = null; this.levelMusicUrl = '' } }
  pause() { if (this.players.music) this.players.music.pause(); if (this.players.levelMusic) this.players.levelMusic.pause() }
  resume() { if (this.preferences.data.music) { const track = this.currentMusic(); if (track) track.play() } }
}

module.exports = { AudioManager }
