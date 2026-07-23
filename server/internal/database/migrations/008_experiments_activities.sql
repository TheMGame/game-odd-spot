CREATE TABLE IF NOT EXISTS experiment_definitions (
  experiment_key VARCHAR(64) PRIMARY KEY,
  variants_json JSON NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  starts_at TIMESTAMP(3) NOT NULL,
  ends_at TIMESTAMP(3) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO experiment_definitions(experiment_key,variants_json,enabled,starts_at,ends_at)
VALUES('home_layout',JSON_ARRAY('control','compact'),true,'2026-01-01 00:00:00','2030-01-01 00:00:00');

INSERT IGNORE INTO activities(id,market_id,name,config_json,starts_at,ends_at,enabled)
VALUES('welcome_2026','global','Welcome Challenge',JSON_OBJECT('theme','cozy_home','bonus_hints',1),'2026-01-01 00:00:00','2030-01-01 00:00:00',true);
