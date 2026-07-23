CREATE TABLE IF NOT EXISTS analytics_events (
  event_id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  session_id VARCHAR(64) NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  market VARCHAR(32) NOT NULL,
  locale VARCHAR(16) NOT NULL,
  app_version VARCHAR(32) NOT NULL,
  occurred_at TIMESTAMP(3) NOT NULL,
  payload JSON NOT NULL,
  received_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_event_type_time (event_type,occurred_at),
  INDEX idx_event_user_time (user_id,occurred_at),
  CONSTRAINT fk_event_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ad_reward_claims (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  provider VARCHAR(32) NOT NULL,
  provider_proof_hash BINARY(32) NOT NULL,
  reward_type VARCHAR(32) NOT NULL,
  reward_amount BIGINT NOT NULL,
  status VARCHAR(16) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  verified_at TIMESTAMP(3) NULL,
  UNIQUE KEY uk_ad_provider_proof (provider,provider_proof_hash),
  CONSTRAINT fk_ad_claim_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS purchase_transactions (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  platform VARCHAR(24) NOT NULL,
  product_id VARCHAR(128) NOT NULL,
  transaction_id VARCHAR(256) NOT NULL,
  status VARCHAR(24) NOT NULL,
  purchased_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uk_purchase_platform_transaction (platform,transaction_id),
  INDEX idx_purchase_user (user_id,created_at),
  CONSTRAINT fk_purchase_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS purchase_entitlements (
  user_id VARCHAR(64) NOT NULL,
  entitlement_key VARCHAR(128) NOT NULL,
  source_transaction_id VARCHAR(64) NOT NULL,
  status VARCHAR(16) NOT NULL,
  expires_at TIMESTAMP(3) NULL,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id,entitlement_key),
  CONSTRAINT fk_entitlement_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_entitlement_transaction FOREIGN KEY (source_transaction_id) REFERENCES purchase_transactions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS daily_challenges (
  challenge_date DATE NOT NULL,
  market_id VARCHAR(32) NOT NULL,
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  starts_at TIMESTAMP(3) NOT NULL,
  ends_at TIMESTAMP(3) NOT NULL,
  PRIMARY KEY (challenge_date,market_id),
  CONSTRAINT fk_daily_market FOREIGN KEY (market_id) REFERENCES markets(id),
  CONSTRAINT fk_daily_level FOREIGN KEY (level_id,level_version) REFERENCES level_versions(level_id,version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS activities (
  id VARCHAR(64) PRIMARY KEY,
  market_id VARCHAR(32) NOT NULL,
  name VARCHAR(128) NOT NULL,
  config_json JSON NOT NULL,
  starts_at TIMESTAMP(3) NOT NULL,
  ends_at TIMESTAMP(3) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  INDEX idx_activity_market_time (market_id,enabled,starts_at,ends_at),
  CONSTRAINT fk_activity_market FOREIGN KEY (market_id) REFERENCES markets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS experiment_assignments (
  experiment_key VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  variant_key VARCHAR(64) NOT NULL,
  assigned_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (experiment_key,user_id),
  CONSTRAINT fk_experiment_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO daily_challenges(challenge_date,market_id,level_id,level_version,starts_at,ends_at)
VALUES(UTC_DATE(),'global','global_demo_001',1,UTC_DATE(),DATE_ADD(UTC_DATE(),INTERVAL 1 DAY));
