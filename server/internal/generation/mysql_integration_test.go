//go:build integration

package generation_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"game-odd-spot/server/internal/database"
	"game-odd-spot/server/internal/generation"
)

func TestWorkerProcessesQualityJob(t *testing.T) {
	dsn := os.Getenv("ODDSPOT_DATABASE_DSN")
	if dsn == "" {
		t.Skip("database not configured")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	db, err := database.Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	service := generation.NewMySQLService(db)
	id := fmt.Sprintf("gen_itest_%d", time.Now().UnixNano())
	_, err = service.Create(ctx, generation.CreateRequest{
		ID: id, Market: "global", PromptVersion: "itest-v1", Model: "mock",
		Input: map[string]any{
			"level": map[string]any{
				"assets":      map[string]any{"base": "a", "target": "b"},
				"differences": []any{"d1", "d2", "d3", "d4", "d5"},
			},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	processed, err := generation.NewWorker(db).ProcessOne(ctx)
	if err != nil || !processed {
		t.Fatalf("processed=%v err=%v", processed, err)
	}
	job, err := service.Get(ctx, id)
	if err != nil {
		t.Fatal(err)
	}
	if job.Status != "completed" {
		t.Fatalf("job=%+v", job)
	}
}
