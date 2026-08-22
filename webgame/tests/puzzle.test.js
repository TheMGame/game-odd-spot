const assert=require('assert')
const p=require('../js/core/puzzle')
assert.deepStrictEqual(p.createIdentityOrder(2,3),[0,1,2,3,4,5])
assert.deepStrictEqual(p.applyOperations(2,3,[{type:'swap',cells:[1,4]}]),[0,4,2,3,1,5])
assert.strictEqual(p.isSolved([0,1,2]),true)
assert.strictEqual(p.countMisplaced([0,2,1]),2)
assert.strictEqual(p.cellFromNormalizedPoint(.99,.99,2,3),5)
assert.deepStrictEqual(p.findHintSwap([0,4,2,3,1,5]),[1,4])
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3,operations:[{type:'swap',cells:[0,3]},{type:'swap',cells:[1,4]},{type:'swap',cells:[2,5]}]}).ok,true)
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3,operations:[{type:'swap',cells:[1,4]},{type:'swap',cells:[4,5]}]}).ok,false)
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3,operations:[{type:'swap',cells:[1,4]}]}).ok,true)
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3,operations:[{type:'swap',cells:[1,4]}]}, false, true).ok,false)
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3,operations:[{type:'swap',cells:[0,3]},{type:'swap',cells:[1,4]},{type:'swap',cells:[2,5]}]}, false, true).ok,true)
assert.deepStrictEqual(p.puzzleGroups([3,4,2,0,1,5],2,3),[[0,1],[2,5],[3,4]])
assert.deepStrictEqual(p.groupForCell([3,4,2,0,1,5],2,3,0),[0,1])
// two assembled blocks may swap wholesale (neither is split) — here it solves the board
assert.deepStrictEqual(p.movePuzzleGroup([3,4,2,0,1,5],2,3,0,3),[0,1,2,3,4,5])
// an assembled block slides one cell over loose (singleton) tiles, which backfill the vacated cells
assert.deepStrictEqual(p.movePuzzleGroup([5,2,3,0,1,4],2,3,3,0),[0,1,3,5,2,4])
// a move that would break an existing assembled block (here [2,5]) is rejected
assert.strictEqual(p.movePuzzleGroup([3,4,2,0,1,5],2,3,0,1),null)
// a group cannot slide past the grid boundary
assert.strictEqual(p.movePuzzleGroup([3,4,2,0,1,5],2,3,0,2),null)

// client-side random shuffle: every piece must be misplaced (derangement)
for (const [rows, cols] of [[2,2],[3,3],[4,5],[2,3]]) {
  for (let trial = 0; trial < 20; trial++) {
    const order = p.shuffleDerangement(rows, cols)
    assert.strictEqual(p.isPermutation(order, rows*cols), true)
    assert.strictEqual(order.every((piece,i)=>piece!==i), true)
  }
}
// operations are now optional (client shuffles at play time)
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3,operations:[]}, true).ok, true)
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3}, true).ok, true)
assert.strictEqual(p.validatePuzzleConfig({rows:2,cols:3,operations:[]}, false).ok, false)
