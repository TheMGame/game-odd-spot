package level

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"
)

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db: db} }

func (s *MySQLService) Home(ctx context.Context, userID string) ([]Summary, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT lv.level_id, lv.version, lv.difficulty,
      CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='image_puzzle'
      THEN (COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.rows') AS UNSIGNED),0)*COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.cols') AS UNSIGNED),0))
      WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='interactive_story'
      THEN COALESCE(JSON_LENGTH(JSON_EXTRACT(lv.runtime_json,'$.story.nodes')),0)
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
		  WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='interactive_story'
		  THEN COALESCE(JSON_LENGTH(JSON_EXTRACT(lv.runtime_json,'$.story.nodes')),0)
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
		_, err = tx.ExecContext(ctx, `UPDATE level_attempts SET hints_used=GREATEST(hints_used,?),duration_ms=GREATEST(duration_ms,?),wrong_taps=GREATEST(wrong_taps,?) WHERE id=?`, request.HintsUsed, request.DurationMS, request.WrongTaps, request.AttemptID)
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
		levelDifficulty, differenceDifficulties, err := scoreConfig(ctx, tx, attemptLevel, version)
		if err != nil {
			return AttemptResult{}, err
		}
		var savedHints, savedWrongTaps int
		var savedDuration int64
		if err = tx.QueryRowContext(ctx, `SELECT hints_used,duration_ms,wrong_taps FROM level_attempts WHERE id=?`, request.AttemptID).Scan(&savedHints, &savedDuration, &savedWrongTaps); err != nil {
			return AttemptResult{}, err
		}
		request.HintsUsed = maxInt(request.HintsUsed, savedHints)
		request.WrongTaps = maxInt(request.WrongTaps, savedWrongTaps)
		if request.DurationMS < savedDuration {
			request.DurationMS = savedDuration
		}
		score := CalculateScore(levelDifficulty, differenceDifficulties, request.DurationMS, request.HintsUsed, request.WrongTaps)
		points := CalculatePoints(score, levelDifficulty)
		_, err = tx.ExecContext(ctx, `UPDATE level_attempts SET state='completed',hints_used=?,duration_ms=?,wrong_taps=?,score=?,points=?,completed_at=UTC_TIMESTAMP(3) WHERE id=?`, request.HintsUsed, request.DurationMS, request.WrongTaps, score, points, request.AttemptID)
		if err != nil {
			return AttemptResult{}, err
		}
		if err = upsertBestScore(ctx, tx, userID, attemptLevel, version, request.AttemptID, score, points, request.DurationMS, request.HintsUsed, request.WrongTaps); err != nil {
			return AttemptResult{}, err
		}
		if err = upsertLifetimeScore(ctx, tx, userID, attemptLevel, version, request.AttemptID, score, points, request.DurationMS, request.HintsUsed, request.WrongTaps); err != nil {
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

func (s *MySQLService) LevelLeaderboard(ctx context.Context, userID, levelID string, limit int) (Leaderboard, error) {
	limit = clampInt(limit, 1, 100)
	var version int
	if err := s.db.QueryRowContext(ctx, `SELECT version FROM level_versions WHERE level_id=? AND status='published' ORDER BY version DESC LIMIT 1`, levelID).Scan(&version); errors.Is(err, sql.ErrNoRows) {
		return Leaderboard{}, ErrNotFound
	} else if err != nil {
		return Leaderboard{}, err
	}
	rows, err := s.db.QueryContext(ctx, `SELECT b.user_id,b.score,b.points,b.duration_ms,b.hints_used,b.wrong_taps,
		u.display_name,u.avatar_url
	  FROM level_best_scores b LEFT JOIN users u ON u.id=b.user_id
	  WHERE b.level_id=? AND b.level_version=?
	  ORDER BY b.score DESC,b.hints_used ASC,b.wrong_taps ASC,b.duration_ms ASC,b.achieved_at ASC LIMIT ?`, levelID, version, limit)
	if err != nil {
		return Leaderboard{}, err
	}
	defer rows.Close()
	entries := []LeaderboardEntry{}
	for rows.Next() {
		var (
			entry                                 LeaderboardEntry
			displayName, avatarURL                sql.NullString
		)
		if err := rows.Scan(&entry.UserID, &entry.Score, &entry.Points, &entry.DurationMS, &entry.HintsUsed, &entry.WrongTaps,
			&displayName, &avatarURL); err != nil {
			return Leaderboard{}, err
		}
		entry.Rank = len(entries) + 1
		entry.IsMe = entry.UserID == userID
		entry.DisplayName = pickDisplayName(displayName.String, entry.UserID)
		entry.AvatarURL = avatarURL.String
		entries = append(entries, entry)
	}
	if err := rows.Err(); err != nil {
		return Leaderboard{}, err
	}
	board := Leaderboard{Scope: "level", LevelID: levelID, LevelVersion: version, Entries: entries}
	board.MyEntry, err = s.levelRank(ctx, userID, levelID, version)
	return board, err
}

func (s *MySQLService) levelRank(ctx context.Context, userID, levelID string, version int) (*LeaderboardEntry, error) {
	var (
		entry                  LeaderboardEntry
		displayName, avatarURL sql.NullString
	)
	err := s.db.QueryRowContext(ctx, `SELECT b.user_id,b.score,b.points,b.duration_ms,b.hints_used,b.wrong_taps,
		u.display_name,u.avatar_url,
	  1+(SELECT COUNT(*) FROM level_best_scores x WHERE x.level_id=b.level_id AND x.level_version=b.level_version AND
	    (x.score>b.score OR (x.score=b.score AND x.hints_used<b.hints_used) OR
	     (x.score=b.score AND x.hints_used=b.hints_used AND x.wrong_taps<b.wrong_taps) OR
	     (x.score=b.score AND x.hints_used=b.hints_used AND x.wrong_taps=b.wrong_taps AND x.duration_ms<b.duration_ms)))
	  FROM level_best_scores b LEFT JOIN users u ON u.id=b.user_id
	  WHERE b.user_id=? AND b.level_id=? AND b.level_version=?`, userID, levelID, version).
		Scan(&entry.UserID, &entry.Score, &entry.Points, &entry.DurationMS, &entry.HintsUsed, &entry.WrongTaps,
			&displayName, &avatarURL, &entry.Rank)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	entry.IsMe = true
	entry.DisplayName = pickDisplayName(displayName.String, entry.UserID)
	entry.AvatarURL = avatarURL.String
	return &entry, nil
}

func (s *MySQLService) OverallLeaderboard(ctx context.Context, userID string, limit int) (Leaderboard, error) {
	limit = clampInt(limit, 1, 100)
	query := `WITH totals AS (SELECT t.user_id,t.total_points points,ROUND(t.score_sum/GREATEST(t.completed_levels,1)) score,t.completed_levels,t.updated_at achieved_at FROM user_score_totals t),
	  ranked AS (SELECT user_id,points,score,completed_levels,ROW_NUMBER() OVER (ORDER BY points DESC,completed_levels DESC,score DESC,achieved_at ASC) ranking FROM totals)
	  SELECT r.user_id,r.points,r.score,r.completed_levels,r.ranking,u.display_name,u.avatar_url
	  FROM ranked r LEFT JOIN users u ON u.id=r.user_id ORDER BY r.ranking LIMIT ?`
	rows, err := s.db.QueryContext(ctx, query, limit)
	if err != nil {
		return Leaderboard{}, err
	}
	defer rows.Close()
	entries := []LeaderboardEntry{}
	for rows.Next() {
		var (
			entry                  LeaderboardEntry
			displayName, avatarURL sql.NullString
		)
		if err := rows.Scan(&entry.UserID, &entry.Points, &entry.Score, &entry.CompletedLevels, &entry.Rank,
			&displayName, &avatarURL); err != nil {
			return Leaderboard{}, err
		}
		entry.IsMe = entry.UserID == userID
		entry.DisplayName = pickDisplayName(displayName.String, entry.UserID)
		entry.AvatarURL = avatarURL.String
		entries = append(entries, entry)
	}
	if err := rows.Err(); err != nil {
		return Leaderboard{}, err
	}
	board := Leaderboard{Scope: "overall", Entries: entries}
	for i := range entries {
		if entries[i].IsMe {
			cp := entries[i]
			board.MyEntry = &cp
		}
	}
	if board.MyEntry == nil {
		myQuery := strings.Replace(query, "ORDER BY r.ranking LIMIT ?", "WHERE r.user_id=?", 1)
		var (
			entry                  LeaderboardEntry
			displayName, avatarURL sql.NullString
		)
		err = s.db.QueryRowContext(ctx, myQuery, userID).Scan(&entry.UserID, &entry.Points, &entry.Score, &entry.CompletedLevels, &entry.Rank,
			&displayName, &avatarURL)
		if err == nil {
			entry.IsMe = true
			entry.DisplayName = pickDisplayName(displayName.String, entry.UserID)
			entry.AvatarURL = avatarURL.String
			board.MyEntry = &entry
		} else if !errors.Is(err, sql.ErrNoRows) {
			return Leaderboard{}, err
		}
	}
	return board, nil
}

func pickDisplayName(got, userID string) string {
	if got != "" {
		return got
	}
	return displayName(userID)
}

func (s *MySQLService) PlayerStats(ctx context.Context, userID string) (PlayerStats, error) {
	stats := PlayerStats{UserID: userID, DisplayName: displayName(userID), PlayerLevel: 1, NextLevelPoints: 100, LevelScores: []PlayerLevelScore{}}
	var scoreSum int
	var totalsUpdatedAt sql.NullTime
	var maxCompleted sql.NullTime
	var displayNameCol, avatarURL sql.NullString
	_ = s.db.QueryRowContext(ctx, `SELECT COALESCE(MAX(completed_at),'1970-01-01') FROM level_attempts WHERE user_id=? AND state='completed'`, userID).Scan(&maxCompleted)
	_ = s.db.QueryRowContext(ctx, `SELECT display_name,avatar_url FROM users WHERE id=?`, userID).Scan(&displayNameCol, &avatarURL)
	if displayNameCol.String != "" {
		stats.DisplayName = displayNameCol.String
	}
	stats.AvatarURL = avatarURL.String
	totalsErr := s.db.QueryRowContext(ctx, `SELECT total_points,completed_levels,score_sum,updated_at FROM user_score_totals WHERE user_id=?`, userID).Scan(&stats.TotalPoints, &stats.CompletedLevels, &scoreSum, &totalsUpdatedAt)
	needRebuild := false
	switch {
	case errors.Is(totalsErr, sql.ErrNoRows):
		needRebuild = true
	case totalsErr != nil:
		return PlayerStats{}, totalsErr
	case maxCompleted.Valid && totalsUpdatedAt.Valid && maxCompleted.Time.After(totalsUpdatedAt.Time.Add(-time.Second)):
		needRebuild = true
	}
	if needRebuild {
		if repairErr := s.rebuildUserScores(ctx, userID); repairErr == nil {
			totalsErr = s.db.QueryRowContext(ctx, `SELECT total_points,completed_levels,score_sum FROM user_score_totals WHERE user_id=?`, userID).Scan(&stats.TotalPoints, &stats.CompletedLevels, &scoreSum)
			if errors.Is(totalsErr, sql.ErrNoRows) {
				return stats, nil
			}
			if totalsErr != nil {
				return PlayerStats{}, totalsErr
			}
		} else if repairErr == context.Canceled || repairErr == context.DeadlineExceeded {
			return PlayerStats{}, repairErr
		}
	}
	if stats.CompletedLevels > 0 {
		stats.AverageScore = int(math.Round(float64(scoreSum) / float64(stats.CompletedLevels)))
	}
	stats.PlayerLevel, stats.LevelProgress, stats.NextLevelPoints = LevelProgress(stats.TotalPoints)
	_ = s.db.QueryRowContext(ctx, `WITH ranked AS (SELECT user_id,ROW_NUMBER() OVER (ORDER BY total_points DESC,completed_levels DESC,(score_sum/GREATEST(completed_levels,1)) DESC,updated_at ASC) ranking FROM user_score_totals) SELECT ranking FROM ranked WHERE user_id=?`, userID).Scan(&stats.GlobalRank)
	rows, queryErr := s.db.QueryContext(ctx, `SELECT level_id,level_version,score,points FROM user_level_best_scores WHERE user_id=? ORDER BY achieved_at DESC`, userID)
	if queryErr != nil {
		return PlayerStats{}, queryErr
	}
	defer rows.Close()
	for rows.Next() {
		var item PlayerLevelScore
		if err := rows.Scan(&item.LevelID, &item.LevelVersion, &item.Score, &item.Points); err != nil {
			return PlayerStats{}, err
		}
		stats.LevelScores = append(stats.LevelScores, item)
	}
	if err := rows.Err(); err != nil {
		return PlayerStats{}, err
	}
	return stats, nil
}

type bestScoreRow struct {
	score, points, hints, wrongTaps int
	durationMS                      int64
	attemptID                       string
}

type userBestRow struct {
	levelID                         string
	version                         int
	score, points, hints, wrongTaps int
	durationMS                      int64
	attemptID                       string
}

func (s *MySQLService) rebuildUserScores(ctx context.Context, userID string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	var lock int
	if err := tx.QueryRowContext(ctx, `SELECT COALESCE(GET_LOCK(CONCAT('oddspot_rebuild_scores_', ?), 5), 0)`, userID).Scan(&lock); err != nil {
		return err
	}
	defer func() { _, _ = tx.ExecContext(ctx, `DO RELEASE_LOCK(CONCAT('oddspot_rebuild_scores_', ?))`, userID) }()
	if lock != 1 {
		return nil
	}
	type attemptRow struct {
		id                          string
		levelID                     string
		version                     int
		hints, wrongTaps            int
		durationMS                  int64
		score, points               sql.NullInt64
	}
	pendingRows, err := tx.QueryContext(ctx, `SELECT a.id,a.level_id,a.level_version,a.hints_used,a.duration_ms,a.wrong_taps,a.score,a.points
		FROM level_attempts a WHERE a.user_id=? AND a.state='completed'
		ORDER BY a.level_id,a.level_version,a.completed_at ASC`, userID)
	if err != nil {
		return err
	}
	var pending []attemptRow
	for pendingRows.Next() {
		var r attemptRow
		if err := pendingRows.Scan(&r.id, &r.levelID, &r.version, &r.hints, &r.durationMS, &r.wrongTaps, &r.score, &r.points); err != nil {
			pendingRows.Close()
			return err
		}
		pending = append(pending, r)
	}
	pendingRows.Close()
	type levelKey struct{ levelID string; version int }
	levelBest := map[levelKey]bestScoreRow{}
	userBest := map[string]userBestRow{}
	for _, r := range pending {
		score := int(r.score.Int64)
		points := int(r.points.Int64)
		if !r.score.Valid || !r.points.Valid || (score == 0 && points == 0) {
			levelDifficulty, diffDiffs, scErr := scoreConfig(ctx, tx, r.levelID, r.version)
			if scErr != nil {
				continue
			}
			score = CalculateScore(levelDifficulty, diffDiffs, r.durationMS, r.hints, r.wrongTaps)
			points = CalculatePoints(score, levelDifficulty)
			if _, upErr := tx.ExecContext(ctx, `UPDATE level_attempts SET score=?,points=? WHERE id=?`, score, points, r.id); upErr != nil {
				return upErr
			}
		}
		k := levelKey{levelID: r.levelID, version: r.version}
		prev, exists := levelBest[k]
		better := !exists || score > prev.score || (score == prev.score && (r.hints < prev.hints || (r.hints == prev.hints && (r.wrongTaps < prev.wrongTaps || (r.wrongTaps == prev.wrongTaps && r.durationMS < prev.durationMS)))))
		if better {
			levelBest[k] = bestScoreRow{score: score, points: points, hints: r.hints, wrongTaps: r.wrongTaps, durationMS: r.durationMS, attemptID: r.id}
		}
		up, exists := userBest[r.levelID]
		uBetter := !exists || points > up.points || (points == up.points && (score > up.score || (score == up.score && (r.hints < up.hints || (r.hints == up.hints && (r.wrongTaps < up.wrongTaps || (r.wrongTaps == up.wrongTaps && r.durationMS < up.durationMS)))))))
		if uBetter {
			userBest[r.levelID] = userBestRow{levelID: r.levelID, version: r.version, score: score, points: points, hints: r.hints, wrongTaps: r.wrongTaps, durationMS: r.durationMS, attemptID: r.id}
		}
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM level_best_scores WHERE user_id=?`, userID); err != nil {
		return err
	}
	for k, v := range levelBest {
		if _, err := tx.ExecContext(ctx, `INSERT INTO level_best_scores(user_id,level_id,level_version,attempt_id,score,points,duration_ms,hints_used,wrong_taps) VALUES(?,?,?,?,?,?,?,?,?)`, userID, k.levelID, k.version, v.attemptID, v.score, v.points, v.durationMS, v.hints, v.wrongTaps); err != nil {
			return err
		}
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM user_level_best_scores WHERE user_id=?`, userID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM user_score_totals WHERE user_id=?`, userID); err != nil {
		return err
	}
	totalPoints := 0
	totalScoreSum := 0
	completedLevels := 0
	for _, v := range userBest {
		if _, err := tx.ExecContext(ctx, `INSERT INTO user_level_best_scores(user_id,level_id,level_version,attempt_id,score,points,duration_ms,hints_used,wrong_taps) VALUES(?,?,?,?,?,?,?,?,?)`, userID, v.levelID, v.version, v.attemptID, v.score, v.points, v.durationMS, v.hints, v.wrongTaps); err != nil {
			return err
		}
		totalPoints += v.points
		totalScoreSum += v.score
		completedLevels++
	}
	if completedLevels > 0 {
		if _, err := tx.ExecContext(ctx, `INSERT INTO user_score_totals(user_id,total_points,completed_levels,score_sum,updated_at) VALUES(?,?,?,?,UTC_TIMESTAMP(3))`, userID, totalPoints, completedLevels, totalScoreSum); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *MySQLService) RebuildScoresFor(ctx context.Context, userID string) error {
	return s.rebuildUserScores(ctx, userID)
}

func (s *MySQLService) RebuildAllScores(ctx context.Context) (int, int, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT DISTINCT user_id FROM level_attempts WHERE state='completed' ORDER BY user_id`)
	if err != nil {
		return 0, 0, fmt.Errorf("enumerate users: %w", err)
	}
	defer rows.Close()
	users := []string{}
	for rows.Next() {
		var u string
		if err := rows.Scan(&u); err != nil {
			continue
		}
		users = append(users, u)
	}
	if err := rows.Close(); err != nil {
	}
	rebuilt, failed := 0, 0
	for _, uid := range users {
		if ctx.Err() != nil {
			break
		}
		if err := s.rebuildUserScores(ctx, uid); err != nil {
			failed++
			continue
		}
		rebuilt++
	}
	return rebuilt, failed, nil
}

func (s *MySQLService) ListUserScoreSummaries(ctx context.Context, limit int) ([]UserScoreSummary, error) {
	if limit <= 0 {
		limit = 100
	}
	rows, err := s.db.QueryContext(ctx, `SELECT user_id,total_points,completed_levels,score_sum,
		DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s.%fZ') AS updated_at
		FROM user_score_totals ORDER BY total_points DESC, completed_levels DESC, updated_at ASC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []UserScoreSummary{}
	for rows.Next() {
		var r UserScoreSummary
		if err := rows.Scan(&r.UserID, &r.TotalPoints, &r.CompletedLevels, &r.ScoreSum, &r.UpdatedAt); err != nil {
			continue
		}
		out = append(out, r)
	}
	return out, nil
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
	err := tx.QueryRowContext(ctx, `SELECT a.state,a.hints_used,a.duration_ms,a.wrong_taps,a.score,a.points,
	  CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='image_puzzle' AND a.state='completed'
	    THEN (COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.rows') AS UNSIGNED),0)*COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.cols') AS UNSIGNED),0))
	    ELSE (SELECT COUNT(*) FROM attempt_differences f WHERE f.attempt_id=a.id) END,
	  CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(lv.runtime_json,'$.mode'))='image_puzzle'
	    THEN (COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.rows') AS UNSIGNED),0)*COALESCE(CAST(JSON_EXTRACT(lv.runtime_json,'$.puzzle.cols') AS UNSIGNED),0))
	    ELSE (SELECT COUNT(*) FROM level_differences d WHERE d.level_id=a.level_id AND d.level_version=a.level_version) END
	  FROM level_attempts a JOIN level_versions lv ON lv.level_id=a.level_id AND lv.version=a.level_version WHERE a.id=?`, attemptID).Scan(&r.State, &r.HintsUsed, &r.DurationMS, &r.WrongTaps, &r.Score, &r.Points, &r.FoundCount, &r.TotalCount)
	if err == nil && r.State == "completed" {
		_ = tx.QueryRowContext(ctx, `SELECT score FROM level_best_scores WHERE attempt_id=?`, attemptID).Scan(&r.BestScore)
		if r.BestScore == 0 {
			_ = tx.QueryRowContext(ctx, `SELECT MAX(score) FROM level_best_scores b JOIN level_attempts a ON a.user_id=b.user_id AND a.level_id=b.level_id AND a.level_version=b.level_version WHERE a.id=?`, attemptID).Scan(&r.BestScore)
		}
	}
	return r, err
}

func scoreConfig(ctx context.Context, tx *sql.Tx, levelID string, version int) (int, []int, error) {
	var difficulty int
	if err := tx.QueryRowContext(ctx, `SELECT difficulty FROM level_versions WHERE level_id=? AND version=?`, levelID, version).Scan(&difficulty); err != nil {
		return 0, nil, err
	}
	rows, err := tx.QueryContext(ctx, `SELECT difficulty FROM level_differences WHERE level_id=? AND level_version=? ORDER BY diff_key`, levelID, version)
	if err != nil {
		return 0, nil, err
	}
	defer rows.Close()
	values := []int{}
	for rows.Next() {
		var value int
		if err := rows.Scan(&value); err != nil {
			return 0, nil, err
		}
		values = append(values, value)
	}
	return difficulty, values, rows.Err()
}

func upsertBestScore(ctx context.Context, tx *sql.Tx, userID, levelID string, version int, attemptID string, score, points int, durationMS int64, hintsUsed, wrongTaps int) error {
	var oldScore, oldHints, oldWrongTaps int
	var oldDuration int64
	err := tx.QueryRowContext(ctx, `SELECT score,hints_used,wrong_taps,duration_ms FROM level_best_scores WHERE user_id=? AND level_id=? AND level_version=? FOR UPDATE`, userID, levelID, version).Scan(&oldScore, &oldHints, &oldWrongTaps, &oldDuration)
	if errors.Is(err, sql.ErrNoRows) {
		_, err = tx.ExecContext(ctx, `INSERT INTO level_best_scores(user_id,level_id,level_version,attempt_id,score,points,duration_ms,hints_used,wrong_taps) VALUES(?,?,?,?,?,?,?,?,?)`, userID, levelID, version, attemptID, score, points, durationMS, hintsUsed, wrongTaps)
		return err
	}
	if err != nil {
		return err
	}
	better := score > oldScore || (score == oldScore && (hintsUsed < oldHints || (hintsUsed == oldHints && (wrongTaps < oldWrongTaps || (wrongTaps == oldWrongTaps && durationMS < oldDuration)))))
	if !better {
		return nil
	}
	_, err = tx.ExecContext(ctx, `UPDATE level_best_scores SET attempt_id=?,score=?,points=?,duration_ms=?,hints_used=?,wrong_taps=?,achieved_at=UTC_TIMESTAMP(3) WHERE user_id=? AND level_id=? AND level_version=?`, attemptID, score, points, durationMS, hintsUsed, wrongTaps, userID, levelID, version)
	return err
}

func upsertLifetimeScore(ctx context.Context, tx *sql.Tx, userID, levelID string, version int, attemptID string, score, points int, durationMS int64, hintsUsed, wrongTaps int) error {
	var oldScore, oldPoints, oldHints, oldWrongTaps int
	var oldDuration int64
	err := tx.QueryRowContext(ctx, `SELECT score,points,hints_used,wrong_taps,duration_ms FROM user_level_best_scores WHERE user_id=? AND level_id=? FOR UPDATE`, userID, levelID).Scan(&oldScore, &oldPoints, &oldHints, &oldWrongTaps, &oldDuration)
	if errors.Is(err, sql.ErrNoRows) {
		if _, err = tx.ExecContext(ctx, `INSERT INTO user_level_best_scores(user_id,level_id,level_version,attempt_id,score,points,duration_ms,hints_used,wrong_taps) VALUES(?,?,?,?,?,?,?,?,?)`, userID, levelID, version, attemptID, score, points, durationMS, hintsUsed, wrongTaps); err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, `INSERT INTO user_score_totals(user_id,total_points,completed_levels,score_sum,updated_at) VALUES(?,?,1,?,UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE total_points=total_points+VALUES(total_points),completed_levels=completed_levels+1,score_sum=score_sum+VALUES(score_sum),updated_at=UTC_TIMESTAMP(3)`, userID, points, score)
		return err
	}
	if err != nil {
		return err
	}
	better := points > oldPoints || (points == oldPoints && (score > oldScore || (score == oldScore && (hintsUsed < oldHints || (hintsUsed == oldHints && (wrongTaps < oldWrongTaps || (wrongTaps == oldWrongTaps && durationMS < oldDuration)))))))
	if !better {
		return nil
	}
	if _, err = tx.ExecContext(ctx, `UPDATE user_level_best_scores SET level_version=?,attempt_id=?,score=?,points=?,duration_ms=?,hints_used=?,wrong_taps=?,achieved_at=UTC_TIMESTAMP(3) WHERE user_id=? AND level_id=?`, version, attemptID, score, points, durationMS, hintsUsed, wrongTaps, userID, levelID); err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `UPDATE user_score_totals SET total_points=total_points+?-?,score_sum=score_sum+?-?,updated_at=UTC_TIMESTAMP(3) WHERE user_id=?`, points, oldPoints, score, oldScore, userID)
	return err
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
