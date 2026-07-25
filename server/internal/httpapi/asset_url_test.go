package httpapi

import (
	"encoding/json"
	"testing"

	"game-odd-spot/server/internal/catalog"
)

func TestNormalizeCatalogAssetURLsUsesConfiguredPublicBase(t *testing.T) {
	items := []catalog.Series{{
		CoverURL: "http://127.0.0.1:8080/content/cover.png",
		Levels: []catalog.Level{{
			ThumbnailURL: "http://127.0.0.1:8080/content/level-thumb.jpg",
		}},
	}}

	normalizeCatalogAssetURLs(items, "https://oddspot.guaguatu.com/")

	if got := items[0].CoverURL; got != "https://oddspot.guaguatu.com/content/cover.png" {
		t.Fatalf("cover URL = %q", got)
	}
	if got := items[0].Levels[0].ThumbnailURL; got != "https://oddspot.guaguatu.com/content/level-thumb.jpg" {
		t.Fatalf("thumbnail URL = %q", got)
	}
}

func TestNormalizeRuntimeAssetURLsRewritesOnlyContentURLs(t *testing.T) {
	raw := json.RawMessage(`{
		"assets": {
			"image": {
				"url": "http://127.0.0.1:8080/content/image.png",
				"thumbnail": {"url": "http://old.example/content/image-thumb.jpg"}
			}
		},
		"reference_url": "https://example.com/reference"
	}`)

	normalized := normalizeRuntimeAssetURLs(raw, "https://oddspot.guaguatu.com")
	var value map[string]any
	if err := json.Unmarshal(normalized, &value); err != nil {
		t.Fatal(err)
	}
	assets := value["assets"].(map[string]any)["image"].(map[string]any)
	if got := assets["url"]; got != "https://oddspot.guaguatu.com/content/image.png" {
		t.Fatalf("image URL = %q", got)
	}
	thumbnail := assets["thumbnail"].(map[string]any)
	if got := thumbnail["url"]; got != "https://oddspot.guaguatu.com/content/image-thumb.jpg" {
		t.Fatalf("thumbnail URL = %q", got)
	}
	if got := value["reference_url"]; got != "https://example.com/reference" {
		t.Fatalf("external URL changed to %q", got)
	}
}
