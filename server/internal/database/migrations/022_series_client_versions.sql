ALTER TABLE content_series
  ADD COLUMN min_web_version VARCHAR(32) NOT NULL DEFAULT '',
  ADD COLUMN min_wechat_version VARCHAR(32) NOT NULL DEFAULT '';
