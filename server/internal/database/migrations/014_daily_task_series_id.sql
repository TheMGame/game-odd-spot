INSERT INTO content_series(id,title,description,mode,cover_url,sort_order,enabled)
VALUES('daily_task','每日挑战','每天发布一道更有挑战性的题目','find_anachronism','',2147483647,TRUE)
ON DUPLICATE KEY UPDATE sort_order=2147483647,enabled=TRUE;

UPDATE content_series
SET enabled=FALSE
WHERE id='daily_challenge'
  AND NOT EXISTS (
    SELECT 1 FROM content_series_levels
    WHERE content_series_levels.series_id='daily_challenge'
  );
