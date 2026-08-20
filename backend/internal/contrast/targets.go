package contrast

import "fmt"

type Targets struct {
	PrimaryText   float64 `json:"primary_text"`
	BrightText    float64 `json:"bright_text"`
	SecondaryText float64 `json:"secondary_text"`
	UIElement     float64 `json:"ui_element"`
	SelectionText float64 `json:"selection_text"`
	ANSI          float64 `json:"ansi"`
	BrightANSI    float64 `json:"bright_ansi"`
}

func (t Targets) Validate() error {
	values := []struct {
		name  string
		value float64
	}{
		{"primary_text", t.PrimaryText},
		{"bright_text", t.BrightText},
		{"secondary_text", t.SecondaryText},
		{"ui_element", t.UIElement},
		{"selection_text", t.SelectionText},
		{"ansi", t.ANSI},
		{"bright_ansi", t.BrightANSI},
	}

	for _, item := range values {
		if item.value < 1 || item.value > 21 {
			return fmt.Errorf(
				"%s contrast must be between 1 and 21, got %.2f",
				item.name,
				item.value,
			)
		}
	}

	return nil
}
