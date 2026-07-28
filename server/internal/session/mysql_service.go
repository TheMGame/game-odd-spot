package session

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

type MySQLService struct {
	db      *sql.DB
	hmacKey []byte
	now     func() time.Time
}

func NewMySQLService(db *sql.DB, hmacKey string) *MySQLService {
	return &MySQLService{db: db, hmacKey: []byte(hmacKey), now: time.Now}
}

func (s *MySQLService) CreateOrRestore(ctx context.Context, request CreateRequest) (Session, error) {
	identityHash := s.identityHash(request.InstallationID)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Session{}, fmt.Errorf("begin identity transaction: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var userID string
	err = tx.QueryRowContext(ctx,
		"SELECT user_id FROM user_identities WHERE provider = 'installation' AND provider_subject_hash = ? FOR UPDATE",
		identityHash,
	).Scan(&userID)
	if errors.Is(err, sql.ErrNoRows) {
		userID, err = prefixedToken("usr_", 18)
		if err != nil {
			return Session{}, err
		}
		if _, err = tx.ExecContext(ctx,
			"INSERT INTO users(id, market_id, locale) VALUES (?, ?, ?)", userID, request.Market, request.Locale,
		); err != nil {
			return Session{}, fmt.Errorf("insert anonymous user: %w", err)
		}
		if _, err = tx.ExecContext(ctx,
			"INSERT INTO user_identities(user_id, provider, provider_subject_hash) VALUES (?, 'installation', ?)", userID, identityHash,
		); err != nil {
			return Session{}, fmt.Errorf("insert installation identity: %w", err)
		}
	} else if err != nil {
		return Session{}, fmt.Errorf("find installation identity: %w", err)
	}

	created, err := newSessionTokens()
	if err != nil {
		return Session{}, err
	}
	sessionID, err := prefixedToken("ses_", 18)
	if err != nil {
		return Session{}, err
	}
	now := s.now().UTC()
	if _, err = tx.ExecContext(ctx, `INSERT INTO user_sessions(
      id, user_id, access_token_hash, refresh_token_hash, access_expires_at, refresh_expires_at
    ) VALUES (?, ?, ?, ?, ?, ?)`,
		sessionID, userID, tokenHash(created.AccessToken), tokenHash(created.RefreshToken), now.Add(15*time.Minute), now.Add(30*24*time.Hour),
	); err != nil {
		return Session{}, fmt.Errorf("insert user session: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return Session{}, fmt.Errorf("commit identity transaction: %w", err)
	}
	created.UserID = userID
	return created, nil
}

func (s *MySQLService) Authenticate(ctx context.Context, accessToken string) (string, bool) {
	if accessToken == "" {
		return "", false
	}
	var userID string
	err := s.db.QueryRowContext(ctx, `SELECT user_id FROM user_sessions
      WHERE access_token_hash = ? AND revoked_at IS NULL AND access_expires_at > UTC_TIMESTAMP(3)`, tokenHash(accessToken)).Scan(&userID)
	if err != nil {
		return "", false
	}
	return userID, true
}

func (s *MySQLService) Refresh(ctx context.Context, refreshToken string) (Session, error) {
	if refreshToken == "" {
		return Session{}, ErrInvalidRefreshToken
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Session{}, fmt.Errorf("begin refresh transaction: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var oldSessionID, userID string
	err = tx.QueryRowContext(ctx, `SELECT id, user_id FROM user_sessions
      WHERE refresh_token_hash = ? AND revoked_at IS NULL AND refresh_expires_at > UTC_TIMESTAMP(3)
      FOR UPDATE`, tokenHash(refreshToken)).Scan(&oldSessionID, &userID)
	if errors.Is(err, sql.ErrNoRows) {
		return Session{}, ErrInvalidRefreshToken
	}
	if err != nil {
		return Session{}, fmt.Errorf("select refresh session: %w", err)
	}
	if _, err := tx.ExecContext(ctx, "UPDATE user_sessions SET revoked_at = UTC_TIMESTAMP(3) WHERE id = ?", oldSessionID); err != nil {
		return Session{}, fmt.Errorf("revoke rotated session: %w", err)
	}
	created, err := newSessionTokens()
	if err != nil {
		return Session{}, err
	}
	newSessionID, err := prefixedToken("ses_", 18)
	if err != nil {
		return Session{}, err
	}
	now := s.now().UTC()
	if _, err := tx.ExecContext(ctx, `INSERT INTO user_sessions(
      id, user_id, access_token_hash, refresh_token_hash, access_expires_at, refresh_expires_at, rotated_from_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?)`, newSessionID, userID, tokenHash(created.AccessToken), tokenHash(created.RefreshToken),
		now.Add(15*time.Minute), now.Add(30*24*time.Hour), oldSessionID); err != nil {
		return Session{}, fmt.Errorf("insert rotated session: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return Session{}, fmt.Errorf("commit refresh transaction: %w", err)
	}
	created.UserID = userID
	return created, nil
}

func (s *MySQLService) Revoke(ctx context.Context, refreshToken string) error {
	if refreshToken == "" {
		return nil
	}
	_, err := s.db.ExecContext(ctx, `UPDATE user_sessions SET revoked_at = UTC_TIMESTAMP(3)
      WHERE refresh_token_hash = ? AND revoked_at IS NULL`, tokenHash(refreshToken))
	if err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}

func (s *MySQLService) Issue(ctx context.Context, userID string) (Session, error) {
	created, err := newSessionTokens()
	if err != nil {
		return Session{}, err
	}
	id, err := prefixedToken("ses_", 18)
	if err != nil {
		return Session{}, err
	}
	now := s.now().UTC()
	_, err = s.db.ExecContext(ctx, `INSERT INTO user_sessions(id,user_id,access_token_hash,refresh_token_hash,access_expires_at,refresh_expires_at) VALUES(?,?,?,?,?,?)`, id, userID, tokenHash(created.AccessToken), tokenHash(created.RefreshToken), now.Add(15*time.Minute), now.Add(30*24*time.Hour))
	if err != nil {
		return Session{}, fmt.Errorf("issue user session: %w", err)
	}
	created.UserID = userID
	return created, nil
}

func (s *MySQLService) IssueExternal(ctx context.Context, userID, market, locale string) (Session, error) {
	if err := s.EnsureExternalUser(ctx, userID, market, locale); err != nil {
		return Session{}, err
	}
	if err := s.UpdateLocale(ctx, userID, locale); err != nil {
		return Session{}, err
	}
	return s.Issue(ctx, userID)
}

func (s *MySQLService) EnsureExternalUser(ctx context.Context, userID, market, locale string) error {
	_, err := s.db.ExecContext(ctx, `INSERT INTO users(id,market_id,locale) VALUES(?,?,?)
		ON DUPLICATE KEY UPDATE id=VALUES(id)`, userID, market, locale)
	if err != nil {
		return fmt.Errorf("upsert external user: %w", err)
	}
	return nil
}
func (s *MySQLService) Profile(ctx context.Context, userID string) (string, string, error) {
	var market, locale string
	err := s.db.QueryRowContext(ctx, `SELECT market_id,locale FROM users WHERE id=?`, userID).Scan(&market, &locale)
	return market, locale, err
}

func (s *MySQLService) UpdateLocale(ctx context.Context, userID, locale string) error {
	result, err := s.db.ExecContext(ctx, `UPDATE users SET locale=? WHERE id=?`, normalizeLocale(locale), userID)
	if err != nil {
		return fmt.Errorf("update user locale: %w", err)
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("read updated user count: %w", err)
	}
	if affected == 0 {
		return ErrUserNotFound
	}
	return nil
}

func (s *MySQLService) identityHash(installationID string) []byte {
	mac := hmac.New(sha256.New, s.hmacKey)
	_, _ = mac.Write([]byte(installationID))
	return mac.Sum(nil)
}

func newSessionTokens() (Session, error) {
	access, err := randomToken(32)
	if err != nil {
		return Session{}, fmt.Errorf("generate access token: %w", err)
	}
	refresh, err := randomToken(48)
	if err != nil {
		return Session{}, fmt.Errorf("generate refresh token: %w", err)
	}
	return Session{AccessToken: access, RefreshToken: refresh}, nil
}

func prefixedToken(prefix string, byteCount int) (string, error) {
	token, err := randomToken(byteCount)
	if err != nil {
		return "", fmt.Errorf("generate identifier: %w", err)
	}
	return prefix + token, nil
}

func tokenHash(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}
