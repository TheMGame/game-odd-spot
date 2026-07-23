package account

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"strings"
)

var ErrInvalidProof = errors.New("invalid account proof")
var ErrAlreadyBound = errors.New("account already bound")

type Result struct {
	Provider string `json:"provider"`
	Subject  string `json:"subject"`
}

type Service interface {
	Bind(context.Context, string, string, string) (Result, error)
	Resolve(context.Context, string, string) (string, error)
}

type MemoryService struct {
	development bool
	users       map[string]string
}

func NewMemoryService(development bool) *MemoryService {
	return &MemoryService{development: development, users: map[string]string{}}
}
func subject(development bool, provider, proof string) (string, error) {
	if !development || provider != "test" || !strings.HasPrefix(proof, "test_account_") || len(proof) < 14 {
		return "", ErrInvalidProof
	}
	return strings.TrimPrefix(proof, "test_account_"), nil
}
func (s *MemoryService) Bind(_ context.Context, user, provider, proof string) (Result, error) {
	sub, e := subject(s.development, provider, proof)
	if e != nil {
		return Result{}, e
	}
	key := provider + ":" + sub
	if old, ok := s.users[key]; ok && old != user {
		return Result{}, ErrAlreadyBound
	}
	s.users[key] = user
	return Result{provider, sub}, nil
}
func (s *MemoryService) Resolve(_ context.Context, provider, proof string) (string, error) {
	sub, e := subject(s.development, provider, proof)
	if e != nil {
		return "", e
	}
	u, ok := s.users[provider+":"+sub]
	if !ok {
		return "", ErrInvalidProof
	}
	return u, nil
}

type MySQLService struct {
	db          *sql.DB
	development bool
}

func NewMySQLService(db *sql.DB, development bool) *MySQLService {
	return &MySQLService{db: db, development: development}
}
func (s *MySQLService) Bind(ctx context.Context, user, provider, proof string) (Result, error) {
	sub, e := subject(s.development, provider, proof)
	if e != nil {
		return Result{}, e
	}
	sum := sha256.Sum256([]byte(sub))
	_, e = s.db.ExecContext(ctx, `INSERT INTO user_identities(user_id,provider,provider_subject_hash) VALUES(?,?,?)`, user, provider, sum[:])
	if e != nil {
		var owner string
		q := s.db.QueryRowContext(ctx, `SELECT user_id FROM user_identities WHERE provider=? AND provider_subject_hash=?`, provider, sum[:]).Scan(&owner)
		if q == nil && owner != user {
			return Result{}, ErrAlreadyBound
		}
		if q == nil {
			return Result{provider, sub}, nil
		}
		return Result{}, fmt.Errorf("bind identity: %w", e)
	}
	return Result{provider, sub}, nil
}
func (s *MySQLService) Resolve(ctx context.Context, provider, proof string) (string, error) {
	sub, e := subject(s.development, provider, proof)
	if e != nil {
		return "", e
	}
	var user string
	sum := sha256.Sum256([]byte(sub))
	e = s.db.QueryRowContext(ctx, `SELECT user_id FROM user_identities WHERE provider=? AND provider_subject_hash=?`, provider, sum[:]).Scan(&user)
	if errors.Is(e, sql.ErrNoRows) {
		return "", ErrInvalidProof
	}
	return user, e
}
