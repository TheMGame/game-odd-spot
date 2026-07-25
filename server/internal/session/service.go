package session

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"sync"
)

var ErrInvalidRefreshToken = errors.New("invalid refresh token")

type Session struct {
	UserID       string
	AccessToken  string
	RefreshToken string
}

type CreateRequest struct {
	InstallationID string
	Market         string
	Locale         string
}

type Service interface {
	CreateOrRestore(ctx context.Context, request CreateRequest) (Session, error)
	Authenticate(ctx context.Context, accessToken string) (string, bool)
	Refresh(ctx context.Context, refreshToken string) (Session, error)
	Revoke(ctx context.Context, refreshToken string) error
	Issue(ctx context.Context, userID string) (Session, error)
	IssueExternal(ctx context.Context, userID, market, locale string) (Session, error)
	EnsureExternalUser(ctx context.Context, userID, market, locale string) error
	Profile(ctx context.Context, userID string) (string, string, error)
}

func (s *MemoryService) IssueExternal(ctx context.Context, userID, _ string, _ string) (Session, error) {
	return s.Issue(ctx, userID)
}

func (s *MemoryService) EnsureExternalUser(_ context.Context, _ string, _ string, _ string) error {
	return nil
}

func (s *MemoryService) Issue(_ context.Context, userID string) (Session, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	created, err := newSessionTokens()
	if err != nil {
		return Session{}, err
	}
	created.UserID = userID
	s.byAccessToken[created.AccessToken] = userID
	s.byRefreshToken[created.RefreshToken] = created
	return created, nil
}
func (s *MemoryService) Profile(_ context.Context, _ string) (string, string, error) {
	return "global", "en", nil
}

type MemoryService struct {
	mu             sync.RWMutex
	byInstallation map[string]Session
	byAccessToken  map[string]string
	byRefreshToken map[string]Session
}

func NewMemoryService() *MemoryService {
	return &MemoryService{
		byInstallation: make(map[string]Session),
		byAccessToken:  make(map[string]string),
		byRefreshToken: make(map[string]Session),
	}
}

func (s *MemoryService) CreateOrRestore(_ context.Context, request CreateRequest) (Session, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if existing, ok := s.byInstallation[request.InstallationID]; ok {
		return existing, nil
	}
	userID, err := randomToken(18)
	if err != nil {
		return Session{}, fmt.Errorf("generate user id: %w", err)
	}
	access, err := randomToken(32)
	if err != nil {
		return Session{}, fmt.Errorf("generate access token: %w", err)
	}
	refresh, err := randomToken(48)
	if err != nil {
		return Session{}, fmt.Errorf("generate refresh token: %w", err)
	}
	created := Session{UserID: "usr_" + userID, AccessToken: access, RefreshToken: refresh}
	s.byInstallation[request.InstallationID] = created
	s.byAccessToken[access] = created.UserID
	s.byRefreshToken[refresh] = created
	return created, nil
}

func (s *MemoryService) Authenticate(_ context.Context, accessToken string) (string, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	userID, ok := s.byAccessToken[accessToken]
	return userID, ok
}

func (s *MemoryService) Refresh(_ context.Context, refreshToken string) (Session, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.byRefreshToken[refreshToken]
	if !ok {
		return Session{}, ErrInvalidRefreshToken
	}
	delete(s.byRefreshToken, refreshToken)
	delete(s.byAccessToken, existing.AccessToken)
	rotated, err := newSessionTokens()
	if err != nil {
		return Session{}, err
	}
	rotated.UserID = existing.UserID
	s.byAccessToken[rotated.AccessToken] = rotated.UserID
	s.byRefreshToken[rotated.RefreshToken] = rotated
	return rotated, nil
}

func (s *MemoryService) Revoke(_ context.Context, refreshToken string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.byRefreshToken[refreshToken]
	if !ok {
		return nil
	}
	delete(s.byRefreshToken, refreshToken)
	delete(s.byAccessToken, existing.AccessToken)
	return nil
}

func randomToken(byteCount int) (string, error) {
	buffer := make([]byte, byteCount)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buffer), nil
}
