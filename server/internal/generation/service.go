package generation

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

var ErrNotFound = errors.New("generation job not found")

type Job struct {
	ID            string         `json:"id"`
	Status        string         `json:"status"`
	Market        string         `json:"market"`
	PromptVersion string         `json:"prompt_version"`
	Model         string         `json:"model"`
	Input         map[string]any `json:"input"`
	Result        map[string]any `json:"result,omitempty"`
	Attempts      int            `json:"attempts"`
	Error         string         `json:"error,omitempty"`
}
type CreateRequest struct {
	ID            string         `json:"id"`
	Market        string         `json:"market"`
	PromptVersion string         `json:"prompt_version"`
	Model         string         `json:"model"`
	Input         map[string]any `json:"input"`
}
type Service interface {
	Create(context.Context, CreateRequest) (Job, error)
	Get(context.Context, string) (Job, error)
}
type MemoryService struct{ jobs map[string]Job }

func NewMemoryService() *MemoryService { return &MemoryService{jobs: map[string]Job{}} }
func (s *MemoryService) Create(_ context.Context, r CreateRequest) (Job, error) {
	j := Job{ID: r.ID, Status: "pending", Market: r.Market, PromptVersion: r.PromptVersion, Model: r.Model, Input: r.Input}
	s.jobs[j.ID] = j
	return j, nil
}
func (s *MemoryService) Get(_ context.Context, id string) (Job, error) {
	j, ok := s.jobs[id]
	if !ok {
		return Job{}, ErrNotFound
	}
	return j, nil
}

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }
func (s *MySQLService) Create(ctx context.Context, r CreateRequest) (Job, error) {
	raw, _ := json.Marshal(r.Input)
	_, err := s.db.ExecContext(ctx, `INSERT INTO generation_jobs(id,status,market_id,prompt_version,model,input_json) VALUES(?,'pending',?,?,?,?)`, r.ID, r.Market, r.PromptVersion, r.Model, raw)
	if err != nil {
		return Job{}, fmt.Errorf("create generation job: %w", err)
	}
	return s.Get(ctx, r.ID)
}
func (s *MySQLService) Get(ctx context.Context, id string) (Job, error) {
	var j Job
	var input, result []byte
	var errText sql.NullString
	err := s.db.QueryRowContext(ctx, `SELECT id,status,market_id,prompt_version,model,input_json,result_json,attempts,error_message FROM generation_jobs WHERE id=?`, id).Scan(&j.ID, &j.Status, &j.Market, &j.PromptVersion, &j.Model, &input, &result, &j.Attempts, &errText)
	if errors.Is(err, sql.ErrNoRows) {
		return j, ErrNotFound
	}
	if err != nil {
		return j, err
	}
	_ = json.Unmarshal(input, &j.Input)
	if len(result) > 0 {
		_ = json.Unmarshal(result, &j.Result)
	}
	j.Error = errText.String
	return j, nil
}

type Worker struct {
	db              *sql.DB
	lastMaintenance time.Time
}

func NewWorker(db *sql.DB) *Worker { return &Worker{db: db} }
func (w *Worker) Run(ctx context.Context) error {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		if time.Since(w.lastMaintenance) >= time.Hour {
			if err := w.Maintain(ctx); err != nil {
				return err
			}
			w.lastMaintenance = time.Now()
		}
		processed, err := w.ProcessOne(ctx)
		if err != nil {
			return err
		}
		if processed {
			continue
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}

// Maintain keeps operational tables bounded and makes abandoned jobs retryable.
func (w *Worker) Maintain(ctx context.Context) error {
	statements := []string{
		`DELETE FROM user_sessions WHERE (revoked_at IS NOT NULL AND revoked_at < UTC_TIMESTAMP(3) - INTERVAL 7 DAY) OR refresh_expires_at < UTC_TIMESTAMP(3) - INTERVAL 7 DAY`,
		`DELETE FROM idempotency_records WHERE expires_at < UTC_TIMESTAMP(3)`,
		`DELETE FROM analytics_events WHERE occurred_at < UTC_TIMESTAMP(3) - INTERVAL 180 DAY`,
		`UPDATE generation_jobs SET status='pending',locked_at=NULL,error_message='recovered stale worker lock' WHERE status='running' AND locked_at < UTC_TIMESTAMP(3) - INTERVAL 15 MINUTE AND attempts < max_attempts`,
		`UPDATE generation_jobs SET status='failed',locked_at=NULL,error_message='retry limit exceeded' WHERE status IN ('pending','running') AND attempts >= max_attempts`,
	}
	for _, statement := range statements {
		if _, err := w.db.ExecContext(ctx, statement); err != nil {
			return fmt.Errorf("worker maintenance: %w", err)
		}
	}
	return nil
}
func (w *Worker) ProcessOne(ctx context.Context) (bool, error) {
	tx, err := w.db.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback() }()
	var id string
	var raw []byte
	err = tx.QueryRowContext(ctx, `SELECT id,input_json FROM generation_jobs WHERE status='pending' AND attempts<max_attempts ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED`).Scan(&id, &raw)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	_, err = tx.ExecContext(ctx, `UPDATE generation_jobs SET status='running',attempts=attempts+1,locked_at=UTC_TIMESTAMP(3) WHERE id=?`, id)
	if err != nil {
		return false, err
	}
	if err = tx.Commit(); err != nil {
		return false, err
	}
	passed, score, checks := qualityCheck(raw)
	checksRaw, _ := json.Marshal(checks)
	status := "completed"
	if !passed {
		status = "quality_failed"
	}
	resultRaw, _ := json.Marshal(map[string]any{"quality_score": score, "review_status": "pending_review"})
	finish, err := w.db.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer func() { _ = finish.Rollback() }()
	_, err = finish.ExecContext(ctx, `INSERT INTO quality_results(generation_job_id,passed,score,checks_json) VALUES(?,?,?,?)`, id, passed, score, checksRaw)
	if err != nil {
		return false, err
	}
	_, err = finish.ExecContext(ctx, `UPDATE generation_jobs SET status=?,result_json=?,error_message=NULL,locked_at=NULL WHERE id=?`, status, resultRaw, id)
	if err != nil {
		return false, err
	}
	return true, finish.Commit()
}
func qualityCheck(raw []byte) (bool, float64, map[string]any) {
	var input map[string]any
	if json.Unmarshal(raw, &input) != nil {
		return false, 0, map[string]any{"valid_json": false}
	}
	level, ok := input["level"].(map[string]any)
	if !ok {
		return false, 20, map[string]any{"level_present": false}
	}
	diffs, ok := level["differences"].([]any)
	count := len(diffs)
	validCount := ok && count >= 3 && count <= 12
	assets, assetsOK := level["assets"].(map[string]any)
	passed := validCount && assetsOK && assets["base"] != nil && assets["target"] != nil
	score := 40.0
	if validCount {
		score += 30
	}
	if assetsOK {
		score += 30
	}
	return passed, score, map[string]any{"valid_json": true, "difference_count": count, "difference_count_valid": validCount, "assets_present": assetsOK}
}
