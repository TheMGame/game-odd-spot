INSERT INTO content_series(id,title,description,mode,cover_url,sort_order,enabled)
VALUES('daily_task','每日挑战','每天发布一道更有挑战性的题目','find_anachronism','',2147483647,TRUE)
ON DUPLICATE KEY UPDATE title=VALUES(title),description=VALUES(description),
sort_order=2147483647,enabled=TRUE;
