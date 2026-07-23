package main

import (
	"context"
	"errors"
	"game-odd-spot/server/internal/config"
	"game-odd-spot/server/internal/database"
	"game-odd-spot/server/internal/generation"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	cfg, err := config.FromEnv()
	if err != nil || cfg.DatabaseDSN == "" {
		slog.Error("invalid worker configuration", "error", err)
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	db, err := database.Open(ctx, cfg.DatabaseDSN)
	if err != nil {
		slog.Error("database connection failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	slog.Info("content worker started")
	err = generation.NewWorker(db).Run(ctx)
	if err != nil && !errors.Is(err, context.Canceled) {
		slog.Error("content worker failed", "error", err)
		os.Exit(1)
	}
}
