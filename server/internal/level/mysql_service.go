package level

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }

func (s *MySQLService) Home(ctx context.Context, userID string) ([]Summary, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT lv.level_id, lv.version, lv.difficulty,
      CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='image_puzzle'
      THEN (COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.rows') AS UNSIGNED),0)*COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.cols') AS UNSIGNED),0))
      ELSE (SELECT COUNT(*) FROM level_differences d WHERE d.level_id=lv.level_id AND d.level_version=lv.version) END
      FROM level_versions lv
      LEFT JOIN users u ON u.id=?
      WHERE lv.status='published'
      ORDER BY EXISTS(SELECT 1 FROM level_tags t WHERE t.level_id=lv.level_id AND t.level_version=lv.version AND t.tag_type='region' AND t.tag_value=u.market_id) DESC,
      lv.quality_score DESC, lv.published_at DESC, lv.level_id LIMIT 50`, userID)
	if err != nil {
		return nil, fmt.Errorf("query home: %w", err)
	}
	defer rows.Close()
	var result []Summary
	for rows.Next() {
		var item Summary
		if err := rows.Scan(&item.LevelID, &item.LevelVersion, &item.Difficulty, &item.DifferenceCount); err != nil {
			return nil, err
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

func (s *MySQLService) Get(ctx context.Context, id string) (json.RawMessage, error) {
	var raw []byte
	err := s.db.QueryRowContext(ctx, `SELECT runtime_json FROM level_versions WHERE level_id=? AND status='published' ORDER BY version DESC LIMIT 1`, id).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get level: %w", err)
	}
	return json.RawMessage(raw), nil
}

func (s *MySQLService) Start(ctx context.Context, userID, levelID string, request StartRequest) (AttemptResult, error) {
	return s.mutate(ctx, userID, "level_start", request.IdempotencyKey, request, func(tx *sql.Tx) (AttemptResult, error) {
		var count int
		err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM level_versions WHERE level_id=? AND version=? AND status='published'`, levelID, request.LevelVersion).Scan(&count)
		if err != nil {
			return AttemptResult{}, err
		}
		if count == 0 {
			return AttemptResult{}, ErrVersionMismatch
		}
		_, err = tx.ExecContext(ctx, `INSERT INTO level_attempts(id,user_id,level_id,level_version,state) VALUES(?,?,?,?,'in_progress')
          ON DUPLICATE KEY UPDATE id=id`, request.AttemptID, userID, levelID, request.LevelVersion)
		if err != nil {
			return AttemptResult{}, fmt.Errorf("insert attempt: %w", err)
		}
		var owner, state string
		var version, total int
		err = tx.QueryRowContext(ctx, `SELECT a.user_id,a.state,a.level_version,
		  CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='image_puzzle'
		  THEN (COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.rows') AS UNSIGNED),0)*COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.cols') AS UNSIGNED),0))
		  ELSE (SELECT COUNT(*) FROM level_differences d WHERE d.level_id=a.level_id AND d.level_version=a.level_version) END
		  FROM level_attempts a JOIN level_versions lv ON lv.level_id=a.level_id AND lv.version=a.level_version WHERE a.id=?`, request.AttemptID).Scan(&owner, &state, &version, &total)
		if err != nil {
			return AttemptResult{}, err
		}
		if owner != userID || version != request.LevelVersion {
			return AttemptResult{}, ErrInvalidState
		}
		return AttemptResult{AttemptID: request.AttemptID, State: state, TotalCount: total}, nil
	})
}

func (s *MySQLService) Progress(ctx context.Context, userID, levelID string, request ProgressRequest) (AttemptResult, error) {
	return s.mutate(ctx, userID, "level_progress", request.IdempotencyKey, request, func(tx *sql.Tx) (AttemptResult, error) {
		attemptLevel, version, state, err := lockAttempt(ctx, tx, userID, request.AttemptID)
		if err != nil {
			return AttemptResult{}, err
		}
		if attemptLevel != levelID || state != "in_progress" {
			return AttemptResult{}, ErrInvalidState
		}
		mode, _, _, err := levelPuzzleConfig(ctx, tx, attemptLevel, version)
		if err != nil {
			return AttemptResult{}, err
		}
		if mode == "image_puzzle" && len(request.Found) > 0 {
			return AttemptResult{}, ErrInvalidDiff
		}
		if err := insertFound(ctx, tx, request.AttemptID, attemptLevel, version, request.Found); err != nil {
			return AttemptResult{}, err
		}
		_, err = tx.ExecContext(ctx, `UPDATE level_attempts SET hints_used=GREATEST(hints_used,?),duration_ms=GREATEST(duration_ms,?) WHERE id=?`, request.HintsUsed, request.DurationMS, request.AttemptID)
		if err != nil {
			return AttemptResult{}, err
		}
		return attemptResult(ctx, tx, request.AttemptID)
	})
}

