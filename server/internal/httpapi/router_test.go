package httpapi_test

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"game-odd-spot/server/internal/analytics"
	"game-odd-spot/server/internal/catalog"
	"game-odd-spot/server/internal/config"
	"game-odd-spot/server/internal/content"
	"game-odd-spot/server/internal/generation"
	"game-odd-spot/server/internal/httpapi"
	"game-odd-spot/server/internal/level"
	"game-odd-spot/server/internal/market"
	"game-odd-spot/server/internal/monetization"
	"game-odd-spot/server/internal/operations"
	"game-odd-spot/server/internal/remoteconfig"
	"game-odd-spot/server/internal/session"
)

func TestAnonymousSessionAndBootstrap(t *testing.T) {
	handler := newTestHandler()
	body := []byte(`{"installation_id":"0123456789abcdef0123456789abcdef","app_version":"0.1.0","platform":"android","locale":"zh-CN"}`)
	request := httptest.NewRequest(http.MethodPost, "/v1/sessions/anonymous", bytes.NewReader(body))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("session status = %d, body = %s", response.Code, response.Body.String())
	}
	var sessionResponse struct {
		Data struct {
			AccessToken string `json:"access_token"`
			UserID      string `json:"user_id"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &sessionResponse); err != nil {
		t.Fatal(err)
	}
	if sessionResponse.Data.AccessToken == "" || sessionResponse.Data.UserID == "" {
		t.Fatal("session response omitted identity or token")
	}

	bootstrap := httptest.NewRequest(http.MethodGet, "/v1/bootstrap", nil)
	bootstrap.Header.Set("Authorization", "Bearer "+sessionResponse.Data.AccessToken)
	bootstrapResponse := httptest.NewRecorder()
	handler.ServeHTTP(bootstrapResponse, bootstrap)
	if bootstrapResponse.Code != http.StatusOK {
		t.Fatalf("bootstrap status = %d, body = %s", bootstrapResponse.Code, bootstrapResponse.Body.String())
	}
}

func TestAnonymousSessionRestoresSameUser(t *testing.T) {
	handler := newTestHandler()
	body := []byte(`{"installation_id":"0123456789abcdef0123456789abcdef","app_version":"0.1.0","platform":"android","locale":"zh-CN"}`)
	var firstUser string
	for attempt := 0; attempt < 2; attempt++ {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/v1/sessions/anonymous", bytes.NewReader(body)))
		if response.Code != http.StatusOK {
			t.Fatalf("session status = %d", response.Code)
		}
		var decoded struct {
			Data struct {
				UserID string `json:"user_id"`
			} `json:"data"`
		}
		if err := json.Unmarshal(response.Body.Bytes(), &decoded); err != nil {
			t.Fatal(err)
		}
		if attempt == 0 {
			firstUser = decoded.Data.UserID
		} else if decoded.Data.UserID != firstUser {
			t.Fatalf("restored user = %q, want %q", decoded.Data.UserID, firstUser)
		}
	}
}

func TestBootstrapRejectsMissingToken(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/v1/bootstrap", nil)
	response := httptest.NewRecorder()
	newTestHandler().ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusUnauthorized)
	}
}

func TestLocalesAndGeoDefaultArePublic(t *testing.T) {
	handler := newTestHandler()
	locales := httptest.NewRecorder()
	handler.ServeHTTP(locales, httptest.NewRequest(http.MethodGet, "/v1/locales", nil))
	if locales.Code != http.StatusOK || !bytes.Contains(locales.Body.Bytes(), []byte(`"zh-CN"`)) {
		t.Fatalf("locales status=%d body=%s", locales.Code, locales.Body.String())
	}
	request := httptest.NewRequest(http.MethodGet, "/v1/locale/default", nil)
	request.Header.Set("CF-IPCountry", "CN")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK || !bytes.Contains(response.Body.Bytes(), []byte(`"zh-CN"`)) {
		t.Fatalf("default locale status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestSessionLocaleCanBeUpdated(t *testing.T) {
	handler := newTestHandler()
	created := createSession(t, handler)
	request := authorizedRequest(http.MethodPut, "/v1/session/locale", []byte(`{"locale":"en_US"}`), created.AccessToken, "")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK || !bytes.Contains(response.Body.Bytes(), []byte(`"en-US"`)) {
		t.Fatalf("update locale status=%d body=%s", response.Code, response.Body.String())
	}
	bootstrap := httptest.NewRecorder()
	handler.ServeHTTP(bootstrap, authorizedRequest(http.MethodGet, "/v1/bootstrap", nil, created.AccessToken, ""))
	if bootstrap.Code != http.StatusOK || !bytes.Contains(bootstrap.Body.Bytes(), []byte(`"locale":"en-US"`)) {
		t.Fatalf("bootstrap status=%d body=%s", bootstrap.Code, bootstrap.Body.String())
	}
}

func TestRefreshRotatesTokensAndRejectsReplay(t *testing.T) {
	handler := newTestHandler()
	created := createSession(t, handler)
	body, _ := json.Marshal(map[string]string{"refresh_token": created.RefreshToken})
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/v1/sessions/refresh", bytes.NewReader(body)))
	if response.Code != http.StatusOK {
		t.Fatalf("refresh status = %d, body = %s", response.Code, response.Body.String())
	}
	var rotated struct {
		Data testSession `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &rotated); err != nil {
		t.Fatal(err)
	}
	if rotated.Data.AccessToken == created.AccessToken || rotated.Data.RefreshToken == created.RefreshToken {
		t.Fatal("refresh did not rotate both tokens")
	}

	replay := httptest.NewRecorder()
	handler.ServeHTTP(replay, httptest.NewRequest(http.MethodPost, "/v1/sessions/refresh", bytes.NewReader(body)))
	if replay.Code != http.StatusUnauthorized {
		t.Fatalf("replay status = %d, want %d", replay.Code, http.StatusUnauthorized)
	}
}

