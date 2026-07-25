CREATE TABLE IF NOT EXISTS content_series (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(128) NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  mode VARCHAR(32) NOT NULL,
  cover_url VARCHAR(1024) NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  INDEX idx_content_series_enabled (enabled,sort_order,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS content_series_levels (
  series_id VARCHAR(64) NOT NULL,
  level_id VARCHAR(64) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (series_id,level_id),
  INDEX idx_series_level_order (series_id,enabled,sort_order,level_id),
  CONSTRAINT fk_series_level_series FOREIGN KEY (series_id) REFERENCES content_series(id),
  CONSTRAINT fk_series_level_level FOREIGN KEY (level_id) REFERENCES levels(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
