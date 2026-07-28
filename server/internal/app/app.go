package app

import (
	"context"
	"database/sql"
	"log/slog"
	"net/http"

	"game-odd-spot/server/internal/account"
	"game-odd-spot/server/internal/analytics"
	"game-odd-spot/server/internal/catalog"
	"game-odd-spot/server/internal/config"
	"game-odd-spot/server/internal/content"
	"game-odd-spot/server/internal/database"
	"game-odd-spot/server/internal/generation"
	"game-odd-spot/server/internal/httpapi"
	"game-odd-spot/server/internal/level"
	"game-odd-spot/server/internal/localization"
	"game-odd-spot/server/internal/market"
	"game-odd-spot/server/internal/metrics"
	"game-odd-spot/server/internal/monetization"
	"game-odd-spot/server/internal/operations"
	"game-odd-spot/server/internal/remoteconfig"
	"game-odd-spot/server/internal/report"
	"game-odd-spot/server/internal/session"
)

func NewHandler(ctx context.Context, cfg config.Config, logger *slog.Logger) (http.Handler, func() error, error) {
	locales, err := localization.New(cfg.RemoteLocalesJSON)
	if err != nil {
		return nil, nil, err
	}
	var sessions session.Service = session.NewMemoryService()
	var levels level.Service = level.NewMemoryService()
	var configs remoteconfig.Service = remoteconfig.NewMemoryService()
	var contents content.Service = content.NewMemoryService()
	var catalogs catalog.Service = catalog.NewMemoryService()
	var events analytics.Service = analytics.NewMemoryService()
	var money monetization.Service = monetization.NewMemoryService(cfg.Environment == "development" || cfg.Environment == "test")
	var ops operations.Service = operations.NewMemoryService()
	var jobs generation.Service = generation.NewMemoryService()
	var markets market.Service = market.NewMemoryService()
	development := cfg.Environment == "development" || cfg.Environment == "test"
	var accounts account.Service = account.NewMemoryService(development)
	var reports report.Service = report.NewMemoryService()
	var measurements metrics.Service = metrics.NewMemoryService()
	var db *sql.DB
	if cfg.DatabaseDSN != "" {
		var err error
		db, err = database.Open(ctx, cfg.DatabaseDSN)
		if err != nil {
			return nil, nil, err
		}
		sessions = session.NewMySQLService(db, cfg.InstallationHMACKey)
		levels = level.NewMySQLService(db)
		configs = remoteconfig.NewMySQLService(db)
		contents = content.NewMySQLService(db)
		catalogs = catalog.NewMySQLService(db)
		events = analytics.NewMySQLService(db)
		money = monetization.NewMySQLService(db, cfg.Environment == "development" || cfg.Environment == "test")
		ops = operations.NewMySQLService(db)
		jobs = generation.NewMySQLService(db)
		markets = market.NewMySQLService(db)
		accounts = account.NewMySQLService(db, development)
		reports = report.NewMySQLService(db)
		measurements = metrics.NewMySQLService(db)
	}
	ready := func(ctx context.Context) error {
		if db == nil {
			return nil
		}
		return db.PingContext(ctx)
	}
	cleanup := func() error {
		if db == nil {
			return nil
		}
		return db.Close()
	}
	return httpapi.NewRouter(httpapi.Dependencies{
		Config:     cfg,
		Logger:     logger,
		Sessions:   sessions,
		Levels:     levels,
		Configs:    configs,
		Contents:   contents,
		Catalog:    catalogs,
		Analytics:  events,
		Money:      money,
		Operations: ops,
		Generation: jobs,
		Markets:    markets,
		Accounts:   accounts,
		Reports:    reports,
		Metrics:    measurements,
		Locales:    locales,
		Ready:      ready,
	}), cleanup, nil
}