func TestLogoutRevokesSession(t *testing.T) {
	handler := newTestHandler()
	created := createSession(t, handler)
	body, _ := json.Marshal(map[string]string{"refresh_token": created.RefreshToken})
	request := httptest.NewRequest(http.MethodPost, "/v1/sessions/logout", bytes.NewReader(body))
	request.Header.Set("Authorization", "Bearer "+created.AccessToken)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusNoContent {
		t.Fatalf("logout status = %d, body = %s", response.Code, response.Body.String())
	}

	bootstrap := httptest.NewRequest(http.MethodGet, "/v1/bootstrap", nil)
	bootstrap.Header.Set("Authorization", "Bearer "+created.AccessToken)
	bootstrapResponse := httptest.NewRecorder()
	handler.ServeHTTP(bootstrapResponse, bootstrap)
	if bootstrapResponse.Code != http.StatusUnauthorized {
		t.Fatalf("revoked access token status = %d", bootstrapResponse.Code)
	}
}

func TestLevelFlow(t *testing.T) {
	handler := newTestHandler()
	sessionData := createSession(t, handler)

	home := authorizedRequest(http.MethodGet, "/v1/home", nil, sessionData.AccessToken, "")
	homeResponse := httptest.NewRecorder()
	handler.ServeHTTP(homeResponse, home)
	if homeResponse.Code != http.StatusOK {
		t.Fatalf("home status=%d", homeResponse.Code)
	}

	startBody := []byte(`{"attempt_id":"019f8b77-1111-7000-8000-111111111111","level_version":1}`)
	start := authorizedRequest(http.MethodPost, "/v1/levels/global_demo_001/start", startBody, sessionData.AccessToken, "019f8b77-1111-7000-8000-111111111112")
	startResponse := httptest.NewRecorder()
	handler.ServeHTTP(startResponse, start)
	if startResponse.Code != http.StatusOK {
		t.Fatalf("start status=%d body=%s", startResponse.Code, startResponse.Body.String())
	}

	progressBody := []byte(`{"attempt_id":"019f8b77-1111-7000-8000-111111111111","found":[{"difference_id":"d1","found_at_ms":1000},{"difference_id":"d2","found_at_ms":2000}],"hints_used":0,"duration_ms":2000}`)
	progress := authorizedRequest(http.MethodPost, "/v1/levels/global_demo_001/progress", progressBody, sessionData.AccessToken, "019f8b77-1111-7000-8000-111111111113")
	progressResponse := httptest.NewRecorder()
	handler.ServeHTTP(progressResponse, progress)
	if progressResponse.Code != http.StatusOK {
		t.Fatalf("progress status=%d body=%s", progressResponse.Code, progressResponse.Body.String())
	}

	completeBody := []byte(`{"attempt_id":"019f8b77-1111-7000-8000-111111111111","difference_ids":["d1","d2","d3","d4","d5"],"hints_used":0,"duration_ms":5000}`)
	complete := authorizedRequest(http.MethodPost, "/v1/levels/global_demo_001/complete", completeBody, sessionData.AccessToken, "019f8b77-1111-7000-8000-111111111114")
	completeResponse := httptest.NewRecorder()
	handler.ServeHTTP(completeResponse, complete)
	if completeResponse.Code != http.StatusOK {
		t.Fatalf("complete status=%d body=%s", completeResponse.Code, completeResponse.Body.String())
	}
	var decoded struct {
		Data level.AttemptResult `json:"data"`
	}
	if err := json.Unmarshal(completeResponse.Body.Bytes(), &decoded); err != nil {
		t.Fatal(err)
	}
	if decoded.Data.State != "completed" || decoded.Data.Reward != 1 {
		t.Fatalf("complete result=%+v", decoded.Data)
	}
}

