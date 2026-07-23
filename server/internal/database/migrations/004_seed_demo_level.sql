INSERT IGNORE INTO levels(id, mode) VALUES ('global_demo_001', 'spot_difference');

INSERT IGNORE INTO level_versions(level_id, version, schema_version, status, runtime_json, difficulty, quality_score, published_at)
VALUES (
  'global_demo_001', 1, 1, 'published',
  JSON_OBJECT(
    'schema_version', 1,
    'level_id', 'global_demo_001',
    'level_version', 1,
    'mode', 'spot_difference',
    'assets', JSON_OBJECT(
      'base', JSON_OBJECT('asset_id','base_demo_001','url','https://cdn.example.com/assets/base_demo_001.webp','sha256',REPEAT('a',64),'bytes',120000,'content_type','image/webp'),
      'target', JSON_OBJECT('asset_id','target_demo_001','url','https://cdn.example.com/assets/target_demo_001.webp','sha256',REPEAT('b',64),'bytes',121000,'content_type','image/webp'),
      'width',1536,'height',1024
    ),
    'differences', JSON_ARRAY(
      JSON_OBJECT('id','d1','shape','circle','x',0.20,'y',0.30,'radius',0.030,'difficulty',1,'operation','remove'),
      JSON_OBJECT('id','d2','shape','circle','x',0.50,'y',0.40,'radius',0.025,'difficulty',2,'operation','color'),
      JSON_OBJECT('id','d3','shape','circle','x',0.70,'y',0.60,'radius',0.020,'difficulty',3,'operation','replace'),
      JSON_OBJECT('id','d4','shape','polygon','points',JSON_ARRAY(JSON_OBJECT('x',0.30,'y',0.70),JSON_OBJECT('x',0.35,'y',0.68),JSON_OBJECT('x',0.34,'y',0.75)),'difficulty',3,'operation','shape'),
      JSON_OBJECT('id','d5','shape','circle','x',0.82,'y',0.22,'radius',0.018,'difficulty',4,'operation','direction')
    ),
    'tags',JSON_OBJECT('regions',JSON_ARRAY('global'),'themes',JSON_ARRAY('cozy_home'),'styles',JSON_ARRAY('cute'),'scenes',JSON_ARRAY('living_room'),'risk',JSON_ARRAY()),
    'difficulty',JSON_OBJECT('total',2,'object_size',2,'color_similarity',2,'visual_density',3,'edge_distance',1,'semantic_obviousness',2)
  ),
  2, 95.00, UTC_TIMESTAMP(3)
);

INSERT IGNORE INTO level_differences(level_id, level_version, diff_key, difficulty) VALUES
  ('global_demo_001',1,'d1',1),
  ('global_demo_001',1,'d2',2),
  ('global_demo_001',1,'d3',3),
  ('global_demo_001',1,'d4',3),
  ('global_demo_001',1,'d5',4);
