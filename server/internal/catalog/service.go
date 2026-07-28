package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
)

var ErrNotFound = errors.New("catalog item not found")

type Level struct {
	ID              string `json:"id"`
	Version         int    `json:"version"`
	Title           string `json:"title"`
	Difficulty      int    `json:"difficulty"`
	DifferenceCount int    `json:"difference_count"`
	ThumbnailURL    string `json:"thumbnail_url"`
	SortOrder       int    `json:"sort_order"`
	AvailableDate   string `json:"available_date"`
	Completed       bool   `json:"completed"`
}

type Series struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Mode        string  `json:"mode"`
	CoverURL    string  `json:"cover_url"`
	SortOrder   int     `json:"sort_order"`
	Enabled     bool    `json:"enabled"`
	Levels      []Level `json:"levels"`
}

type UpsertLevel struct {
	SeriesID  string          `json:"series_id"`
	SortOrder int             `json:"sort_order"`
	Status    string          `json:"status"`
	Runtime   json.RawMessage `json:"runtime_json"`
}

type PublicQuery struct {
	UserID        string
	Locale        string
	DefaultLocale string
}

type Service interface {
	Public(context.Context, PublicQuery) ([]Series, error)
	Admin(context.Context) ([]Series, error)
	GetLevel(context.Context, string) (json.RawMessage, error)
	UpsertSeries(context.Context, Series) error
	UpsertLevel(context.Context, string, UpsertLevel) error
}

type MemoryService struct {
	mu     sync.RWMutex
	series map[string]Series
}

func NewMemoryService() *MemoryService { return &MemoryService{series: map[string]Series{}} }

func (s *MemoryService) Public(_ context.Context, _ PublicQuery) ([]Series, error) {
	return s.list(false), nil
}
func (s *MemoryService) Admin(_ context.Context) ([]Series, error) { return s.list(true), nil }
func (s *MemoryService) GetLevel(context.Context, string) (json.RawMessage, error) {
	return nil, ErrNotFound
}
func (s *MemoryService) list(admin bool) []Series {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := []Series{}
	for _, item := range s.series {
		if admin || item.Enabled {
			out = append(out, item)
		}
	}
	return out
}
func (s *MemoryService) UpsertSeries(_ context.Context, item Series) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.series[item.ID] = item
	return nil
}
func (s *MemoryService) UpsertLevel(context.Context, string, UpsertLevel) error { return nil }

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }
func (s *MySQLService) Public(ctx context.Context, query PublicQuery) ([]Series, error) {
	return s.list(ctx, false, query)
}
func (s *MySQLService) Admin(ctx context.Context) ([]Series, error) {
	return s.list(ctx, true, PublicQuery{})
}
func (s *MySQLService) GetLevel(ctx context.Context, id string) (json.RawMessage, error) {
	var raw []byte
	err := s.db.QueryRowContext(ctx, `SELECT runtime_json FROM level_versions WHERE level_id=? ORDER BY version DESC LIMIT 1`, id).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return json.RawMessage(raw), err
}

func (s *MySQLService) list(ctx context.Context, admin bool, query PublicQuery) ([]Series, error) {
	where := "WHERE s.enabled=TRUE"
	if admin {
		where = ""
	}
	requestedLocale := query.Locale
	defaultLocale := query.DefaultLocale
	if requestedLocale == "" {
		requestedLocale = "en-US"
	}
	if defaultLocale == "" {
		defaultLocale = "en-US"
	}
	rows, err := s.db.QueryContext(ctx, `SELECT s.id,
		COALESCE(req.title,def.title,en.title,s.title,s.id),
		COALESCE(req.description,def.description,en.description,s.description,''),
		s.mode,s.cover_url,s.sort_order,s.enabled
		FROM content_series s
		LEFT JOIN content_series_i18n req ON req.series_id=s.id AND req.locale=?
		LEFT JOIN content_series_i18n def ON def.series_id=s.id AND def.locale=?
		LEFT JOIN content_series_i18n en ON en.series_id=s.id AND en.locale='en-US' `+where+`
		ORDER BY (s.id='daily_task') ASC,s.sort_order ASC,s.created_at DESC,s.id`, requestedLocale, defaultLocale)
	if err != nil {
		return nil, fmt.Errorf("list series: %w", err)
	}
	defer rows.Close()
	out := []Series{}
	for rows.Next() {
		var item Series
		if err := rows.Scan(&item.ID, &item.Title, &item.Description, &item.Mode, &item.CoverURL, &item.SortOrder, &item.Enabled); err != nil {
			return nil, err
		}
		item.Levels = []Level{}
		levelWhere := "AND sl.enabled=TRUE AND lv.status='published'"
		if admin {
			levelWhere = "AND sl.enabled=TRUE AND lv.status IN ('draft','pending_review','approved','staging','published','disabled')"
		}
		levelOrder := "ORDER BY sl.sort_order ASC,sl.created_at DESC,sl.level_id"
		if item.ID == "daily_task" {
			if !admin {
				levelWhere += ` AND COALESCE(
					NULLIF(JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.available_date')),'null'),
					DATE_FORMAT(COALESCE(lv.published_at,lv.created_at),'%Y-%m-%d')
				) <= DATE_FORMAT(DATE_ADD(UTC_TIMESTAMP(),INTERVAL 8 HOUR),'%Y-%m-%d')`
			}
			levelOrder = `ORDER BY COALESCE(
				NULLIF(JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.available_date')),'null'),
				DATE_FORMAT(COALESCE(lv.published_at,lv.created_at),'%Y-%m-%d')
			) DESC,sl.created_at DESC,sl.level_id`
		}
		levelRows, err := s.db.QueryContext(ctx, `SELECT sl.level_id,lv.version,
			COALESCE(req.title,def.title,en.title,JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.title')),sl.level_id),
			lv.difficulty,
			COALESCE(JSON_LENGTH(JSON_EXTRACT(lv.runtime_json,'$.differences')),0),
			COALESCE(
			  JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.assets.image.thumbnail.url')),
			  JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.assets.image.url')),
			  ''
			),
			sl.sort_order,
			COALESCE(
			  NULLIF(JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.available_date')),'null'),
			  DATE_FORMAT(COALESCE(lv.published_at,lv.created_at),'%Y-%m-%d')
			),
			EXISTS(
			  SELECT 1 FROM level_attempts a
			  WHERE a.user_id=? AND a.level_id=sl.level_id AND a.state='completed'
			)
			FROM content_series_levels sl
			JOIN level_versions lv ON lv.level_id=sl.level_id
			AND lv.version=(SELECT MAX(v2.version) FROM level_versions v2 WHERE v2.level_id=sl.level_id)
			LEFT JOIN content_level_i18n req ON req.level_id=sl.level_id AND req.locale=?
			LEFT JOIN content_level_i18n def ON def.level_id=sl.level_id AND def.locale=?
			LEFT JOIN content_level_i18n en ON en.level_id=sl.level_id AND en.locale='en-US'
			WHERE sl.series_id=? `+levelWhere+" "+levelOrder, query.UserID, requestedLocale, defaultLocale, item.ID)
		if err != nil {
			return nil, err
		}
		for levelRows.Next() {
			var level Level
			if err := levelRows.Scan(&level.ID, &level.Version, &level.Title, &level.Difficulty, &level.DifferenceCount, &level.ThumbnailURL, &level.SortOrder, &level.AvailableDate, &level.Completed); err != nil {
				levelRows.Close()
				return nil, err
			}
			item.Levels = append(item.Levels, level)
		}
		levelRows.Close()
		out = append(out, item)
	}
	return out, rows.Err()
}

