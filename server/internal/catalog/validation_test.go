package catalog

import "testing"

func puzzleRuntime() map[string]any {
	operations := make([]any, 0, 10)
	for cell := 0; cell < 20; cell += 2 {
		operations = append(operations, map[string]any{"type": "swap", "cells": []any{float64(cell), float64(cell + 1)}})
	}
	return map[string]any{"mode": "image_puzzle", "assets": map[string]any{"image": map[string]any{"url": "https://example.com/a.png"}, "width": 1024.0, "height": 1024.0}, "puzzle": map[string]any{"rows": 4.0, "cols": 5.0, "operations": operations}}
}

func TestValidatePuzzleRuntime(t *testing.T) {
	if err := validateRuntimeLevel(puzzleRuntime(), true); err != nil {
		t.Fatal(err)
	}
}

func TestValidateInteractiveStory(t *testing.T) {
	runtime := map[string]any{"mode": "interactive_story", "assets": map[string]any{}, "story": map[string]any{"start_node": "intro", "nodes": map[string]any{"intro": map[string]any{"type": "scene", "next": "ending"}, "ending": map[string]any{"type": "ending", "ending_id": "solved"}}}}
	if err := validateRuntimeLevel(runtime, true); err != nil {
		t.Fatalf("valid story rejected: %v", err)
	}
	runtime["story"].(map[string]any)["start_node"] = "missing"
	if err := validateRuntimeLevel(runtime, true); err == nil {
		t.Fatal("missing start node accepted")
	}
}

func TestValidateSharedTimeLimit(t *testing.T) {
	runtime := puzzleRuntime()
	runtime["time_limit_seconds"] = 180.0
	if err := validateRuntimeLevel(runtime, true); err != nil {
		t.Fatalf("shared time limit should be valid: %v", err)
	}
	runtime["time_limit_seconds"] = 3601.0
	if err := validateRuntimeLevel(runtime, true); err == nil {
		t.Fatal("out-of-range shared time limit should be rejected")
	}
}

func TestValidatePuzzleRejectsDuplicateAndOutOfRangeCells(t *testing.T) {
	for name, operations := range map[string][]any{
		"duplicate":    {map[string]any{"type": "swap", "cells": []any{1.0, 2.0}}, map[string]any{"type": "swap", "cells": []any{2.0, 3.0}}},
		"out_of_range": {map[string]any{"type": "swap", "cells": []any{1.0, 20.0}}},
	} {
		t.Run(name, func(t *testing.T) {
			runtime := puzzleRuntime()
			runtime["puzzle"].(map[string]any)["operations"] = operations
			if validateRuntimeLevel(runtime, true) == nil {
				t.Fatal("expected validation error")
			}
		})
	}
}

func TestPuzzleMayHaveNoOperations(t *testing.T) {
	// Pieces are shuffled into a random derangement on the client at play time,
	// so operations are optional even for published puzzles.
	runtime := puzzleRuntime()
	runtime["puzzle"].(map[string]any)["operations"] = []any{}
	if err := validateRuntimeLevel(runtime, false); err != nil {
		t.Fatal(err)
	}
	if err := validateRuntimeLevel(runtime, true); err != nil {
		t.Fatalf("published puzzle should allow empty operations: %v", err)
	}
	delete(runtime["puzzle"].(map[string]any), "operations")
	if err := validateRuntimeLevel(runtime, true); err != nil {
		t.Fatalf("published puzzle should allow missing operations: %v", err)
	}
}
