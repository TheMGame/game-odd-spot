package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"game-odd-spot/server/internal/app"
	"game-odd-spot/server/internal/config"
)

func TestMySQLAccountRestoreReportAndMetrics(t *testing.T) {
	dsn := os.Getenv("ODDSPOT_TEST_MYSQL_DSN")
	if dsn == "" {
		t.Skip("ODDSPOT_TEST_MYSQL_DSN is not set")
	}
	cfg := config.Config{Environment: "test", DatabaseDSN: dsn, InstallationHMACKey: "integration-hmac-key-at-least-32-characters", AdminToken: "integration-admin-token-at-least-32-chars", Market: "global", Locale: "en"}
	handler, closeDB, err := app.NewHandler(context.Background(), cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	defer closeDB()
	server := httptest.NewServer(handler)
	defer server.Close()
	suffix := time.Now().UTC().Format("20060102150405.000000000")
	created := post(t, server.URL+"/v1/sessions/anonymous", "", map[string]any{"installation_id": "integration-installation-" + suffix, "app_version": "0.1.0", "platform": "desktop", "locale": "zh_CN", "store_country": "CN"})
	first := created["data"].(map[string]any)
	token := first["access_token"].(string)
	accountProof := "test_account_integration_" + suffix
	post(t, server.URL+"/v1/account/bind", token, map[string]any{"provider": "test", "proof": accountProof})
	restored := post(t, server.URL+"/v1/account/login", "", map[string]any{"provider": "test", "proof": accountProof})["data"].(map[string]any)
	if first["user_id"] != restored["user_id"] {
		t.Fatal("restored a different user")
	}
	bootstrap := get(t, server.URL+"/v1/bootstrap", restored["access_token"].(string), "")["data"].(map[string]any)
	if bootstrap["market"] != "cn" {
		t.Fatalf("market=%v, want cn", bootstrap["market"])
	}
	report := post(t, server.URL+"/v1/reports", restored["access_token"].(string), map[string]any{"level_id": "global_demo_001", "category": "other", "description": "integration verification report"})["data"].(map[string]any)
	metrics := get(t, server.URL+"/admin/v1/metrics/summary", "", cfg.AdminToken)["data"].(map[string]any)
	if metrics["users"].(float64) < 1 {
		t.Fatal("metrics did not count users")
	}
	postAdmin(t, server.URL+"/admin/v1/reports/"+report["id"].(string)+"/resolve", cfg.AdminToken, map[string]any{"status": "resolved", "note": "integration test complete"})
}

func post(t *testing.T, url, token string, body any) map[string]any {
	return request(t, http.MethodPost, url, token, "", body)
}
func postAdmin(t *testing.T, url, admin string, body any) map[string]any {
	return request(t, http.MethodPost, url, "", admin, body)
}
func get(t *testing.T, url, token, admin string) map[string]any {
	return request(t, http.MethodGet, url, token, admin, nil)
}
func request(t *testing.T, method, url, token, admin string, body any) map[string]any {
	t.Helper()
	var raw []byte
	if body != nil {
		raw, _ = json.Marshal(body)
	}
	req, _ := http.NewRequest(method, url, bytes.NewReader(raw))
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if admin != "" {
		req.Header.Set("X-Admin-Token", admin)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	payload, _ := io.ReadAll(res.Body)
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		t.Fatalf("%s %s: %d %s", method, url, res.StatusCode, payload)
	}
	var out map[string]any
	if len(payload) > 0 && json.Unmarshal(payload, &out) != nil {
		t.Fatalf("invalid JSON: %s", payload)
	}
	return out
}