func (s *MySQLService) UpsertSeries(ctx context.Context, item Series) error {
	if item.ID == "" || item.Title == "" || item.Mode == "" {
		return errors.New("series id, title and mode are required")
	}
	_, err := s.db.ExecContext(ctx, `INSERT INTO content_series(id,title,description,mode,cover_url,sort_order,enabled)
		VALUES(?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE title=VALUES(title),description=VALUES(description),
		mode=VALUES(mode),cover_url=VALUES(cover_url),sort_order=VALUES(sort_order),enabled=VALUES(enabled)`,
		item.ID, item.Title, item.Description, item.Mode, item.CoverURL, item.SortOrder, item.Enabled)
	return err
}

func (s *MySQLService) UpsertLevel(ctx context.Context, levelID string, input UpsertLevel) error {
	var runtime map[string]any
	if levelID == "" || input.SeriesID == "" || json.Unmarshal(input.Runtime, &runtime) != nil {
		return errors.New("level id, series id and valid runtime_json are required")
	}
	version, ok := number(runtime["level_version"])
	if !ok {
		return errors.New("runtime_json.level_version is required")
	}
	mode, _ := runtime["mode"].(string)
	difficulty := 1
	if d, ok := runtime["difficulty"].(map[string]any); ok {
		if v, valid := number(d["total"]); valid {
			difficulty = v
		}
	}
	diffs, _ := runtime["differences"].([]any)
	status := input.Status
	if status == "" {
		status = "draft"
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `INSERT INTO levels(id,mode) VALUES(?,?) ON DUPLICATE KEY UPDATE mode=VALUES(mode)`, levelID, mode); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO level_versions(level_id,version,schema_version,status,runtime_json,difficulty,quality_score,published_at)
		VALUES(?,?,1,?,?,?,100,CASE WHEN ?='published' THEN UTC_TIMESTAMP(3) ELSE NULL END)
		ON DUPLICATE KEY UPDATE status=VALUES(status),runtime_json=VALUES(runtime_json),difficulty=VALUES(difficulty),
		published_at=CASE WHEN VALUES(status)='published' THEN COALESCE(published_at,UTC_TIMESTAMP(3)) ELSE published_at END`,
		levelID, version, status, input.Runtime, difficulty, status); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM level_differences WHERE level_id=? AND level_version=?`, levelID, version); err != nil {
		return err
	}
	for _, raw := range diffs {
		diff, _ := raw.(map[string]any)
		key, _ := diff["id"].(string)
		diffDifficulty, _ := number(diff["difficulty"])
		if key == "" {
			return errors.New("each difference requires an id")
		}
		if diffDifficulty == 0 {
			diffDifficulty = 1
		}
		if _, err = tx.ExecContext(ctx, `INSERT INTO level_differences(level_id,level_version,diff_key,difficulty) VALUES(?,?,?,?)`, levelID, version, key, diffDifficulty); err != nil {
			return err
		}
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO content_series_levels(series_id,level_id,sort_order,enabled)
		VALUES(?,?,?,TRUE) ON DUPLICATE KEY UPDATE sort_order=VALUES(sort_order),enabled=TRUE`, input.SeriesID, levelID, input.SortOrder); err != nil {
		return err
	}
	return tx.Commit()
}

func number(value any) (int, bool) {
	switch v := value.(type) {
	case float64:
		return int(v), true
	case int:
		return v, true
	default:
		return 0, false
	}
}
