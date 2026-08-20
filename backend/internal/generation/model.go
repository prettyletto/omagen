package generation

type Variant string

const (
	Source   Variant = "source"
	Calm     Variant = "calm"
	Mute     Variant = "mute"
	Deep     Variant = "deep"
	Vibrant  Variant = "vibrant"
	Balanced Variant = "balanced"
)

var orderedVariants = [...]Variant{
	Source,
	Calm,
	Mute,
	Deep,
	Vibrant,
	Balanced,
}

type Request struct {
	SessionID   string
	SourceImage string
	Options     Options
}

type VariantResult struct {
	Variant Variant `json:"variant"`
	Path    string  `json:"path"`
}

type Result struct {
	GenerationID string          `json:"generation_id"`
	Options      Options         `json:"options"`
	Variants     []VariantResult `json:"variants"`
}
