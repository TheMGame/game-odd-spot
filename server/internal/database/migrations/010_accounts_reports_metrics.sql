ALTER TABLE user_identities ADD COLUMN provider_subject VARCHAR(191) NULL AFTER provider;
CREATE UNIQUE INDEX uq_identity_provider_subject ON user_identities(provider, provider_subject);

CREATE TABLE IF NOT EXISTS content_reports (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  level_id VARCHAR(64) NOT NULL,
  category VARCHAR(32) NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  status ENUM('open','reviewing','resolved','dismissed') NOT NULL DEFAULT 'open',
  resolution_note VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_report_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_report_level FOREIGN KEY (level_id) REFERENCES levels(id),
  INDEX idx_reports_status_created(status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
