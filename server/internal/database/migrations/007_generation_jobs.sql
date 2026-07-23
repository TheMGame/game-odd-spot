CREATE TABLE IF NOT EXISTS generation_jobs (
  id VARCHAR(64) PRIMARY KEY,
  status VARCHAR(24) NOT NULL,
  market_id VARCHAR(32) NOT NULL,
  prompt_version VARCHAR(64) NOT NULL,
  model VARCHAR(128) NOT NULL,
  input_json JSON NOT NULL,
  result_json JSON NULL,
  attempts INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  error_message TEXT NULL,
  locked_at TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  INDEX idx_generation_queue (status,created_at),
  CONSTRAINT fk_generation_market FOREIGN KEY (market_id) REFERENCES markets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS quality_results (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  generation_job_id VARCHAR(64) NOT NULL,
  passed BOOLEAN NOT NULL,
  score DECIMAL(5,2) NOT NULL,
  checks_json JSON NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_quality_job (generation_job_id,created_at),
  CONSTRAINT fk_quality_job FOREIGN KEY (generation_job_id) REFERENCES generation_jobs(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
