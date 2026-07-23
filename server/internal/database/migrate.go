package database

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"sort"
	"strconv"
	"strings"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

func Migrate(ctx context.Context, db *sql.DB) error {
	if _, err := db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (
      version BIGINT PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      applied_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	var lockAcquired int
	if err := db.QueryRowContext(ctx, "SELECT GET_LOCK('oddspot_schema_migrate', 10)").Scan(&lockAcquired); err != nil || lockAcquired != 1 {
		return fmt.Errorf("acquire migration lock: result=%d error=%w", lockAcquired, err)
	}
	defer func() { _, _ = db.ExecContext(context.Background(), "SELECT RELEASE_LOCK('oddspot_schema_migrate')") }()

	entries, err := fs.ReadDir(migrationFiles, "migrations")
	if err != nil {
		return fmt.Errorf("read embedded migrations: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		versionText, _, ok := strings.Cut(entry.Name(), "_")
		if !ok {
			return fmt.Errorf("migration %q has no numeric prefix", entry.Name())
		}
		version, err := strconv.ParseInt(versionText, 10, 64)
		if err != nil {
			return fmt.Errorf("parse migration version %q: %w", entry.Name(), err)
		}
		var exists int
		err = db.QueryRowContext(ctx, "SELECT COUNT(*) FROM schema_migrations WHERE version = ?", version).Scan(&exists)
		if err != nil {
			return fmt.Errorf("check migration %d: %w", version, err)
		}
		if exists > 0 {
			continue
		}
		contents, err := migrationFiles.ReadFile("migrations/" + entry.Name())
		if err != nil {
			return fmt.Errorf("read migration %q: %w", entry.Name(), err)
		}
		if err := applyMigration(ctx, db, version, entry.Name(), string(contents)); err != nil {
			return err
		}
	}
	return nil
}

func applyMigration(ctx context.Context, db *sql.DB, version int64, name, contents string) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin migration %d: %w", version, err)
	}
	defer func() { _ = tx.Rollback() }()
	for _, statement := range strings.Split(contents, ";") {
		if strings.TrimSpace(statement) == "" {
			continue
		}
		if _, err := tx.ExecContext(ctx, statement); err != nil {
			return fmt.Errorf("apply migration %d (%s): %w", version, name, err)
		}
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO schema_migrations(version, name) VALUES (?, ?)", version, name); err != nil {
		return fmt.Errorf("record migration %d: %w", version, err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit migration %d: %w", version, err)
	}
	return nil
}
