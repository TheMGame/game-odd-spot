CREATE TABLE IF NOT EXISTS museum_configs (
  id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  config_json JSON NOT NULL,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO museum_configs(id, config_json) VALUES(1, JSON_OBJECT(
  'title', '大侦探博物馆',
  'subtitle', '珍藏每一段被还原的历史',
  'items', JSON_ARRAY(JSON_OBJECT(
    'id', 'scroll_luoshen', 'name', '洛神赋卷', 'description', '完成《洛神赋》章节获得',
    'group', '神韵华章', 'image_url', '/content/scroll_luoshen.png', 'sort_order', 10,
    'enabled', true, 'unlock_type', 'always', 'unlock_value', ''
  ))
)) ON DUPLICATE KEY UPDATE id=id;
