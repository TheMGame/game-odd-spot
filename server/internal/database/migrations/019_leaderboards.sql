ALTER TABLE level_attempts
  ADD COLUMN wrong_taps INT NOT NULL DEFAULT 0 AFTER duration_ms,
  ADD COLUMN score TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER wrong_taps,
  ADD COLUMN points SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER score;

CREATE TABLE IF NOT EXISTS level_best_scores (
  user_id VARCHAR(64) NOT NULL,
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  attempt_id VARCHAR(64) NOT NULL,
  score TINYINT UNSIGNED NOT NULL,
  points SMALLINT UNSIGNED NOT NULL,
  duration_ms BIGINT NOT NULL,
  hints_used INT NOT NULL,
  wrong_taps INT NOT NULL,
  achieved_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, level_id, level_version),
  UNIQUE KEY uk_best_attempt (attempt_id),
  INDEX idx_level_leaderboard (level_id, level_version, score DESC, hints_used, wrong_taps, duration_ms),
  INDEX idx_overall_user (user_id, points),
  CONSTRAINT fk_best_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_best_version FOREIGN KEY (level_id, level_version) REFERENCES level_versions(level_id, version),
  CONSTRAINT chk_best_score CHECK (score BETWEEN 40 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_level_best_scores (
  user_id VARCHAR(64) NOT NULL,
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  attempt_id VARCHAR(64) NOT NULL,
  score TINYINT UNSIGNED NOT NULL,
  points SMALLINT UNSIGNED NOT NULL,
  duration_ms BIGINT NOT NULL,
  hints_used INT NOT NULL,
  wrong_taps INT NOT NULL,
  achieved_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, level_id),
  INDEX idx_user_level_points (user_id, points),
  CONSTRAINT fk_user_level_best_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_user_level_best_level FOREIGN KEY (level_id) REFERENCES levels(id),
  CONSTRAINT chk_user_level_best_score CHECK (score BETWEEN 40 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_score_totals (
  user_id VARCHAR(64) PRIMARY KEY,
  total_points BIGINT UNSIGNED NOT NULL DEFAULT 0,
  completed_levels INT UNSIGNED NOT NULL DEFAULT 0,
  score_sum BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  INDEX idx_user_total_rank (total_points DESC, completed_levels DESC, score_sum DESC),
  CONSTRAINT fk_score_total_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
