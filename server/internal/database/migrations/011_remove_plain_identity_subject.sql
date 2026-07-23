DROP INDEX uq_identity_provider_subject ON user_identities;
ALTER TABLE user_identities DROP COLUMN provider_subject;
