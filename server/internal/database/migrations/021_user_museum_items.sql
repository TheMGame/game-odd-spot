CREATE TABLE IF NOT EXISTS user_museum_items (
  user_id VARCHAR(64) NOT NULL,
  item_id VARCHAR(128) NOT NULL,
  source_type VARCHAR(32) NOT NULL,
  source_id VARCHAR(128) NOT NULL DEFAULT '',
  acquired_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, item_id),
  INDEX idx_user_museum_acquired (user_id, acquired_at DESC),
  CONSTRAINT fk_user_museum_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