func (s *MySQLService) Complete(ctx context.Context, userID, levelID string, request CompleteRequest) (AttemptResult, error) {
	return s.mutate(ctx, userID, "level_complete", request.IdempotencyKey, request, func(tx *sql.Tx) (AttemptResult, error) {
		attemptLevel, version, state, err := lockAttempt(ctx, tx, userID, request.AttemptID)
		if err != nil {
			return AttemptResult{}, err
		}
		if attemptLevel != levelID {
			return AttemptResult{}, ErrInvalidState
		}
		if state == "completed" {
			return attemptResult(ctx, tx, request.AttemptID)
		}
		mode, rows, cols, err := levelPuzzleConfig(ctx, tx, attemptLevel, version)
		if err != nil {
			return AttemptResult{}, err
		}
		if mode == "image_puzzle" {
			if len(request.PuzzleOrder) != rows*cols {
				return AttemptResult{}, ErrIncomplete
			}
			for i, piece := range request.PuzzleOrder {
				if piece != i {
					return AttemptResult{}, ErrIncomplete
				}
			}
		} else {
			found := make([]FoundDifference, 0, len(request.DifferenceIDs))
			for _, id := range request.DifferenceIDs {
				found = append(found, FoundDifference{DifferenceID: id, FoundAtMS: request.DurationMS})
			}
			if err := insertFound(ctx, tx, request.AttemptID, attemptLevel, version, found); err != nil {
				return AttemptResult{}, err
			}
			var expected, actual int
			_ = tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM level_differences WHERE level_id=? AND level_version=?`, attemptLevel, version).Scan(&expected)
			_ = tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM attempt_differences WHERE attempt_id=?`, request.AttemptID).Scan(&actual)
			if actual != expected {
				return AttemptResult{}, ErrIncomplete
			}
		}
		_, err = tx.ExecContext(ctx, `UPDATE level_attempts SET state='completed',hints_used=?,duration_ms=?,completed_at=UTC_TIMESTAMP(3) WHERE id=?`, request.HintsUsed, request.DurationMS, request.AttemptID)
		if err != nil {
			return AttemptResult{}, err
		}
		rewardID := "rwd_" + request.AttemptID
		_, err = tx.ExecContext(ctx, `INSERT IGNORE INTO reward_ledger(id,user_id,asset_type,amount,source_type,source_id) VALUES(?,?,'hint',1,'level_complete',?)`, rewardID, userID, request.AttemptID)
		if err != nil {
			return AttemptResult{}, err
		}
		result, err := attemptResult(ctx, tx, request.AttemptID)
		result.Reward = 1
		return result, err
	})
}

