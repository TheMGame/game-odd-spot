package main

import (
	"context"
	"log/slog"
	"os"
	"time"

	"game-odd-spot/server/internal/config"
	"game-odd-spot/server/internal/database"
)

func main() {
	cfg, err := config.FromEnv()
	if err != nil {
		slog.Error("invalid configuration", "error", err)
		os.Exit(1)
	}
	if cfg.DatabaseDSN == "" {
		slog.Error("ODDSPOT_DATABASE_DSN is required")
		os.Exit(1)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	db, err := database.Open(ctx, cfg.DatabaseDSN)
	if err != nil {
		slog.Error("database connection failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	if err := database.Migrate(ctx, db); err != nil {
		slog.Error("migration failed", "error", err)
		os.Exit(1)
	}
	slog.Info("database migrations complete")
}
