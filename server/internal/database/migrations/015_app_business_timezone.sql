UPDATE remote_config_versions
SET config_json=JSON_SET(
  config_json,
  '$.app_timezone',
  COALESCE(JSON_UNQUOTE(JSON_EXTRACT(config_json,'$.app_timezone')),'Asia/Shanghai')
)
WHERE JSON_EXTRACT(config_json,'$.app_timezone') IS NULL;