// Reset clears a user's attempts for a level so a replay starts from a clean
// slate. Scoped to the calling user and level; other users are unaffected.
func (s *MySQLService) Reset(ctx context.Context, userID, levelID string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `DELETE FROM attempt_differences WHERE attempt_id IN (SELECT id FROM level_attempts WHERE user_id=? AND level_id=?)`, userID, levelID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM level_attempts WHERE user_id=? AND level_id=?`, userID, levelID); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *MySQLService) mutate(ctx context.Context, userID, route, key string, request any, operation func(*sql.Tx) (AttemptResult, error)) (AttemptResult, error) {
	raw, _ := json.Marshal(request)
	hash := sha256.Sum256(raw)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return AttemptResult{}, err
	}
	defer func() { _ = tx.Rollback() }()
	var existingHash []byte
	var response []byte
	err = tx.QueryRowContext(ctx, `SELECT request_hash,response_body FROM idempotency_records WHERE user_id=? AND route=? AND idempotency_key=? FOR UPDATE`, userID, route, key).Scan(&existingHash, &response)
	if err == nil {
		if string(existingHash) != string(hash[:]) {
			return AttemptResult{}, ErrIdempotency
		}
		var result AttemptResult
		if json.Unmarshal(response, &result) != nil {
			return AttemptResult{}, ErrInvalidState
		}
		return result, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return AttemptResult{}, err
	}
	result, err := operation(tx)
	if err != nil {
		return AttemptResult{}, err
	}
	encoded, _ := json.Marshal(result)
	_, err = tx.ExecContext(ctx, `INSERT INTO idempotency_records(user_id,route,idempotency_key,request_hash,state,response_status,response_body) VALUES(?,?,?,?,'completed',200,?)`, userID, route, key, hash[:], encoded)
	if err != nil {
		return AttemptResult{}, err
	}
	if err = tx.Commit(); err != nil {
		return AttemptResult{}, err
	}
	return result, nil
}

func lockAttempt(ctx context.Context, tx *sql.Tx, userID, attemptID string) (string, int, string, error) {
	var levelID, state, owner string
	var version int
	err := tx.QueryRowContext(ctx, `SELECT user_id,level_id,level_version,state FROM level_attempts WHERE id=? FOR UPDATE`, attemptID).Scan(&owner, &levelID, &version, &state)
	if errors.Is(err, sql.ErrNoRows) {
		return "", 0, "", ErrInvalidState
	}
	if err != nil {
		return "", 0, "", err
	}
	if owner != userID {
		return "", 0, "", ErrInvalidState
	}
	return levelID, version, state, nil
}

func insertFound(ctx context.Context, tx *sql.Tx, attemptID, levelID string, version int, found []FoundDifference) error {
	for _, item := range found {
		var exists int
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM level_differences WHERE level_id=? AND level_version=? AND diff_key=?`, levelID, version, item.DifferenceID).Scan(&exists); err != nil {
			return err
		}
		if exists == 0 {
			return ErrInvalidDiff
		}
		if _, err := tx.ExecContext(ctx, `INSERT IGNORE INTO attempt_differences(attempt_id,diff_key,found_at_ms) VALUES(?,?,?)`, attemptID, item.DifferenceID, item.FoundAtMS); err != nil {
			return err
		}
	}
	return nil
}

func attemptResult(ctx context.Context, tx *sql.Tx, attemptID string) (AttemptResult, error) {
	var r AttemptResult
	r.AttemptID = attemptID
	err := tx.QueryRowContext(ctx, `SELECT a.state,a.hints_used,a.duration_ms,
	  CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='image_puzzle' AND a.state='completed'
	    THEN (COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.rows') AS UNSIGNED),0)*COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.cols') AS UNSIGNED),0))
	    ELSE (SELECT COUNT(*) FROM attempt_differences f WHERE f.attempt_id=a.id) END,
	  CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='image_puzzle'
	    THEN (COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.rows') AS UNSIGNED),0)*COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.cols') AS UNSIGNED),0))
	    ELSE (SELECT COUNT(*) FROM level_differences d WHERE d.level_id=a.level_id AND d.level_version=a.level_version) END
	  FROM level_attempts a JOIN level_versions lv ON lv.level_id=a.level_id AND lv.version=a.level_version WHERE a.id=?`, attemptID).Scan(&r.State, &r.HintsUsed, &r.DurationMS, &r.FoundCount, &r.TotalCount)
	return r, err
}

func levelPuzzleConfig(ctx context.Context, tx *sql.Tx, levelID string, version int) (string, int, int, error) {
	var raw []byte
	if err := tx.QueryRowContext(ctx, `SELECT runtime_json FROM level_versions WHERE level_id=? AND version=?`, levelID, version).Scan(&raw); err != nil {
		return "", 0, 0, err
	}
	var runtime struct {
		Mode   string `json:"mode"`
		Puzzle *struct {
			Rows int `json:"rows"`
			Cols int `json:"cols"`
		} `json:"puzzle"`
	}
	if err := json.Unmarshal(raw, &runtime); err != nil {
		return "", 0, 0, err
	}
	if runtime.Mode == "image_puzzle" {
		if runtime.Puzzle == nil || runtime.Puzzle.Rows < 2 || runtime.Puzzle.Cols < 2 {
			return "", 0, 0, ErrInvalidState
		}
		return runtime.Mode, runtime.Puzzle.Rows, runtime.Puzzle.Cols, nil
	}
	return runtime.Mode, 0, 0, nil
}
