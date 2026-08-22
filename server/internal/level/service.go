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
	IdempotencyKey string            `json:"-"`
}

type CompleteRequest struct {
	AttemptID      string   `json:"attempt_id"`
	DifferenceIDs  []string `json:"difference_ids"`
	PuzzleOrder    []int    `json:"puzzle_order,omitempty"`
	PuzzleMoves    int      `json:"puzzle_moves,omitempty"`
	HintsUsed      int      `json:"hints_used"`
	DurationMS     int64    `json:"duration_ms"`
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
}

type Service interface {
	Home(context.Context, string) ([]Summary, error)
	Get(context.Context, string) (json.RawMessage, error)
	Start(context.Context, string, string, StartRequest) (AttemptResult, error)
	Progress(context.Context, string, string, ProgressRequest) (AttemptResult, error)
	Complete(context.Context, string, string, CompleteRequest) (AttemptResult, error)
	Reset(context.Context, string, string) error
}

type memoryAttempt struct {
	userID   string
	version  int
	found    map[string]bool
	state    string
	hints    int
	duration int64
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
	result := AttemptResult{AttemptID: request.AttemptID, State: a.state, FoundCount: 5, TotalCount: 5, HintsUsed: a.hints, DurationMS: a.duration, Reward: 1}
	s.idempotency[key] = result
	return result, nil
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

func validDiff(id string) bool {
	return id == "d1" || id == "d2" || id == "d3" || id == "d4" || id == "d5"
}
