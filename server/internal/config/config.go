package config

import (
	"fmt"
	"log/slog"
	"os"
	"strings"
)

const DevelopmentInstallationHMACKey = "oddspot-development-test-hmac-key-2026"

type Config struct {
	Environment         string
	HTTPAddr            string
	LogLevel            slog.Level
	Market              string
	Locale              string
	DatabaseDSN         string
	InstallationHMACKey string
	AdminToken          string
	ContentDir          string
	AdminDir            string
	PublicBaseURL       string
	UserServerBaseURL   string
	UserServerAppID     string
	CORSAllowedOrigins  []string
	RemoteLocalesJSON   string
	GeoCountryHeader    string
}

func FromEnv() (Config, error) {
	cfg := Config{
		Environment:         valueOrDefault("ODDSPOT_ENV", "development"),
		HTTPAddr:            valueOrDefault("ODDSPOT_HTTP_ADDR", "127.0.0.1:8080"),
		Market:              valueOrDefault("ODDSPOT_DEFAULT_MARKET", "global"),
		Locale:              valueOrDefault("ODDSPOT_DEFAULT_LOCALE", "en-US"),
		DatabaseDSN:         os.Getenv("ODDSPOT_DATABASE_DSN"),
		InstallationHMACKey: os.Getenv("ODDSPOT_INSTALLATION_HMAC_KEY"),
		AdminToken:          os.Getenv("ODDSPOT_ADMIN_TOKEN"),
		ContentDir:          valueOrDefault("ODDSPOT_CONTENT_DIR", "./storage/content"),
		AdminDir:            valueOrDefault("ODDSPOT_ADMIN_DIR", "../admin"),
		PublicBaseURL:       strings.TrimRight(valueOrDefault("ODDSPOT_PUBLIC_BASE_URL", "http://127.0.0.1:8080"), "/"),
		UserServerBaseURL:   strings.TrimRight(valueOrDefault("ODDSPOT_USER_SERVER_BASE_URL", "https://api.guaguatu.com"), "/"),
		UserServerAppID:     valueOrDefault("ODDSPOT_USER_SERVER_APP_ID", "game_odd_spot"),
		CORSAllowedOrigins:  splitCSV(valueOrDefault("ODDSPOT_CORS_ALLOWED_ORIGINS", "http://localhost:8000,http://127.0.0.1:8000")),
		RemoteLocalesJSON:   os.Getenv("ODDSPOT_REMOTE_LOCALES_JSON"),
		GeoCountryHeader:    valueOrDefault("ODDSPOT_GEO_COUNTRY_HEADER", "CF-IPCountry"),
	}

	switch strings.ToLower(valueOrDefault("ODDSPOT_LOG_LEVEL", "info")) {
	case "debug":
		cfg.LogLevel = slog.LevelDebug
	case "info":
		cfg.LogLevel = slog.LevelInfo
	case "warn":
		cfg.LogLevel = slog.LevelWarn
	case "error":
		cfg.LogLevel = slog.LevelError
	default:
		return Config{}, fmt.Errorf("ODDSPOT_LOG_LEVEL must be debug, info, warn, or error")
	}
	if cfg.Environment == "development" && cfg.InstallationHMACKey == "" {
		cfg.InstallationHMACKey = DevelopmentInstallationHMACKey
	}
	if cfg.Environment == "development" && cfg.AdminToken == "" {
		cfg.AdminToken = "oddspot-development-admin-token"
	}

	if !strings.Contains(cfg.HTTPAddr, ":") {
		return Config{}, fmt.Errorf("ODDSPOT_HTTP_ADDR must contain host and port")
	}
	if cfg.DatabaseDSN != "" && len(cfg.InstallationHMACKey) < 32 {
		return Config{}, fmt.Errorf("ODDSPOT_INSTALLATION_HMAC_KEY must contain at least 32 characters when MySQL is enabled")
	}
	if cfg.Environment == "production" && cfg.DatabaseDSN == "" {
		return Config{}, fmt.Errorf("ODDSPOT_DATABASE_DSN is required in production")
	}
	if cfg.Environment == "production" && cfg.InstallationHMACKey == DevelopmentInstallationHMACKey {
		return Config{}, fmt.Errorf("the development installation HMAC key is forbidden in production")
	}
	if cfg.Environment == "production" && len(cfg.AdminToken) < 32 {
		return Config{}, fmt.Errorf("ODDSPOT_ADMIN_TOKEN must contain at least 32 characters in production")
	}
	return cfg, nil
}

func valueOrDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func splitCSV(value string) []string {
	result := []string{}
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			result = append(result, strings.TrimRight(item, "/"))
		}
	}
	return result
}
