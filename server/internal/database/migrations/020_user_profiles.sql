-- 用户资料字段：展示名 + 头像 + updated_at
-- 迁移序号: 020 (在 019_leaderboards.sql 之后)
-- 目标:
--   1. users 表新增 display_name/avatar_url/updated_at 三列（如不存在）
--   2. user_score_totals 加 (total_points,updated_at) 复合索引（如不存在）

-- 1) users 表: 逐个 ALTER IGNORE 加列（MySQL 重复列会报错，用存储过程判断）
SET @ddl = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='display_name') = 0,
  'ALTER TABLE users ADD COLUMN display_name VARCHAR(64) NULL COMMENT ''用户展示名（微信昵称/用户名）''',
  'SELECT 1'
);
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='avatar_url') = 0,
  'ALTER TABLE users ADD COLUMN avatar_url VARCHAR(512) NULL COMMENT ''用户头像 URL''',
  'SELECT 1'
);
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='updated_at') = 0,
  'ALTER TABLE users ADD COLUMN updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)',
  'SELECT 1'
);
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) user_score_totals 加索引
SET @ddl = IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='user_score_totals' AND INDEX_NAME='idx_totals_points_updated') = 0,
  'CREATE INDEX idx_totals_points_updated ON user_score_totals (total_points DESC, updated_at ASC)',
  'SELECT 1'
);
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
