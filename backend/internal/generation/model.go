package generation

type Variant string

const (
	Source   Variant = "source"
	Calm     Variant = "calm"
	Mute     Variant = "mute"
	Deep     Variant = "deep"
	Vibrant  Variant = "vibrant"
	Balanced Variant = "Balanced"
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
}

type VariantResult struct {
	Variant Variant `json:"variant"`
	Path    string  `json:"path"`
}

type Result struct {
	GenerationID string          `json:"generation_id"`
	Variants     []VariantResult `json:"variants"`
}
