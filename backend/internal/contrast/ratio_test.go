package contrast

import (
	"math"
	"testing"
)

func TestRatioBlackWhite(t *testing.T) {
	ratio, err := Ratio("#000000", "#ffffff")
	if err != nil {
		t.Fatal(err)
	}
	if math.Abs(ratio-21.0) > 0.001 {
		t.Fatalf("got %.6f, want 21", ratio)
	}
}

func TestRatioSameColor(t *testing.T) {
	ratio, err := Ratio("#123456", "#123456")
	if err != nil {
		t.Fatal(err)
	}
	if math.Abs(ratio-1.0) > 0.001 {
		t.Fatalf("got %.6f, want 1", ratio)
	}
}
