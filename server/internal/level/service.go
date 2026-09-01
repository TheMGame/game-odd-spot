package level

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
)

var (
	ErrNotFound        = errors.New("level not found")
	ErrVersionMismatch = errors.New("level version mismatch")
	ErrInvalidState    = errors.New("invalid attempt state")
	ErrInvalidDiff     = errors.New("invalid difference")
	ErrIncomplete      = errors.New("level is incomplete")
	ErrIdempotency     = errors.New("idempotency conflict")
)

type Summary struct {
	LevelID         string `json:"level_id"`
	LevelVersion    int    `json:"level_version"`
	Difficulty      int    `json:"difficulty"`
	DifferenceCount int    `json:"difference_count"`
}

type FoundDifference struct {
	DifferenceID string `json:"difference_id"`
	FoundAtMS    int64  `json:"found_at_ms"`
}

type StartRequest struct {
	AttemptID      string `json:"attempt_id"`
	LevelVersion   int    `json:"level_version"`
	IdempotencyKey string `json:"-"`
}

type ProgressRequest struct {
	AttemptID      string            `json:"attempt_id"`
	Found          []FoundDifference `json:"found"`
	HintsUsed      int               `json:"hints_used"`
	DurationMS     int64             `json:"duration_ms"`
	WrongTaps      int               `json:"wrong_taps,omitempty"`
	IdempotencyKey string            `json:"-"`
}

type CompleteRequest struct {
	AttemptID      string   `json:"attempt_id"`
	DifferenceIDs  []string `json:"difference_ids"`
	PuzzleOrder    []int    `json:"puzzle_order,omitempty"`
	PuzzleMoves    int      `json:"puzzle_moves,omitempty"`
	HintsUsed      int      `json:"hints_used"`
	DurationMS     int64    `json:"duration_ms"`
	WrongTaps      int      `json:"wrong_taps,omitempty"`
	IdempotencyKey string   `json:"-"`
}

type AttemptResult struct {
	AttemptID  string `json:"attempt_id"`
	State      string `json:"state"`
	FoundCount int    `json:"found_count"`
	TotalCount int    `json:"total_count"`
	HintsUsed  int    `json:"hints_used"`
	DurationMS int64  `json:"duration_ms"`
	Reward     int64  `json:"rewarded_hints"`
	WrongTaps  int    `json:"wrong_taps"`
	Score      int    `json:"score"`
	BestScore  int    `json:"best_score"`
	Points     int    `json:"points"`
}

type LeaderboardEntry struct {
	Rank            int    `json:"rank"`
	UserID          string `json:"user_id"`
	DisplayName     string `json:"display_name"`
	AvatarURL       string `json:"avatar_url"`
	Score           int    `json:"score"`
	Points          int    `json:"points"`
	CompletedLevels int    `json:"completed_levels,omitempty"`
	DurationMS      int64  `json:"duration_ms,omitempty"`
	HintsUsed       int    `json:"hints_used,omitempty"`
	WrongTaps       int    `json:"wrong_taps,omitempty"`
	IsMe            bool   `json:"is_me"`
}

type PlayerStats struct {
	UserID          string             `json:"user_id"`
	DisplayName     string             `json:"display_name"`
	AvatarURL       string             `json:"avatar_url"`
	TotalPoints     int                `json:"total_points"`
	PlayerLevel     int                `json:"player_level"`
	LevelProgress   int                `json:"level_progress"`
	NextLevelPoints int                `json:"next_level_points"`
	CompletedLevels int                `json:"completed_levels"`
	AverageScore    int                `json:"average_score"`
	GlobalRank      int                `json:"global_rank,omitempty"`
	LevelScores     []PlayerLevelScore `json:"level_scores"`
}

type PlayerLevelScore struct {
	LevelID      string `json:"level_id"`
	LevelVersion int    `json:"level_version"`
	Score        int    `json:"score"`
	Points       int    `json:"points"`
}

type Leaderboard struct {
	Scope        string             `json:"scope"`
	LevelID      string             `json:"level_id,omitempty"`
	LevelVersion int                `json:"level_version,omitempty"`
	Entries      []LeaderboardEntry `json:"entries"`
	MyEntry      *LeaderboardEntry  `json:"my_entry,omitempty"`
}

