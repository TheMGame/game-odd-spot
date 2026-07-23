CREATE TABLE IF NOT EXISTS market_country_aliases (
  country_code VARCHAR(3) PRIMARY KEY,
  market_id VARCHAR(32) NOT NULL,
  priority INT NOT NULL DEFAULT 100,
  CONSTRAINT fk_country_market FOREIGN KEY (market_id) REFERENCES markets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO market_country_aliases(country_code,market_id) VALUES
  ('CN','cn'),('CHN','cn'),('US','us'),('USA','us'),('JP','jp'),('JPN','jp');
