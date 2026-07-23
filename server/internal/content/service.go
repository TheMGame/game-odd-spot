package content

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
)

var (
	ErrNotFound   = errors.New("content not found")
	ErrTransition = errors.New("invalid content transition")
)

type Item struct {
	LevelID      string  `json:"level_id"`
	Version      int     `json:"version"`
	Status       string  `json:"status"`
	Difficulty   int     `json:"difficulty"`
	QualityScore float64 `json:"quality_score"`
}
type Service interface {
	List(context.Context, string) ([]Item, error)
	Transition(context.Context, string, int, string, string, string) error
}

type MemoryService struct{ status string }

func NewMemoryService() *MemoryService { return &MemoryService{status: "published"} }
func (s *MemoryService) List(_ context.Context, status string) ([]Item, error) {
	if status != "" && status != s.status {
		return []Item{}, nil
	}
	return []Item{{LevelID: "global_demo_001", Version: 1, Status: s.status, Difficulty: 2, QualityScore: 95}}, nil
}
func (s *MemoryService) Transition(_ context.Context, _ string, _ int, to string, _ string, _ string) error {
	if !allowed(s.status, to) {
		return ErrTransition
	}
	s.status = to
	return nil
}

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }
func (s *MySQLService) List(ctx context.Context, status string) ([]Item, error) {
	query := `SELECT level_id,version,status,difficulty,quality_score FROM level_versions`
	args := []any{}
	if status != "" {
		query += " WHERE status=?"
		args = append(args, status)
	}
	query += " ORDER BY created_at DESC LIMIT 200"
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []Item
	for rows.Next() {
		var item Item
		if err := rows.Scan(&item.LevelID, &item.Version, &item.Status, &item.Difficulty, &item.QualityScore); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
func (s *MySQLService) Transition(ctx context.Context, levelID string, version int, to, reviewer, reason string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	var from string
	err = tx.QueryRowContext(ctx, `SELECT status FROM level_versions WHERE level_id=? AND version=? FOR UPDATE`, levelID, version).Scan(&from)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if !allowed(from, to) {
		return ErrTransition
	}
	_, err = tx.ExecContext(ctx, `UPDATE level_versions SET status=?,published_at=CASE WHEN ?='published' THEN COALESCE(published_at,UTC_TIMESTAMP(3)) ELSE published_at END WHERE level_id=? AND version=?`, to, to, levelID, version)
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO review_records(level_id,level_version,reviewer_id,from_status,to_status,reason) VALUES(?,?,?,?,?,?)`, levelID, version, reviewer, from, to, reason)
	if err != nil {
		return fmt.Errorf("write review record: %w", err)
	}
	return tx.Commit()
}
func allowed(from, to string) bool {
	transitions := map[string]map[string]bool{"draft": {"generated": true}, "generated": {"auto_review_failed": true, "pending_review": true}, "auto_review_failed": {"draft": true}, "pending_review": {"approved": true, "auto_review_failed": true}, "approved": {"staging": true}, "staging": {"published": true, "disabled": true}, "published": {"disabled": true}, "disabled": {"staging": true}}
	return transitions[from][to]
}