func TestAdminRequiresTokenAndListsContent(t *testing.T) {
	handler := newTestHandler()
	unauthorized := httptest.NewRecorder()
	handler.ServeHTTP(unauthorized, httptest.NewRequest(http.MethodGet, "/admin/v1/levels", nil))
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized status=%d", unauthorized.Code)
	}
	request := httptest.NewRequest(http.MethodGet, "/admin/v1/levels", nil)
	request.Header.Set("X-Admin-Token", "test-admin-token")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("admin list status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestAdminLevelStatusAndDeleteRoutes(t *testing.T) {
	handler := newTestHandler()
	for _, tc := range []struct{ method, path string }{
		{http.MethodDelete, "/admin/v1/levels/lv_demo"},
		{http.MethodPost, "/admin/v1/levels/lv_demo/status"},
	} {
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, httptest.NewRequest(tc.method, tc.path, nil))
		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("%s %s expected 401, got %d", tc.method, tc.path, rec.Code)
		}
	}
	statusReq := httptest.NewRequest(http.MethodPost, "/admin/v1/levels/lv_demo/status", bytes.NewReader([]byte(`{"status":"disabled"}`)))
	statusReq.Header.Set("X-Admin-Token", "test-admin-token")
	statusReq.Header.Set("Content-Type", "application/json")
	statusRec := httptest.NewRecorder()
	handler.ServeHTTP(statusRec, statusReq)
	if statusRec.Code != http.StatusOK {
		t.Fatalf("status route code=%d body=%s", statusRec.Code, statusRec.Body.String())
	}
	delReq := httptest.NewRequest(http.MethodDelete, "/admin/v1/levels/lv_demo", nil)
	delReq.Header.Set("X-Admin-Token", "test-admin-token")
	delRec := httptest.NewRecorder()
	handler.ServeHTTP(delRec, delReq)
	if delRec.Code != http.StatusOK {
		t.Fatalf("delete route code=%d body=%s", delRec.Code, delRec.Body.String())
	}
}

func TestVersionedConfig(t *testing.T) {
	handler := newTestHandler()
	created := createSession(t, handler)
	request := authorizedRequest(http.MethodGet, "/v1/config/1", nil, created.AccessToken, "")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("config status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestEventsMonetizationAndDailyChallenge(t *testing.T) {
	handler := newTestHandler()
	created := createSession(t, handler)
	eventBody := []byte(`{"events":[{"event_id":"019f8b77-2222-7000-8000-111111111111","session_id":"session-1","event_type":"app_open","market":"global","locale":"en-US","app_version":"0.1.0","occurred_at":"2026-07-23T00:00:00Z","payload":{}}]}`)
	eventResponse := httptest.NewRecorder()
	handler.ServeHTTP(eventResponse, authorizedRequest(http.MethodPost, "/v1/events/batch", eventBody, created.AccessToken, ""))
	if eventResponse.Code != http.StatusAccepted {
		t.Fatalf("events status=%d body=%s", eventResponse.Code, eventResponse.Body.String())
	}
	adBody := []byte(`{"provider":"mock","proof":"test_ad_example","reward_type":"hint"}`)
	adResponse := httptest.NewRecorder()
	handler.ServeHTTP(adResponse, authorizedRequest(http.MethodPost, "/v1/rewards/ad", adBody, created.AccessToken, ""))
	if adResponse.Code != http.StatusOK {
		t.Fatalf("ad status=%d body=%s", adResponse.Code, adResponse.Body.String())
	}
	dailyResponse := httptest.NewRecorder()
	handler.ServeHTTP(dailyResponse, authorizedRequest(http.MethodGet, "/v1/daily-challenge", nil, created.AccessToken, ""))
	if dailyResponse.Code != http.StatusOK {
		t.Fatalf("daily status=%d", dailyResponse.Code)
	}
}

func TestAnonymousSessionRejectsUnknownFields(t *testing.T) {
	body := []byte(`{"installation_id":"0123456789abcdef0123456789abcdef","app_version":"0.1.0","platform":"android","locale":"zh-CN","unexpected":true}`)
	request := httptest.NewRequest(http.MethodPost, "/v1/sessions/anonymous", bytes.NewReader(body))
	response := httptest.NewRecorder()
	newTestHandler().ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusBadRequest)
	}
}

