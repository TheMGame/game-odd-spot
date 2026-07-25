package httpapi

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	xdraw "golang.org/x/image/draw"

	"game-odd-spot/server/internal/account"
	"game-odd-spot/server/internal/analytics"
	"game-odd-spot/server/internal/catalog"
	"game-odd-spot/server/internal/config"
	"game-odd-spot/server/internal/content"
	"game-odd-spot/server/internal/generation"
	"game-odd-spot/server/internal/level"
	"game-odd-spot/server/internal/market"
	"game-odd-spot/server/internal/metrics"
	"game-odd-spot/server/internal/monetization"
	"game-odd-spot/server/internal/operations"
	"game-odd-spot/server/internal/remoteconfig"
	"game-odd-spot/server/internal/report"
	"game-odd-spot/server/internal/session"
)

type Dependencies struct {
	Config     config.Config
	Logger     *slog.Logger
	Sessions   session.Service
	Levels     level.Service
	Configs    remoteconfig.Service
	Contents   content.Service
	Catalog    catalog.Service
	Analytics  analytics.Service
	Money      monetization.Service
	Operations operations.Service
	Generation generation.Service
	Markets    market.Service
	Accounts   account.Service
	Reports    report.Service
	Metrics    metrics.Service
	Ready      func(context.Context) error
}

type api struct {
	deps Dependencies
}

type envelope struct {
	RequestID     string `json:"request_id"`
	ServerTime    string `json:"server_time"`
	ConfigVersion int64  `json:"config_version"`
	Data          any    `json:"data"`
}

func NewRouter(deps Dependencies) http.Handler {
	a := &api{deps: deps}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health/live", a.live)
	mux.HandleFunc("GET /health/ready", a.ready)
	if deps.Config.UserServerBaseURL == "" {
		// Legacy development mode only. Production uses the shared user_server.
		mux.HandleFunc("POST /v1/sessions/anonymous", a.anonymousSession)
		mux.HandleFunc("POST /v1/sessions/refresh", a.refreshSession)
		mux.Handle("POST /v1/sessions/logout", a.requireAuth(http.HandlerFunc(a.logoutSession)))
		mux.Handle("POST /v1/account/bind", a.requireAuth(http.HandlerFunc(a.bindAccount)))
		mux.HandleFunc("POST /v1/account/login", a.loginAccount)
	} else {
		mux.HandleFunc("POST /v1/sessions/user-server", a.userServerSession)
		mux.HandleFunc("POST /v1/sessions/refresh", a.refreshSession)
		mux.Handle("POST /v1/sessions/logout", a.requireAuth(http.HandlerFunc(a.logoutSession)))
	}
	mux.Handle("GET /v1/bootstrap", a.requireAuth(http.HandlerFunc(a.bootstrap)))
	mux.Handle("GET /v1/home", a.requireAuth(http.HandlerFunc(a.home)))
	mux.Handle("GET /v1/catalog", a.requireAuth(http.HandlerFunc(a.publicCatalog)))
	mux.Handle("GET /v1/levels/{levelId}", a.requireAuth(http.HandlerFunc(a.getLevel)))
	mux.Handle("POST /v1/levels/{levelId}/start", a.requireAuth(http.HandlerFunc(a.startLevel)))
	mux.Handle("POST /v1/levels/{levelId}/progress", a.requireAuth(http.HandlerFunc(a.progressLevel)))
	mux.Handle("POST /v1/levels/{levelId}/complete", a.requireAuth(http.HandlerFunc(a.completeLevel)))
	mux.Handle("GET /v1/config/{version}", a.requireAuth(http.HandlerFunc(a.getConfig)))
	mux.Handle("GET /admin/v1/levels", a.requireAdmin(http.HandlerFunc(a.adminLevels)))
	mux.Handle("GET /admin/v1/catalog", a.requireAdmin(http.HandlerFunc(a.adminCatalog)))
	mux.Handle("POST /admin/v1/series", a.requireAdmin(http.HandlerFunc(a.upsertSeries)))
	mux.Handle("GET /admin/v1/levels/{levelId}", a.requireAdmin(http.HandlerFunc(a.adminGetLevel)))
	mux.Handle("POST /admin/v1/levels/{levelId}", a.requireAdmin(http.HandlerFunc(a.upsertCatalogLevel)))
	mux.Handle("GET /admin/v1/assets", a.requireAdmin(http.HandlerFunc(a.listAssets)))
	mux.Handle("POST /admin/v1/assets/{assetId}", a.requireAdmin(http.HandlerFunc(a.uploadAsset)))
	mux.Handle("POST /admin/v1/levels/{levelId}/versions/{version}/transition", a.requireAdmin(http.HandlerFunc(a.adminTransition)))
	mux.Handle("POST /v1/events/batch", a.requireAuth(http.HandlerFunc(a.ingestEvents)))
	mux.Handle("POST /v1/rewards/ad", a.requireAuth(http.HandlerFunc(a.claimAdReward)))
	mux.Handle("POST /v1/purchases/verify", a.requireAuth(http.HandlerFunc(a.verifyPurchase)))
	mux.Handle("GET /v1/daily-challenge", a.requireAuth(http.HandlerFunc(a.dailyChallenge)))
	mux.Handle("GET /v1/activities", a.requireAuth(http.HandlerFunc(a.activities)))
	mux.Handle("GET /v1/experiments/{experimentKey}", a.requireAuth(http.HandlerFunc(a.experiment)))
	mux.Handle("POST /v1/reports", a.requireAuth(http.HandlerFunc(a.createReport)))
	mux.Handle("GET /admin/v1/reports", a.requireAdmin(http.HandlerFunc(a.adminReports)))
	mux.Handle("POST /admin/v1/reports/{reportId}/resolve", a.requireAdmin(http.HandlerFunc(a.resolveReport)))
	mux.Handle("GET /admin/v1/metrics/summary", a.requireAdmin(http.HandlerFunc(a.metricsSummary)))
	mux.Handle("POST /admin/v1/generation/jobs", a.requireAdmin(http.HandlerFunc(a.createGenerationJob)))
	mux.Handle("GET /admin/v1/generation/jobs/{jobId}", a.requireAdmin(http.HandlerFunc(a.getGenerationJob)))
	_ = os.MkdirAll(deps.Config.ContentDir, 0755)
	mux.Handle("GET /content/", http.StripPrefix("/content/", http.FileServer(http.Dir(deps.Config.ContentDir))))
	mux.Handle("GET /admin/", http.StripPrefix("/admin/", http.FileServer(http.Dir(deps.Config.AdminDir))))
	return a.recoverPanic(a.requestLog(a.cors(mux)))
}

