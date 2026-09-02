package barprofile

import (
	"encoding/json"
	"testing"
)

func TestProfileNormalizesAndValidates(t *testing.T) {
	profile := (Profile{Ownership: OwnershipOverlay, Implementation: ImplementationAdapter, Bar: json.RawMessage(`{"bar":true}`)}).Normalize()
	if err := profile.Validate(); err != nil {
		t.Fatal(err)
	}
	if profile.Behavior.Visibility != "always" || profile.Behavior.Workspace != "native" {
		t.Fatalf("defaults not applied: %#v", profile.Behavior)
	}
}

func TestReplacementCannotInherit(t *testing.T) {
	profile := Profile{Implementation: ImplementationReplacement}
	if err := profile.Validate(); err == nil {
		t.Fatal("replacement profile inherited ownership")
	}
}
