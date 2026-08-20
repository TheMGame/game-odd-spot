package catalog

import (
	"errors"
	"fmt"
)

func validateRuntimeLevel(runtime map[string]any, published bool) error {
	mode, _ := runtime["mode"].(string)
	if mode != "find_anachronism" && mode != "image_puzzle" {
		return errors.New("unsupported level mode")
	}
	assets, ok := runtime["assets"].(map[string]any)
	if !ok || assets["image"] == nil {
		return errors.New("assets.image is required")
	}
	width, wok := number(assets["width"])
	height, hok := number(assets["height"])
	if !wok || !hok || width < 1 || height < 1 || width > 8192 || height > 8192 {
		return errors.New("invalid image dimensions")
	}
	if mode == "find_anachronism" {
		if runtime["puzzle"] != nil {
			return errors.New("find_anachronism cannot contain puzzle")
		}
		diffs, ok := runtime["differences"].([]any)
		if !ok || len(diffs) > 12 || (published && len(diffs) < 3) {
			return errors.New("differences must contain 3 to 12 items")
		}
		seen := map[string]bool{}
		for _, raw := range diffs {
			d, ok := raw.(map[string]any)
			if !ok {
				return errors.New("invalid difference")
			}
			id, _ := d["id"].(string)
			if id == "" || seen[id] {
				return errors.New("difference ids must be unique")
			}
			seen[id] = true
		}
		return nil
	}
	if runtime["differences"] != nil || assets["base"] != nil || assets["target"] != nil {
		return errors.New("image_puzzle cannot contain differences, base, or target")
	}
	puzzle, ok := runtime["puzzle"].(map[string]any)
	if !ok {
		return errors.New("puzzle is required")
	}
	rows, rok := integerNumber(puzzle["rows"])
	cols, cok := integerNumber(puzzle["cols"])
	if !rok || !cok || rows < 2 || rows > 8 || cols < 2 || cols > 8 || rows*cols > 48 {
		return errors.New("invalid puzzle grid")
	}
	ops, ok := puzzle["operations"].([]any)
	if !ok || len(ops) > 24 || (published && len(ops) == 0) {
		return errors.New("puzzle operations must contain 1 to 24 swaps when published")
	}
	used := map[int]bool{}
	for _, raw := range ops {
		op, ok := raw.(map[string]any)
		if !ok || op["type"] != "swap" {
			return errors.New("invalid puzzle operation")
		}
		cells, ok := op["cells"].([]any)
		if !ok || len(cells) != 2 {
			return errors.New("swap requires two cells")
		}
		a, aok := integerNumber(cells[0])
		b, bok := integerNumber(cells[1])
		if !aok || !bok || a == b || a < 0 || b < 0 || a >= rows*cols || b >= rows*cols {
			return errors.New("invalid swap cells")
		}
		if used[a] || used[b] {
			return fmt.Errorf("puzzle cell is used more than once")
		}
		used[a], used[b] = true, true
	}
	if published && len(used) != rows*cols {
		return errors.New("every puzzle cell must be misplaced before publishing")
	}
	return nil
}

func integerNumber(value any) (int, bool) {
	v, ok := value.(float64)
	if !ok || v != float64(int(v)) {
		return 0, false
	}
	return int(v), true
}

func puzzleContentCount(runtime map[string]any) int {
	p, _ := runtime["puzzle"].(map[string]any)
	ops, _ := p["operations"].([]any)
	rows, _ := integerNumber(p["rows"])
	cols, _ := integerNumber(p["cols"])
	if rows > 0 && cols > 0 {
		return rows * cols
	}
	return len(ops) * 2
}