func (a *api) cors(next http.Handler) http.Handler {
	allowed := make(map[string]struct{}, len(a.deps.Config.CORSAllowedOrigins))
	for _, origin := range a.deps.Config.CORSAllowedOrigins {
		allowed[strings.TrimRight(origin, "/")] = struct{}{}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/v1/") {
			next.ServeHTTP(w, r)
			return
		}
		origin := strings.TrimRight(r.Header.Get("Origin"), "/")
		if _, ok := allowed[origin]; ok {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Request-ID, Idempotency-Key")
			w.Header().Set("Access-Control-Max-Age", "600")
			w.Header().Add("Vary", "Origin")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

func (a *api) publicCatalog(w http.ResponseWriter, r *http.Request) {
	items, err := a.deps.Catalog.Public(r.Context())
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not load catalog")
		return
	}
	normalizeCatalogAssetURLs(items, a.deps.Config.PublicBaseURL)
	writeJSON(w, 200, newEnvelope(map[string]any{"series": items}))
}

func (a *api) adminCatalog(w http.ResponseWriter, r *http.Request) {
	items, err := a.deps.Catalog.Admin(r.Context())
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not load admin catalog")
		return
	}
	normalizeCatalogAssetURLs(items, a.deps.Config.PublicBaseURL)
	writeJSON(w, 200, newEnvelope(map[string]any{"series": items}))
}

func (a *api) upsertSeries(w http.ResponseWriter, r *http.Request) {
	var input catalog.Series
	if !decodeBody(w, r, &input) {
		return
	}
	if err := a.deps.Catalog.UpsertSeries(r.Context(), input); err != nil {
		writeError(w, 400, "VALIDATION_FAILED", err.Error())
		return
	}
	writeJSON(w, 200, newEnvelope(input))
}

func (a *api) upsertCatalogLevel(w http.ResponseWriter, r *http.Request) {
	var input catalog.UpsertLevel
	if !decodeBody(w, r, &input) {
		return
	}
	if err := a.deps.Catalog.UpsertLevel(r.Context(), r.PathValue("levelId"), input); err != nil {
		writeError(w, 400, "VALIDATION_FAILED", err.Error())
		return
	}
	writeJSON(w, 200, newEnvelope(map[string]any{"level_id": r.PathValue("levelId")}))
}

func (a *api) adminGetLevel(w http.ResponseWriter, r *http.Request) {
	raw, err := a.deps.Catalog.GetLevel(r.Context(), r.PathValue("levelId"))
	if errors.Is(err, catalog.ErrNotFound) {
		writeError(w, 404, "LEVEL_NOT_FOUND", "level not found")
		return
	}
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not load level")
		return
	}
	writeJSON(w, 200, newEnvelope(normalizeRuntimeAssetURLs(raw, a.deps.Config.PublicBaseURL)))
}

