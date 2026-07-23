package operations

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

var ErrNotFound = errors.New("operation item not found")

type DailyChallenge struct {
	Date         string    `json:"date"`
	LevelID      string    `json:"level_id"`
	LevelVersion int       `json:"level_version"`
	StartsAt     time.Time `json:"starts_at"`
	EndsAt       time.Time `json:"ends_at"`
}
type Activity struct {
	ID       string         `json:"id"`
	Name     string         `json:"name"`
	Config   map[string]any `json:"config"`
	StartsAt time.Time      `json:"starts_at"`
	EndsAt   time.Time      `json:"ends_at"`
}
type Experiment struct {
	Key     string `json:"experiment_key"`
	Variant string `json:"variant"`
}
type Service interface {
	Daily(context.Context, string) (DailyChallenge, error)
	Activities(context.Context, string) ([]Activity, error)
	Assign(context.Context, string, string) (Experiment, error)
}
type MemoryService struct{}

func NewMemoryService() *MemoryService { return &MemoryService{} }
func (*MemoryService) Daily(_ context.Context, _ string) (DailyChallenge, error) {
	now := time.Now().UTC()
	return DailyChallenge{Date: now.Format("2006-01-02"), LevelID: "global_demo_001", LevelVersion: 1, StartsAt: now.Truncate(24 * time.Hour), EndsAt: now.Truncate(24 * time.Hour).Add(24 * time.Hour)}, nil
}
func (*MemoryService) Activities(_ context.Context, _ string) ([]Activity, error) {
	return []Activity{{ID: "welcome_2026", Name: "Welcome Challenge", Config: map[string]any{"theme": "cozy_home", "bonus_hints": 1}}}, nil
}
func (*MemoryService) Assign(_ context.Context, userID, key string) (Experiment, error) {
	variants := []string{"control", "compact"}
	sum := sha256.Sum256([]byte(userID + ":" + key))
	return Experiment{Key: key, Variant: variants[int(sum[0])%len(variants)]}, nil
}

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }
func (s *MySQLService) Daily(ctx context.Context, market string) (DailyChallenge, error) {
	var item DailyChallenge
	var date time.Time
	err := s.db.QueryRowContext(ctx, `SELECT challenge_date,level_id,level_version,starts_at,ends_at FROM daily_challenges WHERE challenge_date=UTC_DATE() AND market_id IN (?, 'global') ORDER BY market_id=? DESC LIMIT 1`, market, market).Scan(&date, &item.LevelID, &item.LevelVersion, &item.StartsAt, &item.EndsAt)
	if errors.Is(err, sql.ErrNoRows) {
		return item, ErrNotFound
	}
	if err != nil {
		return item, fmt.Errorf("query daily challenge: %w", err)
	}
	item.Date = date.Format("2006-01-02")
	return item, nil
}
func (s *MySQLService) Activities(ctx context.Context, market string) ([]Activity, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id,name,config_json,starts_at,ends_at FROM activities WHERE market_id IN (?, 'global') AND enabled=true AND starts_at<=UTC_TIMESTAMP(3) AND ends_at>UTC_TIMESTAMP(3) ORDER BY market_id=? DESC,starts_at`, market, market)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []Activity
	for rows.Next() {
		var item Activity
		var raw []byte
		if err := rows.Scan(&item.ID, &item.Name, &raw, &item.StartsAt, &item.EndsAt); err != nil {
			return nil, err
		}
		_ = json.Unmarshal(raw, &item.Config)
		items = append(items, item)
	}
	return items, rows.Err()
}
func (s *MySQLService) Assign(ctx context.Context, userID, key string) (Experiment, error) {
	var existing string
	err := s.db.QueryRowContext(ctx, `SELECT variant_key FROM experiment_assignments WHERE experiment_key=? AND user_id=?`, key, userID).Scan(&existing)
	if err == nil {
		return Experiment{Key: key, Variant: existing}, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return Experiment{}, err
	}
	var raw []byte
	err = s.db.QueryRowContext(ctx, `SELECT variants_json FROM experiment_definitions WHERE experiment_key=? AND enabled=true AND starts_at<=UTC_TIMESTAMP(3) AND ends_at>UTC_TIMESTAMP(3)`, key).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return Experiment{}, ErrNotFound
	}
	if err != nil {
		return Experiment{}, err
	}
	var variants []string
	if json.Unmarshal(raw, &variants) != nil || len(variants) == 0 {
		return Experiment{}, ErrNotFound
	}
	sum := sha256.Sum256([]byte(userID + ":" + key))
	index := binary.BigEndian.Uint64(sum[:8]) % uint64(len(variants))
	variant := variants[index]
	_, err = s.db.ExecContext(ctx, `INSERT INTO experiment_assignments(experiment_key,user_id,variant_key) VALUES(?,?,?) ON DUPLICATE KEY UPDATE variant_key=variant_key`, key, userID, variant)
	if err != nil {
		return Experiment{}, err
	}
	return Experiment{Key: key, Variant: variant}, nil
}
