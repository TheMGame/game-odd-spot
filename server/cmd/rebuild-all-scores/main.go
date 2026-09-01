package main

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	levels "game-odd-spot/server/internal/level"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	dsn := os.Getenv("ODDSPOT_DATABASE_DSN")
	if dsn == "" {
		slog.Error("ODDSPOT_DATABASE_DSN environment variable is required")
		os.Exit(1)
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		slog.Error("open mysql failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	db.SetMaxOpenConns(8)
	db.SetConnMaxLifetime(5 * time.Minute)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, os.Interrupt, syscall.SIGTERM)
	go func() { <-ch; slog.Info("interrupt received, stopping after current user"); cancel() }()

	pingCtx, pingCancel := context.WithTimeout(ctx, 5*time.Second)
	defer pingCancel()
	if err := db.PingContext(pingCtx); err != nil {
		slog.Error("ping mysql failed", "error", err)
		os.Exit(1)
	}
	fmt.Println("=== Oddspot 全量玩家得分回填工具 ===")
	fmt.Println("  处理对象：level_attempts.state='completed' 的所有 DISTINCT 用户")
	fmt.Println("  写入表：level_best_scores / user_level_best_scores / user_score_totals")
	fmt.Println("  同时会重算 level_attempts.score/points 为 NULL 或 0 的历史记录")

	rows, err := db.QueryContext(ctx, `SELECT DISTINCT user_id FROM level_attempts WHERE state='completed' ORDER BY user_id`)
	if err != nil {
		slog.Error("query distinct users failed", "error", err)
		os.Exit(1)
	}
	defer rows.Close()
	users := []string{}
	for rows.Next() {
		var u string
		if err := rows.Scan(&u); err != nil {
			slog.Error("scan user failed", "error", err)
			continue
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		slog.Error("rows err", "error", err)
		os.Exit(1)
	}
	fmt.Printf("\n目标玩家数：%d\n\n", len(users))

	svc := levels.NewMySQLService(db)
	done, failed := 0, 0
	t0 := time.Now()
	for i, uid := range users {
		if ctx.Err() != nil {
			break
		}
		if err := svc.RebuildScoresFor(ctx, uid); err != nil {
			slog.Error("rebuild failed", "index", i+1, "user", shortID(uid), "error", err)
			failed++
			continue
		}
		done++
		if (i+1)%5 == 0 || i+1 == len(users) {
			fmt.Printf("  [%d/%d] 已完成 %d  失败 %d  耗时 %s\n", i+1, len(users), done, failed, time.Since(t0).Round(time.Millisecond))
		}
	}
	fmt.Printf("\n=== 完成 ===\n  成功 %d  失败 %d  总计 %d  总耗时 %s\n", done, failed, len(users), time.Since(t0).Round(time.Millisecond))

	fmt.Println("\n--- TOP 10 玩家排行榜（按总积分） ---")
	top, err := db.QueryContext(ctx, `SELECT t.user_id,t.total_points,t.completed_levels,t.score_sum,t.updated_at
		FROM user_score_totals t ORDER BY t.total_points DESC,t.completed_levels DESC,t.updated_at ASC LIMIT 10`)
	if err != nil {
		slog.Error("query totals failed", "error", err)
		return
	}
	defer top.Close()
	fmt.Printf("%-28s %10s %8s %10s %22s\n", "user_id", "points", "levels", "score_sum", "updated_at")
	for top.Next() {
		var uid string
		var points, levels, scoreSum, updatedAt string
		top.Scan(&uid, &points, &levels, &scoreSum, &updatedAt)
		fmt.Printf("%-28s %10s %8s %10s %22s\n", shortID(uid), points, levels, scoreSum, updatedAt)
	}
}

func shortID(s string) string {
	n := len(s)
	if n <= 28 {
		return s
	}
	return s[:8] + "…" + s[n-16:]
}