func TestCORSPreflightAllowsLocalWebBuild(t *testing.T) {
	request := httptest.NewRequest(http.MethodOptions, "/v1/sessions/user-server", nil)
	request.Header.Set("Origin", "http://localhost:8000")
	request.Header.Set("Access-Control-Request-Method", http.MethodPost)
	request.Header.Set("Access-Control-Request-Headers", "content-type")
	response := httptest.NewRecorder()
	newTestHandler().ServeHTTP(response, request)
	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNoContent)
	}
	if got := response.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:8000" {
		t.Fatalf("Access-Control-Allow-Origin = %q", got)
	}
}

func TestCORSDoesNotExposeContentToLocalWebBuild(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/content/example.png", nil)
	request.Header.Set("Origin", "http://localhost:8000")
	response := httptest.NewRecorder()
	newTestHandler().ServeHTTP(response, request)
	if got := response.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("content Access-Control-Allow-Origin = %q, want empty", got)
	}
}

func TestContentResponsesAreLongLived(t *testing.T) {
	contentDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(contentDir, "example.png"), []byte("image"), 0600); err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodGet, "/content/example.png", nil)
	response := httptest.NewRecorder()
	newTestHandler(contentDir).ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if got := response.Header().Get("Cache-Control"); got != "public, max-age=31536000, immutable" {
		t.Fatalf("content Cache-Control = %q", got)
	}
}

func newTestHandler(contentDirs ...string) http.Handler {
	contentDir := ""
	if len(contentDirs) > 0 {
		contentDir = contentDirs[0]
	}
	return httpapi.NewRouter(httpapi.Dependencies{
		Config: config.Config{
			Environment:        "test",
			HTTPAddr:           "127.0.0.1:0",
			Market:             "global",
			Locale:             "en-US",
			AdminToken:         "test-admin-token",
			CORSAllowedOrigins: []string{"http://localhost:8000"},
			ContentDir:         contentDir,
		},
		Logger:     slog.New(slog.NewTextHandler(io.Discard, nil)),
		Sessions:   session.NewMemoryService(),
		Catalog:    catalog.NewMemoryService(),
		Levels:     level.NewMemoryService(),
		Configs:    remoteconfig.NewMemoryService(),
		Contents:   content.NewMemoryService(),
		Analytics:  analytics.NewMemoryService(),
		Money:      monetization.NewMemoryService(true),
		Operations: operations.NewMemoryService(),
		Generation: generation.NewMemoryService(),
		Markets:    market.NewMemoryService(),
	})
}

type testSession struct {
	UserID       string `json:"user_id"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func createSession(t *testing.T, handler http.Handler) testSession {
	t.Helper()
	body := []byte(`{"installation_id":"0123456789abcdef0123456789abcdef","app_version":"0.1.0","platform":"android","locale":"zh-CN"}`)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/v1/sessions/anonymous", bytes.NewReader(body)))
	if response.Code != http.StatusOK {
		t.Fatalf("create session status = %d", response.Code)
	}
	var decoded struct {
		Data testSession `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &decoded); err != nil {
		t.Fatal(err)
	}
	return decoded.Data
}

func authorizedRequest(method, path string, body []byte, token, idempotency string) *http.Request {
	request := httptest.NewRequest(method, path, bytes.NewReader(body))
	request.Header.Set("Authorization", "Bearer "+token)
	if idempotency != "" {
		request.Header.Set("Idempotency-Key", idempotency)
	}
	return request
}