func (a *api) listAssets(w http.ResponseWriter, r *http.Request) {
	entries, err := os.ReadDir(a.deps.Config.ContentDir)
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not list assets")
		return
	}
	items := []map[string]any{}
	for _, entry := range entries {
		if entry.IsDir() || strings.Contains(entry.Name(), "-thumb.") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		item := map[string]any{
			"name": entry.Name(), "url": a.deps.Config.PublicBaseURL + "/content/" + entry.Name(),
			"bytes": info.Size(), "updated_at": info.ModTime().UTC(),
		}
		stem := strings.TrimSuffix(entry.Name(), filepath.Ext(entry.Name()))
		thumbName := stem + "-thumb.jpg"
		if thumbInfo, thumbErr := os.Stat(filepath.Join(a.deps.Config.ContentDir, thumbName)); thumbErr == nil {
			item["thumbnail_url"] = a.deps.Config.PublicBaseURL + "/content/" + thumbName
			item["thumbnail_bytes"] = thumbInfo.Size()
		}
		items = append(items, item)
	}
	writeJSON(w, 200, newEnvelope(map[string]any{"items": items}))
}

func (a *api) uploadAsset(w http.ResponseWriter, r *http.Request) {
	assetID := strings.TrimSpace(r.PathValue("assetId"))
	if assetID == "" || strings.ContainsAny(assetID, `/\\.`) {
		writeError(w, 400, "VALIDATION_FAILED", "invalid asset id")
		return
	}
	contentType := r.Header.Get("Content-Type")
	ext := ".png"
	if contentType == "image/jpeg" {
		ext = ".jpg"
	} else if contentType != "image/png" {
		writeError(w, 415, "UNSUPPORTED_MEDIA_TYPE", "only image/png and image/jpeg are supported")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 15<<20))
	if err != nil || len(body) == 0 {
		writeError(w, 400, "VALIDATION_FAILED", "invalid image body")
		return
	}
	sum := sha256.Sum256(body)
	name := assetID + "-" + fmt.Sprintf("%x", sum[:8]) + ext
	originalPath := filepath.Join(a.deps.Config.ContentDir, name)
	if _, statErr := os.Stat(originalPath); errors.Is(statErr, os.ErrNotExist) {
		if err := os.WriteFile(originalPath, body, 0644); err != nil {
			writeError(w, 500, "INTERNAL_ERROR", "could not store asset")
			return
		}
	}
	thumbnail, err := createThumbnail(body, filepath.Join(a.deps.Config.ContentDir, strings.TrimSuffix(name, ext)+"-thumb.jpg"))
	if err != nil {
		writeError(w, 400, "ASSET_DECODE_FAILED", "could not generate thumbnail")
		return
	}
	thumbnailURL := a.deps.Config.PublicBaseURL + "/content/" + strings.TrimSuffix(name, ext) + "-thumb.jpg"
	writeJSON(w, 201, newEnvelope(map[string]any{
		"asset_id": assetID, "url": a.deps.Config.PublicBaseURL + "/content/" + name,
		"sha256": fmt.Sprintf("%x", sum), "bytes": len(body), "content_type": contentType,
		"thumbnail": map[string]any{
			"asset_id": assetID + "_thumb", "url": thumbnailURL, "sha256": thumbnail.sha256,
			"bytes": thumbnail.bytes, "content_type": "image/jpeg", "width": thumbnail.width, "height": thumbnail.height,
		},
	}))
}

type thumbnailResult struct {
	sha256 string
	bytes  int
	width  int
	height int
}

func createThumbnail(source []byte, destination string) (thumbnailResult, error) {
	decoded, _, err := image.Decode(bytes.NewReader(source))
	if err != nil {
		return thumbnailResult{}, err
	}
	bounds := decoded.Bounds()
	width, height := bounds.Dx(), bounds.Dy()
	const maxWidth, maxHeight = 240, 360
	scale := min(float64(maxWidth)/float64(width), float64(maxHeight)/float64(height))
	if scale > 1 {
		scale = 1
	}
	targetWidth := max(1, int(float64(width)*scale))
	targetHeight := max(1, int(float64(height)*scale))
	target := image.NewRGBA(image.Rect(0, 0, targetWidth, targetHeight))
	xdraw.CatmullRom.Scale(target, target.Bounds(), decoded, bounds, xdraw.Over, nil)
	var encoded bytes.Buffer
	if err := jpeg.Encode(&encoded, target, &jpeg.Options{Quality: 82}); err != nil {
		return thumbnailResult{}, err
	}
	data := encoded.Bytes()
	if err := os.WriteFile(destination, data, 0644); err != nil {
		return thumbnailResult{}, err
	}
	sum := sha256.Sum256(data)
	return thumbnailResult{sha256: fmt.Sprintf("%x", sum), bytes: len(data), width: targetWidth, height: targetHeight}, nil
}

