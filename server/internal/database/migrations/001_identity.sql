CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  market_id VARCHAR(32) NOT NULL,
  locale VARCHAR(16) NOT NULL,
  content_preference VARCHAR(32) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_identities (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id VARCHAR(64) NOT NULL,
  provider VARCHAR(24) NOT NULL,
  provider_subject_hash BINARY(32) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_identity_provider_subject (provider, provider_subject_hash),
  INDEX idx_identity_user (user_id),
  CONSTRAINT fk_identity_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_sessions (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  access_token_hash BINARY(32) NOT NULL,
  refresh_token_hash BINARY(32) NOT NULL,
  access_expires_at TIMESTAMP(3) NOT NULL,
  refresh_expires_at TIMESTAMP(3) NOT NULL,
  revoked_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_seen_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_session_access_token (access_token_hash),
  UNIQUE KEY uk_session_refresh_token (refresh_token_hash),
  INDEX idx_session_user (user_id),
  INDEX idx_session_refresh_expiry (refresh_expires_at),
  CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
