package level

import "testing"

func TestCalculateScore(t *testing.T) {
	tests := []struct {
		name                    string
		duration                int64
		hints, wrong, wantScore int
	}{
		{name: "perfect", duration: 60_000, wantScore: 100},
		{name: "normal", duration: 135_000, wrong: 1, wantScore: 88},
		{name: "one hint", duration: 135_000, hints: 1, wrong: 1, wantScore: 69},
		{name: "floor", duration: 600_000, hints: 12, wrong: 50, wantScore: 40},
	}
	difficulties := []int{1, 2, 3, 3, 4}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := CalculateScore(2, difficulties, test.duration, test.hints, test.wrong); got != test.wantScore {
				t.Fatalf("score=%d want=%d", got, test.wantScore)
			}
		})
	}
}

func TestCalculatePointsWeightsDifficulty(t *testing.T) {
	if got := CalculatePoints(90, 1); got != 90 {
		t.Fatalf("easy points=%d", got)
	}
	if got := CalculatePoints(90, 5); got != 135 {
		t.Fatalf("hard points=%d", got)
	}
}

func TestLevelProgress(t *testing.T) {
	level, progress, next := LevelProgress(135)
	if level != 2 || progress != 35 || next != 300 {
		t.Fatalf("level=%d progress=%d next=%d", level, progress, next)
	}
}
