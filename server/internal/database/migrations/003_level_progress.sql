CREATE TABLE IF NOT EXISTS levels (
  id VARCHAR(64) PRIMARY KEY,
  mode VARCHAR(32) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS level_versions (
  level_id VARCHAR(64) NOT NULL,
  version INT NOT NULL,
  schema_version INT NOT NULL,
  status VARCHAR(32) NOT NULL,
  runtime_json JSON NOT NULL,
  difficulty TINYINT NOT NULL,
  quality_score DECIMAL(5,2) NOT NULL DEFAULT 0,
  published_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (level_id, version),
  INDEX idx_level_catalog (status, published_at, quality_score),
  CONSTRAINT fk_level_version_level FOREIGN KEY (level_id) REFERENCES levels(id),
  CONSTRAINT chk_level_version_status CHECK (status IN ('draft','generated','auto_review_failed','pending_review','approved','staging','published','disabled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS level_differences (
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  diff_key VARCHAR(32) NOT NULL,
  difficulty TINYINT NOT NULL,
  PRIMARY KEY (level_id, level_version, diff_key),
  CONSTRAINT fk_difference_version FOREIGN KEY (level_id, level_version) REFERENCES level_versions(level_id, version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS level_attempts (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  state VARCHAR(16) NOT NULL,
  hints_used INT NOT NULL DEFAULT 0,
  duration_ms BIGINT NOT NULL DEFAULT 0,
  started_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at TIMESTAMP(3) NULL,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  INDEX idx_attempt_user_level (user_id, level_id, state),
  CONSTRAINT fk_attempt_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_attempt_version FOREIGN KEY (level_id, level_version) REFERENCES level_versions(level_id, version),
  CONSTRAINT chk_attempt_state CHECK (state IN ('in_progress','completed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS attempt_differences (
  attempt_id VARCHAR(64) NOT NULL,
  diff_key VARCHAR(32) NOT NULL,
  found_at_ms BIGINT NOT NULL,
  found_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (attempt_id, diff_key),
  CONSTRAINT fk_attempt_difference_attempt FOREIGN KEY (attempt_id) REFERENCES level_attempts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS reward_ledger (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  asset_type VARCHAR(32) NOT NULL,
  amount BIGINT NOT NULL,
  source_type VARCHAR(32) NOT NULL,
  source_id VARCHAR(128) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_reward_source (user_id, source_type, source_id, asset_type),
  INDEX idx_reward_user_created (user_id, created_at),
  CONSTRAINT fk_reward_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS idempotency_records (
  user_id VARCHAR(64) NOT NULL,
  route VARCHAR(128) NOT NULL,
  idempotency_key VARCHAR(128) NOT NULL,
  request_hash BINARY(32) NOT NULL,
  state VARCHAR(16) NOT NULL,
  response_status SMALLINT NULL,
  response_body JSON NULL,
  expires_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, route, idempotency_key),
  CONSTRAINT fk_idempotency_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
