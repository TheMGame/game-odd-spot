//go:build integration

package level_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"game-odd-spot/server/internal/database"
	"game-odd-spot/server/internal/level"
	"game-odd-spot/server/internal/session"
)

func TestRemoteLevelFlow(t *testing.T) {
	dsn := os.Getenv("ODDSPOT_DATABASE_DSN")
	key := os.Getenv("ODDSPOT_INSTALLATION_HMAC_KEY")
	if dsn == "" || key == "" {
		t.Skip("database integration environment is not configured")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	db, err := database.Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	sessions := session.NewMySQLService(db, key)
	created, err := sessions.CreateOrRestore(ctx, session.CreateRequest{
		InstallationID: fmt.Sprintf("integration-level-%d-0123456789abcdef", time.Now().UnixNano()),
		Market:         "global", Locale: "en-US",
	})
	if err != nil {
		t.Fatal(err)
	}
	service := level.NewMySQLService(db)
	attemptID := fmt.Sprintf("itest_%d", time.Now().UnixNano())
	started, err := service.Start(ctx, created.UserID, "global_demo_001", level.StartRequest{AttemptID: attemptID, LevelVersion: 1, IdempotencyKey: "itest-start-" + attemptID})
	if err != nil {
		t.Fatal(err)
	}
	if started.State != "in_progress" || started.TotalCount != 5 {
		t.Fatalf("started=%+v", started)
	}
	completed, err := service.Complete(ctx, created.UserID, "global_demo_001", level.CompleteRequest{AttemptID: attemptID, DifferenceIDs: []string{"d1", "d2", "d3", "d4", "d5"}, DurationMS: 5000, IdempotencyKey: "itest-complete-" + attemptID})
	if err != nil {
		t.Fatal(err)
	}
	if completed.State != "completed" || completed.Reward != 1 {
		t.Fatalf("completed=%+v", completed)
	}
	replayed, err := service.Complete(ctx, created.UserID, "global_demo_001", level.CompleteRequest{AttemptID: attemptID, DifferenceIDs: []string{"d1", "d2", "d3", "d4", "d5"}, DurationMS: 5000, IdempotencyKey: "itest-complete-" + attemptID})
	if err != nil {
		t.Fatal(err)
	}
	if replayed != completed {
		t.Fatalf("replay=%+v completed=%+v", replayed, completed)
	}
}
