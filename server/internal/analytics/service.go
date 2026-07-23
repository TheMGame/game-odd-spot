package analytics

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

type Event struct {
	EventID    string         `json:"event_id"`
	SessionID  string         `json:"session_id"`
	EventType  string         `json:"event_type"`
	Market     string         `json:"market"`
	Locale     string         `json:"locale"`
	AppVersion string         `json:"app_version"`
	OccurredAt time.Time      `json:"occurred_at"`
	Payload    map[string]any `json:"payload"`
}
type Service interface {
	Ingest(context.Context, string, []Event) (int, error)
}
type MemoryService struct{ seen map[string]bool }

func NewMemoryService() *MemoryService { return &MemoryService{seen: map[string]bool{}} }
func (s *MemoryService) Ingest(_ context.Context, _ string, events []Event) (int, error) {
	count := 0
	for _, e := range events {
		if !s.seen[e.EventID] {
			s.seen[e.EventID] = true
			count++
		}
	}
	return count, nil
}

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }
func (s *MySQLService) Ingest(ctx context.Context, userID string, events []Event) (int, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer func() { _ = tx.Rollback() }()
	accepted := 0
	for _, event := range events {
		payload, _ := json.Marshal(event.Payload)
		result, err := tx.ExecContext(ctx, `INSERT IGNORE INTO analytics_events(event_id,user_id,session_id,event_type,market,locale,app_version,occurred_at,payload) VALUES(?,?,?,?,?,?,?,?,?)`, event.EventID, userID, event.SessionID, event.EventType, event.Market, event.Locale, event.AppVersion, event.OccurredAt.UTC(), payload)
		if err != nil {
			return 0, fmt.Errorf("insert event: %w", err)
		}
		rows, _ := result.RowsAffected()
		accepted += int(rows)
	}
	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return accepted, nil
}
