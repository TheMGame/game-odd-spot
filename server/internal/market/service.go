package market

import (
	"context"
	"database/sql"
	"strings"
)

type Service interface {
	Resolve(context.Context, string, string, string) string
}
type MemoryService struct{}

func NewMemoryService() *MemoryService { return &MemoryService{} }
func (*MemoryService) Resolve(_ context.Context, country, locale, fallback string) string {
	switch strings.ToUpper(country) {
	case "CN", "CHN":
		return "cn"
	case "US", "USA":
		return "us"
	case "JP", "JPN":
		return "jp"
	}
	if strings.HasPrefix(strings.ToLower(locale), "zh") {
		return "cn"
	}
	if strings.HasPrefix(strings.ToLower(locale), "ja") {
		return "jp"
	}
	return fallback
}

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }
func (s *MySQLService) Resolve(ctx context.Context, country, locale, fallback string) string {
	var resolved string
	if country != "" && s.db.QueryRowContext(ctx, `SELECT market_id FROM market_country_aliases WHERE country_code=?`, strings.ToUpper(country)).Scan(&resolved) == nil {
		return resolved
	}
	var byLocale string
	err := s.db.QueryRowContext(ctx, `SELECT id FROM markets WHERE enabled=true AND default_locale=? ORDER BY id LIMIT 1`, locale).Scan(&byLocale)
	if err == nil {
		return byLocale
	}
	return fallback
}
