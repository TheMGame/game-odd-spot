package level

import (
	"math"
	"sort"
)

// CalculateScore returns a normalized per-level score from 40 to 100.
// Difference difficulty affects the target time, not the maximum score.
func CalculateScore(levelDifficulty int, differenceDifficulties []int, durationMS int64, hintsUsed, wrongTaps int) int {
	targetSeconds := 20
	if len(differenceDifficulties) > 0 {
		for _, difficulty := range differenceDifficulties {
			targetSeconds += 10 + 5*clampInt(difficulty, 1, 5)
		}
	} else {
		// Puzzle levels do not have per-difference ratings.
		targetSeconds += 35 * clampInt(levelDifficulty, 1, 5)
	}
	elapsedSeconds := math.Max(0.5, float64(durationMS)/1000)
	timeRatio := clampFloat((2*float64(targetSeconds)-elapsedSeconds)/(1.5*float64(targetSeconds)), 0, 1)
	timeScore := 30 * timeRatio
	targetCount := len(differenceDifficulties)
	if targetCount == 0 {
		targetCount = 5
	}
	accuracyScore := 20 * clampFloat(1-float64(maxInt(wrongTaps, 0))/float64(targetCount*2), 0, 1)
	noHintBonus := 0.0
	if hintsUsed == 0 {
		noHintBonus = 10
	}
	hintMultiplier := math.Max(0.25, 1-0.25*float64(maxInt(hintsUsed, 0)))
	return clampInt(int(math.Round(40+(timeScore+accuracyScore+noHintBonus)*hintMultiplier)), 40, 100)
}

// CalculatePoints weights the normalized score for the cross-level leaderboard.
func CalculatePoints(score, difficulty int) int {
	weights := [...]float64{1, 1, 1.10, 1.20, 1.35, 1.50}
	return int(math.Round(float64(clampInt(score, 0, 100)) * weights[clampInt(difficulty, 1, 5)]))
}

// LevelProgress maps permanent user points to a quadratic progression curve.
// Level N starts at 100*(N-1)^2 total points.
func LevelProgress(totalPoints int) (level, progress, nextLevelPoints int) {
	totalPoints = maxInt(totalPoints, 0)
	level = int(math.Floor(math.Sqrt(float64(totalPoints)/100))) + 1
	levelStart := 100 * (level - 1) * (level - 1)
	nextStart := 100 * level * level
	return level, totalPoints - levelStart, nextStart - levelStart
}

func memoryEntries(best map[string]*memoryAttempt, userID string, limit int) []LeaderboardEntry {
	entries := make([]LeaderboardEntry, 0, len(best))
	for id, attempt := range best {
		entries = append(entries, LeaderboardEntry{UserID: id, DisplayName: displayName(id), Score: attempt.score, Points: CalculatePoints(attempt.score, 2), DurationMS: attempt.duration, HintsUsed: attempt.hints, WrongTaps: attempt.wrong, IsMe: id == userID})
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].Score != entries[j].Score {
			return entries[i].Score > entries[j].Score
		}
		if entries[i].HintsUsed != entries[j].HintsUsed {
			return entries[i].HintsUsed < entries[j].HintsUsed
		}
		if entries[i].WrongTaps != entries[j].WrongTaps {
			return entries[i].WrongTaps < entries[j].WrongTaps
		}
		return entries[i].DurationMS < entries[j].DurationMS
	})
	if limit < 1 {
		limit = 50
	}
	if len(entries) > limit {
		entries = entries[:limit]
	}
	for i := range entries {
		entries[i].Rank = i + 1
	}
	return entries
}

func findMe(entries []LeaderboardEntry) *LeaderboardEntry {
	for i := range entries {
		if entries[i].IsMe {
			copy := entries[i]
			return &copy
		}
	}
	return nil
}

func clampInt(value, minimum, maximum int) int {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}

func clampFloat(value, minimum, maximum float64) float64 {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func displayName(userID string) string {
	if len(userID) > 6 {
		userID = userID[len(userID)-6:]
	}
	return "侦探·" + userID
}
