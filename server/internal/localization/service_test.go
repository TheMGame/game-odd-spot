package localization

import "testing"

func TestNormalizeBuiltins(t *testing.T) {
	tests := map[string]string{
		"zh": "zh-CN", "zh_CN": "zh-CN", "zh-Hans-CN": "zh-CN",
		"en": "en-US", "en_US": "en-US",
	}
	for input, expected := range tests {
		if actual := Normalize(input); actual != expected {
			t.Fatalf("Normalize(%q)=%q, want %q", input, actual, expected)
		}
	}
}

func TestRemoteLocaleCountryMapping(t *testing.T) {
	service, err := New(`[{"locale":"fr-FR","display_name":"French","native_name":"Français","builtin":false,"version":2,"country_codes":["FR"],"download_url":"https://cdn.example/fr.pck","sha256":"abc","size_bytes":42,"resource_path":"res://i18n/fr_FR.translation"}]`)
	if err != nil {
		t.Fatal(err)
	}
	locale, source := service.DefaultForCountry("fr", "en-US")
	if locale != "fr-FR" || source != "geoip" || !service.RequiresDownload(locale) {
		t.Fatalf("resolved locale=%q source=%q download=%v", locale, source, service.RequiresDownload(locale))
	}
}
