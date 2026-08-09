class AudioManager {
  constructor(preferences) {
    this.preferences = preferences
    this.players = {}
    this.lastClickAt = 0
    this.unlocked = false
  }

  start() {
    this.players.click = this.create('assets/audio/ui_click.wav', false, 0.56)
    this.players.correct = this.create('assets/audio/correct.wav', false, 0.63)
    this.players.complete = this.create('assets/audio/complete.wav', false, 0.56)
    this.players.music = this.create('assets/audio/quiet_search_loop.wav', true, 0.13)
    const unlock = () => {
      if (this.unlocked) return
      this.unlocked = true
      if (this.preferences.data.music) this.play(this.players.music)
    }
    window.addEventListener('pointerdown', unlock, { once: true, passive: true })
    window.addEventListener('keydown', unlock, { once: true, passive: true })
  }

  create(src, loop, volume) {
    const audio = new Audio(src)
    audio.preload = 'metadata'
    audio.loop = loop
    audio.volume = volume
    return audio
  }

  play(player) {
    if (!player) return
    const promise = player.play()
    if (promise && promise.catch) promise.catch(() => {})
  }
  click() {
    const now = Date.now()
    if (now - this.lastClickAt < 50) return
    this.lastClickAt = now
    this.effect('click')
  }
  correct() { this.effect('correct') }
  complete() { this.effect('complete') }
  effect(name) {
    const player = this.players[name]
    if (!this.preferences.data.effects || !player) return
    player.pause(); player.currentTime = 0; this.play(player)
  }
  setMusic(enabled) { this.preferences.set('music', enabled); if (enabled && this.unlocked) this.play(this.players.music); else this.players.music.pause() }
  setEffects(enabled) { this.preferences.set('effects', enabled) }
  pause() { if (this.players.music) this.players.music.pause() }
  resume() { if (this.preferences.data.music && this.unlocked) this.play(this.players.music) }
}

module.exports = { AudioManager }