type Service interface {
	Home(context.Context, string) ([]Summary, error)
	Get(context.Context, string) (json.RawMessage, error)
	Start(context.Context, string, string, StartRequest) (AttemptResult, error)
	Progress(context.Context, string, string, ProgressRequest) (AttemptResult, error)
	Complete(context.Context, string, string, CompleteRequest) (AttemptResult, error)
	Reset(context.Context, string, string) error
	LevelLeaderboard(context.Context, string, string, int) (Leaderboard, error)
	OverallLeaderboard(context.Context, string, int) (Leaderboard, error)
	PlayerStats(context.Context, string) (PlayerStats, error)
	RebuildScoresFor(context.Context, string) error
	RebuildAllScores(context.Context) (rebuilt int, failed int, err error)
	ListUserScoreSummaries(context.Context, int) ([]UserScoreSummary, error)
}

type UserScoreSummary struct {
	UserID          string `json:"user_id"`
	TotalPoints     int    `json:"total_points"`
	CompletedLevels int    `json:"completed_levels"`
	ScoreSum        int    `json:"score_sum"`
	UpdatedAt       string `json:"updated_at"`
}

type memoryAttempt struct {
	userID   string
	version  int
	found    map[string]bool
	state    string
	hints    int
	duration int64
	wrong    int
	score    int
}

type MemoryService struct {
	mu          sync.Mutex
	attempts    map[string]*memoryAttempt
	idempotency map[string]AttemptResult
}

func NewMemoryService() *MemoryService {
	return &MemoryService{attempts: map[string]*memoryAttempt{}, idempotency: map[string]AttemptResult{}}
}

func (s *MemoryService) Home(context.Context, string) ([]Summary, error) {
	return []Summary{{LevelID: "global_demo_001", LevelVersion: 1, Difficulty: 2, DifferenceCount: 5}}, nil
}

func (s *MemoryService) Get(_ context.Context, id string) (json.RawMessage, error) {
	if id != "global_demo_001" {
		return nil, ErrNotFound
	}
	return json.RawMessage(`{"schema_version":1,"level_id":"global_demo_001","level_version":1,"mode":"find_anachronism","assets":{"image":{"asset_id":"image_demo_001","url":"https://cdn.example.com/image.webp","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","bytes":1,"content_type":"image/webp"},"width":1536,"height":1024},"differences":[{"id":"d1"},{"id":"d2"},{"id":"d3"},{"id":"d4"},{"id":"d5"}]}`), nil
}

func (s *MemoryService) Start(_ context.Context, userID, levelID string, request StartRequest) (AttemptResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := userID + "|start|" + request.IdempotencyKey
	if result, ok := s.idempotency[key]; ok {
		return result, nil
	}
	if levelID != "global_demo_001" {
		return AttemptResult{}, ErrNotFound
	}
	if request.LevelVersion != 1 {
		return AttemptResult{}, ErrVersionMismatch
	}
	if existing, ok := s.attempts[request.AttemptID]; ok && existing.userID != userID {
		return AttemptResult{}, ErrInvalidState
	}
	s.attempts[request.AttemptID] = &memoryAttempt{userID: userID, version: 1, found: map[string]bool{}, state: "in_progress"}
	result := AttemptResult{AttemptID: request.AttemptID, State: "in_progress", TotalCount: 5}
	s.idempotency[key] = result
	return result, nil
}

func (s *MemoryService) Progress(_ context.Context, userID, _ string, request ProgressRequest) (AttemptResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := userID + "|progress|" + request.IdempotencyKey
	if result, ok := s.idempotency[key]; ok {
		return result, nil
	}
	a, ok := s.attempts[request.AttemptID]
	if !ok || a.userID != userID || a.state != "in_progress" {
		return AttemptResult{}, ErrInvalidState
	}
	for _, found := range request.Found {
		if !validDiff(found.DifferenceID) {
			return AttemptResult{}, ErrInvalidDiff
		}
		a.found[found.DifferenceID] = true
	}
	a.hints = request.HintsUsed
	a.duration = request.DurationMS
	a.wrong = request.WrongTaps
	result := AttemptResult{AttemptID: request.AttemptID, State: a.state, FoundCount: len(a.found), TotalCount: 5, HintsUsed: a.hints, DurationMS: a.duration}
	s.idempotency[key] = result
	return result, nil
}

