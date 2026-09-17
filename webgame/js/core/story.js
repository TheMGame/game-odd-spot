'use strict'

const NODE_TYPES = new Set(['scene', 'dialogue', 'choice', 'hotspot', 'evidence', 'sequence', 'puzzle', 'ending'])

function validateStory(story) {
  if (!story || typeof story !== 'object') return { ok: false, error: 'STORY_MISSING' }
  if (!story.start_node || !story.nodes || typeof story.nodes !== 'object' || Array.isArray(story.nodes)) return { ok: false, error: 'STORY_STRUCTURE_INVALID' }
  if (!story.nodes[story.start_node]) return { ok: false, error: 'STORY_START_NODE_MISSING' }
  const ids = Object.keys(story.nodes)
  if (!ids.length || ids.length > 300) return { ok: false, error: 'STORY_NODE_COUNT_INVALID' }
  let endings = 0
  for (const id of ids) {
    const node = story.nodes[id]
    if (!node || !NODE_TYPES.has(node.type)) return { ok: false, error: `STORY_NODE_TYPE_INVALID:${id}` }
    if (node.type === 'ending') endings++
    const targets = []
    if (node.next) targets.push(node.next)
    for (const option of node.choices || []) { if (!option.id || !option.label || !option.next) return { ok: false, error: `STORY_CHOICE_INVALID:${id}` }; targets.push(option.next) }
    for (const spot of node.hotspots || []) { if (!spot.id || !Number.isFinite(spot.x) || !Number.isFinite(spot.y) || spot.x < 0 || spot.x > 1 || spot.y < 0 || spot.y > 1) return { ok: false, error: `STORY_HOTSPOT_INVALID:${id}` } }
    if (node.type === 'sequence' && (!Array.isArray(node.items) || !Array.isArray(node.correct_order))) return { ok: false, error: `STORY_SEQUENCE_INVALID:${id}` }
    for (const target of targets) if (!story.nodes[target]) return { ok: false, error: `STORY_TARGET_MISSING:${id}:${target}` }
  }
  if (!endings) return { ok: false, error: 'STORY_ENDING_MISSING' }
  return { ok: true }
}

function createStoryState(story, saved) {
  const previous = saved && typeof saved === 'object' ? saved : {}
  const nodeId = story.nodes[previous.node_id] ? previous.node_id : story.start_node
  return {
    node_id: nodeId,
    visited: Array.isArray(previous.visited) ? previous.visited.slice(0, 300) : [],
    variables: Object.assign({}, previous.variables || {}),
    evidence: Array.isArray(previous.evidence) ? previous.evidence.slice() : [],
    hotspots: Object.assign({}, previous.hotspots || {}),
    sequences: Object.assign({}, previous.sequences || {}),
    puzzles: Object.assign({}, previous.puzzles || {}),
    completed: Boolean(previous.completed),
    ending_id: previous.ending_id || '',
  }
}

class StoryRuntime {
  constructor(story, saved) { this.story = story; this.state = createStoryState(story, saved); this.enter(this.state.node_id, false) }
  node() { return this.story.nodes[this.state.node_id] }
  snapshot() { return JSON.parse(JSON.stringify(this.state)) }
  enter(id, remember = true) {
    if (!this.story.nodes[id]) return false
    if (remember && !this.state.visited.includes(this.state.node_id)) this.state.visited.push(this.state.node_id)
    this.state.node_id = id
    const node = this.node()
    if (node.set) Object.assign(this.state.variables, node.set)
    if (node.evidence_id && !this.state.evidence.includes(node.evidence_id)) this.state.evidence.push(node.evidence_id)
    if (node.type === 'ending') { this.state.completed = true; this.state.ending_id = node.ending_id || id }
    return true
  }
  next() { const node = this.node(); return node && node.next ? this.enter(node.next) : false }
  choose(id) { const option = (this.node().choices || []).find((item) => String(item.id) === String(id)); if (!option) return false; if (option.set) Object.assign(this.state.variables, option.set); return this.enter(option.next) }
  findHotspot(id) {
    const node = this.node(), spot = (node.hotspots || []).find((item) => String(item.id) === String(id)); if (!spot) return false
    const found = this.state.hotspots[node.id || this.state.node_id] || []
    if (!found.includes(spot.id)) found.push(spot.id)
    this.state.hotspots[node.id || this.state.node_id] = found
    if (spot.evidence_id && !this.state.evidence.includes(spot.evidence_id)) this.state.evidence.push(spot.evidence_id)
    const required = Number(node.required || (node.hotspots || []).length)
    if (found.length >= required && node.next) this.enter(node.next)
    return true
  }
  selectSequence(id) {
    const node = this.node(), valid = (node.items || []).some((item) => String(item.id) === String(id)); if (!valid) return false
    const selected = this.state.sequences[this.state.node_id] || []
    if (selected.includes(id)) return false
    selected.push(id); this.state.sequences[this.state.node_id] = selected
    if (selected.length === node.correct_order.length) {
      if (selected.map(String).join('|') === node.correct_order.map(String).join('|')) { if (node.next) this.enter(node.next) }
      else this.state.sequences[this.state.node_id] = []
    }
    return true
  }
  completePuzzle(moves) { const node=this.node(); if(!node||node.type!=='puzzle')return false;this.state.puzzles[this.state.node_id]={completed:true,moves:Number(moves)||0};return node.next?this.enter(node.next):true }
}

module.exports = { NODE_TYPES, validateStory, createStoryState, StoryRuntime }