func (a *api) home(w http.ResponseWriter, r *http.Request) {
	items, err := a.deps.Levels.Home(r.Context(), authenticatedUser(r))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not load home")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(map[string]any{"items": items, "next_cursor": nil}))
}

func (a *api) getLevel(w http.ResponseWriter, r *http.Request) {
	raw, err := a.deps.Levels.Get(r.Context(), r.PathValue("levelId"))
	if errors.Is(err, level.ErrNotFound) {
		writeError(w, http.StatusNotFound, "LEVEL_NOT_FOUND", "level not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not load level")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(normalizeRuntimeAssetURLs(raw, a.deps.Config.PublicBaseURL)))
}

func normalizeCatalogAssetURLs(items []catalog.Series, publicBaseURL string) {
	for seriesIndex := range items {
		items[seriesIndex].CoverURL = normalizeAssetURL(items[seriesIndex].CoverURL, publicBaseURL)
		for levelIndex := range items[seriesIndex].Levels {
			items[seriesIndex].Levels[levelIndex].ThumbnailURL = normalizeAssetURL(
				items[seriesIndex].Levels[levelIndex].ThumbnailURL,
				publicBaseURL,
			)
		}
	}
}

func normalizeRuntimeAssetURLs(raw json.RawMessage, publicBaseURL string) json.RawMessage {
	var value any
	if len(raw) == 0 || json.Unmarshal(raw, &value) != nil {
		return raw
	}
	normalizeJSONAssetURLs(value, publicBaseURL)
	normalized, err := json.Marshal(value)
	if err != nil {
		return raw
	}
	return normalized
}

func normalizeJSONAssetURLs(value any, publicBaseURL string) {
	switch current := value.(type) {
	case map[string]any:
		for key, child := range current {
			if text, ok := child.(string); ok {
				current[key] = normalizeAssetURL(text, publicBaseURL)
				continue
			}
			normalizeJSONAssetURLs(child, publicBaseURL)
		}
	case []any:
		for _, child := range current {
			normalizeJSONAssetURLs(child, publicBaseURL)
		}
	}
}

func normalizeAssetURL(value, publicBaseURL string) string {
	const contentPath = "/content/"
	index := strings.Index(value, contentPath)
	if index < 0 || strings.TrimSpace(publicBaseURL) == "" {
		return value
	}
	return strings.TrimRight(publicBaseURL, "/") + value[index:]
}

func (a *api) startLevel(w http.ResponseWriter, r *http.Request) {
	var input level.StartRequest
	if !decodeBody(w, r, &input) {
		return
	}
	input.IdempotencyKey = idempotencyKey(w, r)
	if input.IdempotencyKey == "" {
		return
	}
	result, err := a.deps.Levels.Start(r.Context(), authenticatedUser(r), r.PathValue("levelId"), input)
	writeLevelResult(w, result, err)
}

func (a *api) progressLevel(w http.ResponseWriter, r *http.Request) {
	var input level.ProgressRequest
	if !decodeBody(w, r, &input) {
		return
	}
	input.IdempotencyKey = idempotencyKey(w, r)
	if input.IdempotencyKey == "" {
		return
	}
	result, err := a.deps.Levels.Progress(r.Context(), authenticatedUser(r), r.PathValue("levelId"), input)
	writeLevelResult(w, result, err)
}

func (a *api) completeLevel(w http.ResponseWriter, r *http.Request) {
	var input level.CompleteRequest
	if !decodeBody(w, r, &input) {
		return
	}
	input.IdempotencyKey = idempotencyKey(w, r)
	if input.IdempotencyKey == "" {
		return
	}
	result, err := a.deps.Levels.Complete(r.Context(), authenticatedUser(r), r.PathValue("levelId"), input)
	writeLevelResult(w, result, err)
}

func decodeBody(w http.ResponseWriter, r *http.Request, target any) bool {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "invalid JSON request")
		return false
	}
	return true
}

func idempotencyKey(w http.ResponseWriter, r *http.Request) string {
	key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key == "" || len(key) > 128 {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "a valid Idempotency-Key is required")
		return ""
	}
	return key
}

