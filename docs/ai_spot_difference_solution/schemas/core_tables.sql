-- MySQL 8.0 reference schema. Production changes must be delivered as versioned migrations.
CREATE TABLE markets (
  id VARCHAR(32) PRIMARY KEY,
  default_locale VARCHAR(16) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);

CREATE TABLE users (
  id VARCHAR(64) PRIMARY KEY,
  market_id VARCHAR(32) NOT NULL,
  locale VARCHAR(16) NOT NULL,
  content_preference VARCHAR(32) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_user_market FOREIGN KEY (market_id) REFERENCES markets(id)
);

CREATE TABLE user_identities (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id VARCHAR(64) NOT NULL,
  provider VARCHAR(24) NOT NULL,
  provider_subject_hash BINARY(32) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_identity_provider_subject (provider, provider_subject_hash),
  INDEX idx_identity_user (user_id),
  CONSTRAINT fk_identity_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE levels (
  id VARCHAR(64) PRIMARY KEY,
  mode VARCHAR(32) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);

CREATE TABLE generation_batches (
  id VARCHAR(64) PRIMARY KEY,
  model VARCHAR(128) NOT NULL,
  prompt_version VARCHAR(64) NOT NULL,
  parameters_json JSON NOT NULL,
  estimated_cost DECIMAL(12,4) NOT NULL DEFAULT 0,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);

CREATE TABLE level_versions (
  level_id VARCHAR(64) NOT NULL,
  version INT NOT NULL,
  schema_version INT NOT NULL,
  status VARCHAR(32) NOT NULL,
  runtime_json JSON NOT NULL,
  difficulty TINYINT NOT NULL,
  quality_score DECIMAL(5,2) NOT NULL DEFAULT 0,
  generation_batch_id VARCHAR(64) NULL,
  published_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (level_id, version),
  INDEX idx_version_status_quality (status, quality_score),
  CONSTRAINT fk_version_level FOREIGN KEY (level_id) REFERENCES levels(id),
  CONSTRAINT fk_version_batch FOREIGN KEY (generation_batch_id) REFERENCES generation_batches(id),
  CONSTRAINT chk_version_status CHECK (status IN ('draft','generating','generated','auto_review_failed','pending_review','approved','staging','published','disabled'))
);

CREATE TABLE level_differences (
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  diff_key VARCHAR(32) NOT NULL,
  shape VARCHAR(16) NOT NULL,
  geometry_json JSON NOT NULL,
  operation VARCHAR(16) NOT NULL,
  difficulty TINYINT NOT NULL,
  mask_asset_id VARCHAR(128) NULL,
  PRIMARY KEY (level_id, level_version, diff_key),
  CONSTRAINT fk_diff_version FOREIGN KEY (level_id, level_version) REFERENCES level_versions(level_id, version)
);

CREATE TABLE level_tags (
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  tag_type VARCHAR(32) NOT NULL,
  tag_value VARCHAR(64) NOT NULL,
  weight DECIMAL(5,2) NOT NULL DEFAULT 1,
  PRIMARY KEY (level_id, level_version, tag_type, tag_value),
  INDEX idx_tag_lookup (tag_type, tag_value),
  CONSTRAINT fk_tag_version FOREIGN KEY (level_id, level_version) REFERENCES level_versions(level_id, version)
);

CREATE TABLE level_attempts (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  state VARCHAR(16) NOT NULL,
  hints_used INT NOT NULL DEFAULT 0,
  duration_ms BIGINT NOT NULL DEFAULT 0,
  started_at TIMESTAMP(3) NOT NULL,
  completed_at TIMESTAMP(3) NULL,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  INDEX idx_attempt_user_level (user_id, level_id),
  CONSTRAINT fk_attempt_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_attempt_version FOREIGN KEY (level_id, level_version) REFERENCES level_versions(level_id, version),
  CONSTRAINT chk_attempt_state CHECK (state IN ('in_progress','completed'))
);

CREATE TABLE attempt_differences (
  attempt_id VARCHAR(64) NOT NULL,
  diff_key VARCHAR(32) NOT NULL,
  found_at_ms BIGINT NOT NULL,
  found_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (attempt_id, diff_key),
  CONSTRAINT fk_found_attempt FOREIGN KEY (attempt_id) REFERENCES level_attempts(id)
);

CREATE TABLE reward_ledger (
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
);

CREATE TABLE idempotency_records (
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
);

CREATE TABLE purchase_transactions (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  platform VARCHAR(24) NOT NULL,
  product_id VARCHAR(128) NOT NULL,
  transaction_id VARCHAR(256) NOT NULL,
  original_transaction_id VARCHAR(256) NULL,
  status VARCHAR(24) NOT NULL,
  purchased_at TIMESTAMP(3) NULL,
  raw_reference VARCHAR(512) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_purchase_transaction (platform, transaction_id),
  INDEX idx_purchase_user (user_id, created_at),
  CONSTRAINT fk_purchase_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE purchase_entitlements (
  user_id VARCHAR(64) NOT NULL,
  entitlement_key VARCHAR(128) NOT NULL,
  source_transaction_id VARCHAR(64) NOT NULL,
  status VARCHAR(16) NOT NULL,
  expires_at TIMESTAMP(3) NULL,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, entitlement_key),
  CONSTRAINT fk_entitlement_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_entitlement_transaction FOREIGN KEY (source_transaction_id) REFERENCES purchase_transactions(id)
);

CREATE TABLE remote_config_versions (
  market_id VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL,
  status VARCHAR(16) NOT NULL,
  config_json JSON NOT NULL,
  config_sha256 BINARY(32) NOT NULL,
  rollout_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
  published_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (market_id, version),
  CONSTRAINT fk_config_market FOREIGN KEY (market_id) REFERENCES markets(id)
);

CREATE TABLE review_records (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  reviewer_id VARCHAR(64) NOT NULL,
  from_status VARCHAR(32) NOT NULL,
  to_status VARCHAR(32) NOT NULL,
  reason TEXT NULL,
  result_json JSON NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_review_version (level_id, level_version, created_at),
  CONSTRAINT fk_review_version FOREIGN KEY (level_id, level_version) REFERENCES level_versions(level_id, version)
);

CREATE TABLE event_dedup (
  event_id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  occurred_at TIMESTAMP(3) NOT NULL,
  received_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_event_received (received_at)
);
