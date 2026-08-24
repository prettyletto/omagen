package demo

import "testing"

func TestWindowDemoGeometryBalancesStackedTUI(t *testing.T) {
	monitor := monitorInfo{Name: "eDP-1", Width: 1920, Height: 1200, X: 0, Y: 0}
	width, height, x, y := windowDemoActiveGeometry(monitor)
	if width != 902 || height != 744 || x != 32 || y != 80 {
		t.Fatalf("active geometry = %d,%d at %d,%d; want 902,744 at 32,80", width, height, x, y)
	}

	inactiveY := y + height + 20
	inactiveHeight := monitor.Height * 22 / 100
	if inactiveY != 844 || inactiveHeight != 264 {
		t.Fatalf("inactive geometry = %d,%d; want 844,264", inactiveY, inactiveHeight)
	}
	if inactiveY+inactiveHeight >= monitor.Height-32 {
		t.Fatalf("stacked demo does not leave bottom margin: bottom=%d", inactiveY+inactiveHeight)
	}
}
