package remoteconfig

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

var ErrNotFound = errors.New("config not found")

type Snapshot struct {
	Market       string         `json:"market"`
	SourceMarket string         `json:"source_market,omitempty"`
	Locale       string         `json:"locale"`
	Version      int64          `json:"config_version"`
	Values       map[string]any `json:"-"`
}

type Service interface {
	Latest(context.Context, string, string) (Snapshot, error)
	Version(context.Context, string, int64, string) (Snapshot, error)
}

type MemoryService struct{}

func NewMemoryService() *MemoryService { return &MemoryService{} }
func (s *MemoryService) Latest(_ context.Context, market, locale string) (Snapshot, error) {
	return defaultSnapshot(market, locale), nil
}
func (s *MemoryService) Version(_ context.Context, market string, version int64, locale string) (Snapshot, error) {
	if version != 1 {
		return Snapshot{}, ErrNotFound
	}
	return defaultSnapshot(market, locale), nil
}
func defaultSnapshot(market, locale string) Snapshot {
	return Snapshot{Market: market, Locale: locale, Version: 1, Values: map[string]any{"minimum_app_version": "0.1.0", "force_upgrade": false, "features": map[string]any{"daily_challenge": false, "rewarded_ads": false, "iap": false}}}
}

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }
func (s *MySQLService) Latest(ctx context.Context, market, locale string) (Snapshot, error) {
	return s.query(ctx, market, locale, 0)
}
func (s *MySQLService) Version(ctx context.Context, market string, version int64, locale string) (Snapshot, error) {
	return s.query(ctx, market, locale, version)
}
func (s *MySQLService) query(ctx context.Context, market, locale string, version int64) (Snapshot, error) {
	query := `SELECT market_id,version,config_json FROM remote_config_versions WHERE market_id=? AND status='published'`
	args := []any{market}
	if version > 0 {
		query += " AND version=?"
		args = append(args, version)
	}
	query += " ORDER BY version DESC LIMIT 1"
	var resolved string
	var resolvedVersion int64
	var raw []byte
	err := s.db.QueryRowContext(ctx, query, args...).Scan(&resolved, &resolvedVersion, &raw)
	if errors.Is(err, sql.ErrNoRows) && market != "global" {
		fallback, fallbackErr := s.query(ctx, "global", locale, version)
		if fallbackErr == nil {
			fallback.SourceMarket = fallback.Market
			fallback.Market = market
		}
		return fallback, fallbackErr
	}
	if errors.Is(err, sql.ErrNoRows) {
		return Snapshot{}, ErrNotFound
	}
	if err != nil {
		return Snapshot{}, fmt.Errorf("query remote config: %w", err)
	}
	values := map[string]any{}
	if err := json.Unmarshal(raw, &values); err != nil {
		return Snapshot{}, fmt.Errorf("decode remote config: %w", err)
	}
	return Snapshot{Market: resolved, SourceMarket: resolved, Locale: locale, Version: resolvedVersion, Values: values}, nil
}
