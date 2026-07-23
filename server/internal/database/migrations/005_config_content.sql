CREATE TABLE IF NOT EXISTS markets (
  id VARCHAR(32) PRIMARY KEY,
  default_locale VARCHAR(16) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO markets(id,default_locale) VALUES
  ('global','en-US'),('cn','zh-CN'),('us','en-US'),('jp','ja-JP');

CREATE TABLE IF NOT EXISTS remote_config_versions (
  market_id VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL,
  status VARCHAR(16) NOT NULL,
  config_json JSON NOT NULL,
  config_sha256 BINARY(32) NOT NULL,
  rollout_percent DECIMAL(5,2) NOT NULL DEFAULT 100,
  published_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (market_id,version),
  INDEX idx_config_published (market_id,status,published_at),
  CONSTRAINT fk_config_market FOREIGN KEY (market_id) REFERENCES markets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS level_tags (
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  tag_type VARCHAR(32) NOT NULL,
  tag_value VARCHAR(64) NOT NULL,
  weight DECIMAL(5,2) NOT NULL DEFAULT 1,
  PRIMARY KEY (level_id,level_version,tag_type,tag_value),
  INDEX idx_tag_lookup (tag_type,tag_value,weight),
  CONSTRAINT fk_tag_level_version FOREIGN KEY (level_id,level_version) REFERENCES level_versions(level_id,version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS review_records (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  reviewer_id VARCHAR(64) NOT NULL,
  from_status VARCHAR(32) NOT NULL,
  to_status VARCHAR(32) NOT NULL,
  reason TEXT NULL,
  result_json JSON NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_review_level (level_id,level_version,created_at),
  CONSTRAINT fk_review_level_version FOREIGN KEY (level_id,level_version) REFERENCES level_versions(level_id,version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO level_tags(level_id,level_version,tag_type,tag_value,weight) VALUES
  ('global_demo_001',1,'region','global',1),
  ('global_demo_001',1,'theme','cozy_home',1),
  ('global_demo_001',1,'style','cute',1);

INSERT IGNORE INTO remote_config_versions(market_id,version,status,config_json,config_sha256,rollout_percent,published_at)
VALUES('global',1,'published',JSON_OBJECT(
  'minimum_app_version','0.1.0','force_upgrade',false,
  'features',JSON_OBJECT('daily_challenge',false,'rewarded_ads',false,'iap',false),
  'monetization',JSON_OBJECT('interstitial_every_levels',5,'free_daily_hints',3),
  'theme_weights',JSON_OBJECT('global',1.0,'cozy_home',1.2)
),UNHEX(SHA2(CAST(JSON_OBJECT(
  'minimum_app_version','0.1.0','force_upgrade',false,
  'features',JSON_OBJECT('daily_challenge',false,'rewarded_ads',false,'iap',false),
  'monetization',JSON_OBJECT('interstitial_every_levels',5,'free_daily_hints',3),
  'theme_weights',JSON_OBJECT('global',1.0,'cozy_home',1.2)
) AS CHAR),256)),100,UTC_TIMESTAMP(3));
