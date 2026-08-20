package contrast

import "testing"

func TestAdjustLightnessLighter(t *testing.T) {
	got, err := adjustLightness("#444444", "#222222", 4.5, lighter)
	if err != nil {
		t.Fatal(err)
	}
	ratio, err := Ratio(got, "#222222")
	if err != nil {
		t.Fatal(err)
	}
	if ratio < 4.5 {
		t.Fatalf("ratio %.4f is below 4.5; color=%s", ratio, got)
	}
}

func TestAdjustLightnessDarker(t *testing.T) {
	got, err := adjustLightness("#dddddd", "#ffffff", 4.5, darker)
	if err != nil {
		t.Fatal(err)
	}
	ratio, err := Ratio(got, "#ffffff")
	if err != nil {
		t.Fatal(err)
	}
	if ratio < 4.5 {
		t.Fatalf("ratio %.4f is below 4.5; color=%s", ratio, got)
	}
}
