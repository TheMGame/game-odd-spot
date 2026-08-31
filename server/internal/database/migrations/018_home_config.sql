CREATE TABLE IF NOT EXISTS home_configs (
  id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  config_json JSON NOT NULL,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO home_configs(id, config_json) VALUES(1, JSON_OBJECT(
  'brand_title', '错位大侦探',
  'brand_subtitle', 'ODD SPOT DETECTIVE',
  'detective_title', '敏锐侦探',
  'hero_series_id', '',
  'hero_badge', '继续调查',
  'hero_label', '当前调查章节',
  'hero_button', '继续调查',
  'daily_title', '今日案件',
  'daily_description', '完成案件，积累侦探经验',
  'daily_reward', '奖励：EXP +30',
  'daily_target', 3,
  'worlds_title', '案件世界',
  'worlds_link_text', '全部世界',
  'museum_title', '最近获得',
  'museum_link_text', '我的博物馆',
  'logo_url', '/content/home_logo-ce94f91decc4f622.png',
  'header_url', '/content/home_header_texture-a1ae2615a05e529a.png',
  'hero_fallback_url', '/content/home_hero_fallback-1a4c84c9ef47447a.png',
  'collection_placeholder_url', '/content/home_collection_placeholder-5fa977654dff7781.png'
)) ON DUPLICATE KEY UPDATE id=id;
