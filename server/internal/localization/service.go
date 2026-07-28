package localization

import (
	"encoding/json"
	"errors"
	"strings"
)

var ErrUnsupported = errors.New("locale not supported")

type Locale struct {
	Locale       string   `json:"locale"`
	DisplayName  string   `json:"display_name"`
	NativeName   string   `json:"native_name"`
	Builtin      bool     `json:"builtin"`
	Version      int      `json:"version"`
	CountryCodes []string `json:"country_codes"`
	DownloadURL  string   `json:"download_url,omitempty"`
	SHA256       string   `json:"sha256,omitempty"`
	SizeBytes    int64    `json:"size_bytes,omitempty"`
	ResourcePath string   `json:"resource_path,omitempty"`
}

type Service struct {
	items     []Locale
	byLocale  map[string]Locale
	byCountry map[string]string
}

func New(remoteJSON string) (*Service, error) {
	items := []Locale{
		{Locale: "zh-CN", DisplayName: "Simplified Chinese", NativeName: "简体中文", Builtin: true, Version: 1, CountryCodes: []string{"CN"}},
		{Locale: "en-US", DisplayName: "English", NativeName: "English", Builtin: true, Version: 1, CountryCodes: []string{}},
	}
	if strings.TrimSpace(remoteJSON) != "" {
		var remote []Locale
		if err := json.Unmarshal([]byte(remoteJSON), &remote); err != nil {
			return nil, err
		}
		items = append(items, remote...)
	}
	service := &Service{items: items, byLocale: map[string]Locale{}, byCountry: map[string]string{}}
	for _, item := range items {
		item.Locale = Normalize(item.Locale)
		if item.Locale == "" || item.Version < 1 {
			return nil, errors.New("locale and positive version are required")
		}
		if !item.Builtin && (item.DownloadURL == "" || item.SHA256 == "" || item.SizeBytes <= 0 || item.ResourcePath == "") {
			return nil, errors.New("remote locale requires download_url, sha256, size_bytes and resource_path")
		}
		if _, duplicate := service.byLocale[item.Locale]; duplicate {
			return nil, errors.New("duplicate locale " + item.Locale)
		}
		service.byLocale[item.Locale] = item
		for _, country := range item.CountryCodes {
			service.byCountry[strings.ToUpper(strings.TrimSpace(country))] = item.Locale
		}
	}
	service.items = make([]Locale, 0, len(service.byLocale))
	for _, original := range items {
		service.items = append(service.items, service.byLocale[Normalize(original.Locale)])
	}
	return service, nil
}

func Normalize(value string) string {
	value = strings.TrimSpace(value)
	normalized := strings.ReplaceAll(strings.ToLower(value), "_", "-")
	switch normalized {
	case "zh", "zh-cn", "zh-hans", "zh-hans-cn":
		return "zh-CN"
	case "en", "en-us":
		return "en-US"
	default:
		parts := strings.Split(normalized, "-")
		if len(parts) == 2 && len(parts[0]) == 2 && len(parts[1]) == 2 {
			return parts[0] + "-" + strings.ToUpper(parts[1])
		}
		return value
	}
}

func (s *Service) List() []Locale {
	return append([]Locale(nil), s.items...)
}

func (s *Service) Validate(value string) (string, error) {
	normalized := Normalize(value)
	if _, ok := s.byLocale[normalized]; !ok {
		return "", ErrUnsupported
	}
	return normalized, nil
}

func (s *Service) DefaultForCountry(country, fallback string) (string, string) {
	if locale, ok := s.byCountry[strings.ToUpper(strings.TrimSpace(country))]; ok {
		return locale, "geoip"
	}
	if normalized, err := s.Validate(fallback); err == nil {
		return normalized, "fallback"
	}
	return "en-US", "fallback"
}

func (s *Service) RequiresDownload(locale string) bool {
	item, ok := s.byLocale[Normalize(locale)]
	return ok && !item.Builtin
}
