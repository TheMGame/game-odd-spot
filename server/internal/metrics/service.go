package metrics

import (
	"context"
	"database/sql"
	"fmt"
)

type Snapshot struct {
	Users             int64   `json:"users"`
	Attempts          int64   `json:"attempts"`
	Completed         int64   `json:"completed"`
	CompletionRate    float64 `json:"completion_rate"`
	HintsUsed         int64   `json:"hints_used"`
	PurchasesVerified int64   `json:"purchases_verified"`
	OpenReports       int64   `json:"open_reports"`
}
type Service interface {
	Snapshot(context.Context) (Snapshot, error)
}
type MemoryService struct{}

func NewMemoryService() *MemoryService                            { return &MemoryService{} }
func (*MemoryService) Snapshot(context.Context) (Snapshot, error) { return Snapshot{}, nil }

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db} }
func (s *MySQLService) Snapshot(ctx context.Context) (Snapshot, error) {
	var v Snapshot
	e := s.db.QueryRowContext(ctx, `SELECT (SELECT COUNT(*) FROM users),(SELECT COUNT(*) FROM level_attempts),(SELECT COUNT(*) FROM level_attempts WHERE state='completed'),(SELECT COALESCE(SUM(hints_used),0) FROM level_attempts),(SELECT COUNT(*) FROM purchase_transactions WHERE status='verified'),(SELECT COUNT(*) FROM content_reports WHERE status IN ('open','reviewing'))`).Scan(&v.Users, &v.Attempts, &v.Completed, &v.HintsUsed, &v.PurchasesVerified, &v.OpenReports)
	if e != nil {
		return v, fmt.Errorf("metrics snapshot: %w", e)
	}
	if v.Attempts > 0 {
		v.CompletionRate = float64(v.Completed) / float64(v.Attempts)
	}
	return v, nil
}
