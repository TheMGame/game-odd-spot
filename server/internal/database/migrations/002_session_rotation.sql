ALTER TABLE user_sessions
  ADD COLUMN rotated_from_id VARCHAR(64) NULL AFTER revoked_at,
  ADD INDEX idx_session_rotated_from (rotated_from_id),
  ADD CONSTRAINT fk_session_rotated_from FOREIGN KEY (rotated_from_id) REFERENCES user_sessions(id);
