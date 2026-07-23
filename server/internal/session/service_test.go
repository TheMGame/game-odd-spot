package session

import (
	"context"
	"errors"
	"testing"
)

func TestMemoryServiceRestoresIdentityAndAuthenticates(t *testing.T) {
	service := NewMemoryService()
	request := CreateRequest{InstallationID: "0123456789abcdef0123456789abcdef", Market: "global", Locale: "en-US"}
	first, err := service.CreateOrRestore(context.Background(), request)
	if err != nil {
		t.Fatal(err)
	}
	second, err := service.CreateOrRestore(context.Background(), request)
	if err != nil {
		t.Fatal(err)
	}
	if first.UserID != second.UserID {
		t.Fatalf("restored user = %q, want %q", second.UserID, first.UserID)
	}
	if userID, ok := service.Authenticate(context.Background(), first.AccessToken); !ok || userID != first.UserID {
		t.Fatal("access token did not authenticate")
	}
}

func TestMemoryServiceRefreshIsSingleUse(t *testing.T) {
	service := NewMemoryService()
	created, err := service.CreateOrRestore(context.Background(), CreateRequest{InstallationID: "0123456789abcdef0123456789abcdef"})
	if err != nil {
		t.Fatal(err)
	}
	rotated, err := service.Refresh(context.Background(), created.RefreshToken)
	if err != nil {
		t.Fatal(err)
	}
	if rotated.AccessToken == created.AccessToken || rotated.RefreshToken == created.RefreshToken {
		t.Fatal("tokens were not rotated")
	}
	if _, err := service.Refresh(context.Background(), created.RefreshToken); !errors.Is(err, ErrInvalidRefreshToken) {
		t.Fatalf("replay error = %v", err)
	}
}