func (s *MemoryService) Complete(_ context.Context, userID, _ string, request CompleteRequest) (AttemptResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := userID + "|complete|" + request.IdempotencyKey
	if result, ok := s.idempotency[key]; ok {
		return result, nil
	}
	a, ok := s.attempts[request.AttemptID]
	if !ok || a.userID != userID {
		return AttemptResult{}, ErrInvalidState
	}
	for _, id := range request.DifferenceIDs {
		if !validDiff(id) {
			return AttemptResult{}, ErrInvalidDiff
		}
		a.found[id] = true
	}
	if len(a.found) != 5 {
		return AttemptResult{}, ErrIncomplete
	}
	a.state = "completed"
	a.hints = request.HintsUsed
	a.duration = request.DurationMS
	a.wrong = request.WrongTaps
	a.score = CalculateScore(2, []int{1, 2, 3, 3, 4}, request.DurationMS, request.HintsUsed, request.WrongTaps)
	result := AttemptResult{AttemptID: request.AttemptID, State: a.state, FoundCount: 5, TotalCount: 5, HintsUsed: a.hints, DurationMS: a.duration, Reward: 1, WrongTaps: a.wrong, Score: a.score, BestScore: a.score, Points: CalculatePoints(a.score, 2)}
	s.idempotency[key] = result
	return result, nil
}

func (s *MemoryService) LevelLeaderboard(_ context.Context, userID, levelID string, limit int) (Leaderboard, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if levelID != "global_demo_001" {
		return Leaderboard{}, ErrNotFound
	}
	best := map[string]*memoryAttempt{}
	for _, a := range s.attempts {
		if a.state == "completed" && (best[a.userID] == nil || a.score > best[a.userID].score) {
			best[a.userID] = a
		}
	}
	entries := memoryEntries(best, userID, limit)
	return Leaderboard{Scope: "level", LevelID: levelID, LevelVersion: 1, Entries: entries, MyEntry: findMe(entries)}, nil
}

func (s *MemoryService) OverallLeaderboard(_ context.Context, userID string, limit int) (Leaderboard, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	best := map[string]*memoryAttempt{}
	for _, a := range s.attempts {
		if a.state == "completed" && (best[a.userID] == nil || a.score > best[a.userID].score) {
			best[a.userID] = a
		}
	}
	entries := memoryEntries(best, userID, limit)
	for i := range entries {
		entries[i].CompletedLevels = 1
	}
	return Leaderboard{Scope: "overall", Entries: entries, MyEntry: findMe(entries)}, nil
}

func (s *MemoryService) PlayerStats(_ context.Context, userID string) (PlayerStats, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	best := map[string]*memoryAttempt{}
	for _, a := range s.attempts {
		if a.userID == userID && a.state == "completed" && (best[a.userID] == nil || a.score > best[a.userID].score) {
			best[a.userID] = a
		}
	}
	points, score, completed := 0, 0, 0
	if a := best[userID]; a != nil {
		points = CalculatePoints(a.score, 2)
		score = a.score
		completed = 1
	}
	playerLevel, progress, next := LevelProgress(points)
	levels := []PlayerLevelScore{}
	if completed > 0 {
		levels = append(levels, PlayerLevelScore{LevelID: "global_demo_001", LevelVersion: 1, Score: score, Points: points})
	}
	return PlayerStats{UserID: userID, DisplayName: displayName(userID), TotalPoints: points, PlayerLevel: playerLevel, LevelProgress: progress, NextLevelPoints: next, CompletedLevels: completed, AverageScore: score, GlobalRank: 1, LevelScores: levels}, nil
}

func (s *MemoryService) Reset(_ context.Context, userID, _ string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for id, attempt := range s.attempts {
		if attempt.userID == userID {
			delete(s.attempts, id)
		}
	}
	return nil
}

func (s *MemoryService) RebuildScoresFor(_ context.Context, _ string) error { return nil }

func (s *MemoryService) RebuildAllScores(_ context.Context) (int, int, error) { return 0, 0, nil }

func (s *MemoryService) ListUserScoreSummaries(_ context.Context, _ int) ([]UserScoreSummary, error) {
	return []UserScoreSummary{}, nil
}

func validDiff(id string) bool {
	return id == "d1" || id == "d2" || id == "d3" || id == "d4" || id == "d5"
}