func writeLevelResult(w http.ResponseWriter, result level.AttemptResult, err error) {
	switch {
	case err == nil:
		writeJSON(w, http.StatusOK, newEnvelope(result))
	case errors.Is(err, level.ErrNotFound):
		writeError(w, http.StatusNotFound, "LEVEL_NOT_FOUND", "level not found")
	case errors.Is(err, level.ErrVersionMismatch):
		writeError(w, http.StatusConflict, "LEVEL_VERSION_MISMATCH", "level version is unavailable")
	case errors.Is(err, level.ErrInvalidDiff):
		writeError(w, http.StatusBadRequest, "INVALID_DIFFERENCE", "difference does not belong to level")
	case errors.Is(err, level.ErrIncomplete):
		writeError(w, http.StatusConflict, "LEVEL_INCOMPLETE", "not all differences were found")
	case errors.Is(err, level.ErrIdempotency):
		writeError(w, http.StatusConflict, "IDEMPOTENCY_CONFLICT", "idempotency key was used with another request")
	case errors.Is(err, level.ErrInvalidState):
		writeError(w, http.StatusConflict, "INVALID_STATE", "attempt state is invalid")
	default:
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "level operation failed")
	}
}

func (a *api) refreshSession(w http.ResponseWriter, r *http.Request) {
	refreshToken, ok := decodeRefreshToken(w, r)
	if !ok {
		return
	}
	rotated, err := a.deps.Sessions.Refresh(r.Context(), refreshToken)
	if errors.Is(err, session.ErrInvalidRefreshToken) {
		writeError(w, http.StatusUnauthorized, "REFRESH_TOKEN_INVALID", "the refresh token is invalid or expired")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not refresh session")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(map[string]any{
		"user_id":       rotated.UserID,
		"access_token":  rotated.AccessToken,
		"refresh_token": rotated.RefreshToken,
		"expires_in":    900,
	}))
}

func (a *api) logoutSession(w http.ResponseWriter, r *http.Request) {
	refreshToken, ok := decodeRefreshToken(w, r)
	if !ok {
		return
	}
	if err := a.deps.Sessions.Revoke(r.Context(), refreshToken); err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not revoke session")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func decodeRefreshToken(w http.ResponseWriter, r *http.Request) (string, bool) {
	var input struct {
		RefreshToken string `json:"refresh_token"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil || input.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "refresh_token is required")
		return "", false
	}
	return input.RefreshToken, true
}

func (a *api) live(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *api) ready(w http.ResponseWriter, _ *http.Request) {
	if a.deps.Ready != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if err := a.deps.Ready(ctx); err != nil {
			writeError(w, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "a required dependency is unavailable")
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (a *api) anonymousSession(w http.ResponseWriter, r *http.Request) {
	var input struct {
		InstallationID string `json:"installation_id"`
		AppVersion     string `json:"app_version"`
		Platform       string `json:"platform"`
		Locale         string `json:"locale"`
		StoreCountry   string `json:"store_country"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "invalid JSON request")
		return
	}
	if len(input.InstallationID) < 32 || input.AppVersion == "" || input.Locale == "" || !validPlatform(input.Platform) {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "required session fields are invalid")
		return
	}
	created, err := a.deps.Sessions.CreateOrRestore(r.Context(), session.CreateRequest{
		InstallationID: input.InstallationID,
		Market:         a.deps.Markets.Resolve(r.Context(), input.StoreCountry, input.Locale, a.deps.Config.Market),
		Locale:         input.Locale,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not create session")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(map[string]any{
		"user_id":       created.UserID,
		"access_token":  created.AccessToken,
		"refresh_token": created.RefreshToken,
		"expires_in":    900,
	}))
}

