package colorspace

import "testing"

func TestHexFromOKLCHRoundTrip(t *testing.T) {
	tests := []struct {
		name    string
		r, g, b uint8
		want    string
	}{
		{name: "red", r: 255, want: "#ff0000"},
		{name: "green", g: 255, want: "#00ff00"},
		{name: "blue", b: 255, want: "#0000ff"},
		{name: "tokyo night background", r: 0x1a, g: 0x1b, b: 0x26, want: "#1a1b26"},
		{name: "tokyo night blue", r: 0x7a, g: 0xa2, b: 0xf7, want: "#7aa2f7"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			lab := FromSRGB8(test.r, test.g, test.b)
			if got := HexFromOKLCH(lab.ToOKLCH()); got != test.want {
				t.Fatalf("got %s, want %s", got, test.want)
			}
		})
	}
}