func (a *api) validateUserServerToken(ctx context.Context, token string) (string, bool) {
	body, _ := json.Marshal(map[string]string{
		"token":  token,
		"app_id": a.deps.Config.UserServerAppID,
	})
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		a.deps.Config.UserServerBaseURL+"/api/v1/user/validate_token", bytes.NewReader(body))
	if err != nil {
		return "", false
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", false
	}
	defer resp.Body.Close()
	var validated struct {
		Code int `json:"code"`
		Data struct {
			Valid    bool `json:"valid"`
			UserInfo struct {
				UserID string `json:"user_id"`
			} `json:"user_info"`
		} `json:"data"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&validated); err != nil ||
		resp.StatusCode != http.StatusOK || validated.Code != 0 || !validated.Data.Valid || validated.Data.UserInfo.UserID == "" {
		return "", false
	}
	return validated.Data.UserInfo.UserID, true
}

func (a *api) userServerSession(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Token  string `json:"token"`
		Locale string `json:"locale"`
	}
	if !decodeBody(w, r, &input) {
		return
	}
	if input.Token == "" {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "token is required")
		return
	}
	userID, valid := a.validateUserServerToken(r.Context(), input.Token)
	if !valid {
		writeError(w, http.StatusUnauthorized, "USER_LOGIN_INVALID", "user login is invalid")
		return
	}
	locale := input.Locale
	if locale == "" {
		locale = a.deps.Config.Locale
	}
	created, err := a.deps.Sessions.IssueExternal(r.Context(), userID, a.deps.Config.Market, locale)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not create game session")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(map[string]any{
		"user_id": created.UserID, "access_token": created.AccessToken,
		"refresh_token": created.RefreshToken, "expires_in": 900,
	}))
}

func (a *api) bootstrap(w http.ResponseWriter, r *http.Request) {
	marketID, locale, err := a.deps.Sessions.Profile(r.Context(), authenticatedUser(r))
	if err != nil {
		marketID, locale = a.deps.Config.Market, a.deps.Config.Locale
	}
	snapshot, err := a.deps.Configs.Latest(r.Context(), marketID, locale)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "CONFIG_UNAVAILABLE", "runtime configuration unavailable")
		return
	}
	data := snapshot.Values
	data["market"] = snapshot.Market
	data["config_source_market"] = snapshot.SourceMarket
	data["locale"] = snapshot.Locale
	data["config_version"] = snapshot.Version
	w.Header().Set("ETag", fmt.Sprintf("\"%s-%d\"", snapshot.Market, snapshot.Version))
	writeJSON(w, http.StatusOK, newEnvelope(data))
}

func (a *api) getConfig(w http.ResponseWriter, r *http.Request) {
	version, err := strconv.ParseInt(r.PathValue("version"), 10, 64)
	if err != nil || version < 1 {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "invalid config version")
		return
	}
	snapshot, err := a.deps.Configs.Version(r.Context(), a.deps.Config.Market, version, a.deps.Config.Locale)
	if errors.Is(err, remoteconfig.ErrNotFound) {
		writeError(w, http.StatusNotFound, "CONFIG_NOT_FOUND", "config version not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not load config")
		return
	}
	data := snapshot.Values
	data["market"] = snapshot.Market
	data["config_source_market"] = snapshot.SourceMarket
	data["locale"] = snapshot.Locale
	data["config_version"] = snapshot.Version
	writeJSON(w, http.StatusOK, newEnvelope(data))
}

func (a *api) adminLevels(w http.ResponseWriter, r *http.Request) {
	items, err := a.deps.Contents.List(r.Context(), r.URL.Query().Get("status"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not list content")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(map[string]any{"items": items}))
}

func (a *api) adminTransition(w http.ResponseWriter, r *http.Request) {
	version, err := strconv.Atoi(r.PathValue("version"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "invalid version")
		return
	}
	var input struct {
		ToStatus   string `json:"to_status"`
		Reason     string `json:"reason"`
		ReviewerID string `json:"reviewer_id"`
	}
	if !decodeBody(w, r, &input) {
		return
	}
	if input.ReviewerID == "" {
		input.ReviewerID = "admin"
	}
	err = a.deps.Contents.Transition(r.Context(), r.PathValue("levelId"), version, input.ToStatus, input.ReviewerID, input.Reason)
	if errors.Is(err, content.ErrNotFound) {
		writeError(w, http.StatusNotFound, "LEVEL_NOT_FOUND", "level version not found")
		return
	}
	if errors.Is(err, content.ErrTransition) {
		writeError(w, http.StatusConflict, "INVALID_CONTENT_TRANSITION", "content state transition is invalid")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not transition content")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(map[string]any{"status": input.ToStatus}))
}

func (a *api) ingestEvents(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Events []analytics.Event `json:"events"`
	}
	if !decodeBody(w, r, &input) {
		return
	}
	if len(input.Events) < 1 || len(input.Events) > 100 {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "events must contain 1 to 100 items")
		return
	}
	for _, event := range input.Events {
		if event.EventID == "" || event.EventType == "" || event.SessionID == "" || event.OccurredAt.IsZero() {
			writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "event fields are incomplete")
			return
		}
	}
	accepted, err := a.deps.Analytics.Ingest(r.Context(), authenticatedUser(r), input.Events)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not ingest events")
		return
	}
	writeJSON(w, http.StatusAccepted, newEnvelope(map[string]any{"accepted": accepted, "received": len(input.Events)}))
}

func (a *api) claimAdReward(w http.ResponseWriter, r *http.Request) {
	var input monetization.AdRequest
	if !decodeBody(w, r, &input) {
		return
	}
	result, err := a.deps.Money.ClaimAd(r.Context(), authenticatedUser(r), input)
	if errors.Is(err, monetization.ErrInvalidProof) || errors.Is(err, monetization.ErrVerifierUnavailable) {
		writeError(w, http.StatusUnprocessableEntity, "REWARD_NOT_VERIFIED", "ad reward could not be verified")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "ad reward failed")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(result))
}

func (a *api) verifyPurchase(w http.ResponseWriter, r *http.Request) {
	var input monetization.PurchaseRequest
	if !decodeBody(w, r, &input) {
		return
	}
	result, err := a.deps.Money.VerifyPurchase(r.Context(), authenticatedUser(r), input)
	if errors.Is(err, monetization.ErrInvalidProof) || errors.Is(err, monetization.ErrVerifierUnavailable) {
		writeError(w, http.StatusUnprocessableEntity, "PURCHASE_INVALID", "purchase could not be verified")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "purchase verification failed")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(result))
}

func (a *api) dailyChallenge(w http.ResponseWriter, r *http.Request) {
	marketID, _, _ := a.deps.Sessions.Profile(r.Context(), authenticatedUser(r))
	if marketID == "" {
		marketID = a.deps.Config.Market
	}
	item, err := a.deps.Operations.Daily(r.Context(), marketID)
	if errors.Is(err, operations.ErrNotFound) {
		writeError(w, http.StatusNotFound, "DAILY_CHALLENGE_NOT_FOUND", "daily challenge unavailable")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not load daily challenge")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(item))
}

func (a *api) activities(w http.ResponseWriter, r *http.Request) {
	marketID, _, _ := a.deps.Sessions.Profile(r.Context(), authenticatedUser(r))
	if marketID == "" {
		marketID = a.deps.Config.Market
	}
	items, err := a.deps.Operations.Activities(r.Context(), marketID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not load activities")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(map[string]any{"items": items}))
}

func (a *api) bindAccount(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Provider string `json:"provider"`
		Proof    string `json:"proof"`
	}
	if !decodeBody(w, r, &in) {
		return
	}
	result, err := a.deps.Accounts.Bind(r.Context(), authenticatedUser(r), in.Provider, in.Proof)
	if errors.Is(err, account.ErrInvalidProof) {
		writeError(w, 422, "ACCOUNT_PROOF_INVALID", "account proof could not be verified")
		return
	}
	if errors.Is(err, account.ErrAlreadyBound) {
		writeError(w, 409, "ACCOUNT_ALREADY_BOUND", "account belongs to another user")
		return
	}
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not bind account")
		return
	}
	writeJSON(w, 200, newEnvelope(result))
}

func (a *api) loginAccount(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Provider string `json:"provider"`
		Proof    string `json:"proof"`
	}
	if !decodeBody(w, r, &in) {
		return
	}
	user, err := a.deps.Accounts.Resolve(r.Context(), in.Provider, in.Proof)
	if errors.Is(err, account.ErrInvalidProof) {
		writeError(w, 401, "ACCOUNT_PROOF_INVALID", "account proof is invalid")
		return
	}
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not restore account")
		return
	}
	created, err := a.deps.Sessions.Issue(r.Context(), user)
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not issue session")
		return
	}
	writeJSON(w, 200, newEnvelope(map[string]any{"user_id": created.UserID, "access_token": created.AccessToken, "refresh_token": created.RefreshToken, "expires_in": 900}))
}

func (a *api) createReport(w http.ResponseWriter, r *http.Request) {
	var in struct {
		LevelID     string `json:"level_id"`
		Category    string `json:"category"`
		Description string `json:"description"`
	}
	if !decodeBody(w, r, &in) {
		return
	}
	valid := map[string]bool{"wrong_difference": true, "inappropriate": true, "copyright": true, "broken_asset": true, "other": true}
	if in.LevelID == "" || !valid[in.Category] || len(in.Description) > 500 {
		writeError(w, 400, "VALIDATION_FAILED", "invalid report")
		return
	}
	item, err := a.deps.Reports.Create(r.Context(), report.Item{ID: "rpt_" + newEnvelope(nil).RequestID, UserID: authenticatedUser(r), LevelID: in.LevelID, Category: in.Category, Description: in.Description})
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not create report")
		return
	}
	writeJSON(w, 201, newEnvelope(item))
}
func (a *api) adminReports(w http.ResponseWriter, r *http.Request) {
	items, err := a.deps.Reports.List(r.Context(), r.URL.Query().Get("status"))
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not list reports")
		return
	}
	writeJSON(w, 200, newEnvelope(map[string]any{"items": items}))
}
func (a *api) resolveReport(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Status string `json:"status"`
		Note   string `json:"note"`
	}
	if !decodeBody(w, r, &in) {
		return
	}
	err := a.deps.Reports.Resolve(r.Context(), r.PathValue("reportId"), in.Status, in.Note)
	if errors.Is(err, report.ErrNotFound) {
		writeError(w, 404, "REPORT_NOT_FOUND", "report not found")
		return
	}
	if errors.Is(err, report.ErrInvalidState) {
		writeError(w, 409, "INVALID_REPORT_STATE", "report status is invalid")
		return
	}
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not resolve report")
		return
	}
	writeJSON(w, 200, newEnvelope(map[string]any{"status": in.Status}))
}
func (a *api) metricsSummary(w http.ResponseWriter, r *http.Request) {
	item, err := a.deps.Metrics.Snapshot(r.Context())
	if err != nil {
		writeError(w, 500, "INTERNAL_ERROR", "could not load metrics")
		return
	}
	writeJSON(w, 200, newEnvelope(item))
}

func (a *api) experiment(w http.ResponseWriter, r *http.Request) {
	item, err := a.deps.Operations.Assign(r.Context(), authenticatedUser(r), r.PathValue("experimentKey"))
	if errors.Is(err, operations.ErrNotFound) {
		writeError(w, http.StatusNotFound, "EXPERIMENT_NOT_FOUND", "experiment unavailable")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not assign experiment")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(item))
}

func (a *api) createGenerationJob(w http.ResponseWriter, r *http.Request) {
	var input generation.CreateRequest
	if !decodeBody(w, r, &input) {
		return
	}
	if input.ID == "" {
		input.ID = "gen_" + newEnvelope(nil).RequestID
	}
	if input.Market == "" {
		input.Market = "global"
	}
	if input.PromptVersion == "" || input.Model == "" || input.Input == nil {
		writeError(w, http.StatusBadRequest, "VALIDATION_FAILED", "prompt_version, model and input are required")
		return
	}
	job, err := a.deps.Generation.Create(r.Context(), input)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not create generation job")
		return
	}
	writeJSON(w, http.StatusCreated, newEnvelope(job))
}

func (a *api) getGenerationJob(w http.ResponseWriter, r *http.Request) {
	job, err := a.deps.Generation.Get(r.Context(), r.PathValue("jobId"))
	if errors.Is(err, generation.ErrNotFound) {
		writeError(w, http.StatusNotFound, "GENERATION_JOB_NOT_FOUND", "generation job not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "could not load generation job")
		return
	}
	writeJSON(w, http.StatusOK, newEnvelope(job))
}

func (a *api) requireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		scheme, token, ok := strings.Cut(r.Header.Get("Authorization"), " ")
		if !ok || !strings.EqualFold(scheme, "Bearer") || token == "" {
			writeError(w, http.StatusUnauthorized, "UNAUTHENTICATED", "a bearer token is required")
			return
		}
		userID, authenticated := a.deps.Sessions.Authenticate(r.Context(), token)
		if !authenticated {
			writeError(w, http.StatusUnauthorized, "UNAUTHENTICATED", "the bearer token is invalid")
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), userContextKey{}, userID)))
	})
}

func (a *api) requireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		provided := r.Header.Get("X-Admin-Token")
		expected := a.deps.Config.AdminToken
		if len(provided) != len(expected) || subtle.ConstantTimeCompare([]byte(provided), []byte(expected)) != 1 {
			writeError(w, http.StatusUnauthorized, "ADMIN_UNAUTHENTICATED", "admin token is invalid")
			return
		}
		next.ServeHTTP(w, r)
	})
}

type userContextKey struct{}

func authenticatedUser(r *http.Request) string {
	value, _ := r.Context().Value(userContextKey{}).(string)
	return value
}

func (a *api) requestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		next.ServeHTTP(w, r)
		a.deps.Logger.Info("http request", "method", r.Method, "path", r.URL.Path, "duration_ms", time.Since(started).Milliseconds())
	})
}

func (a *api) recoverPanic(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				a.deps.Logger.Error("request panic", "error", fmt.Sprint(recovered))
				writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func newEnvelope(data any) envelope {
	requestID, err := randomRequestID()
	if err != nil {
		requestID = "request-id-unavailable"
	}
	return envelope{RequestID: requestID, ServerTime: time.Now().UTC().Format(time.RFC3339Nano), ConfigVersion: 1, Data: data}
}

func randomRequestID() (string, error) {
	buffer := make([]byte, 18)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buffer), nil
}

func validPlatform(platform string) bool {
	return platform == "ios" || platform == "android" || platform == "desktop"
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	response := map[string]any{"request_id": newEnvelope(nil).RequestID, "error_code": code, "message": message}
	writeJSON(w, status, response)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
