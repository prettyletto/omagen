package processutil

import (
	"strings"
	"testing"
)

func TestLimitedBufferConsumesAndMarksOverflow(t *testing.T) {
	buffer := NewLimitedBuffer(4)
	n, err := buffer.Write([]byte("abcdef"))
	if err != nil || n != 6 {
		t.Fatalf("Write() = (%d, %v), want consumed input", n, err)
	}
	if buffer.String() != "abcd" || !buffer.Truncated() {
		t.Fatalf("buffer = %q truncated=%v", buffer.String(), buffer.Truncated())
	}
}

func TestLimitedBufferPreservesUTF8BytesAsWritten(t *testing.T) {
	buffer := NewLimitedBuffer(5)
	_, _ = buffer.Write([]byte("ééé"))
	if !strings.HasPrefix(buffer.String(), "éé") || !buffer.Truncated() {
		t.Fatalf("buffer = %q truncated=%v", buffer.String(), buffer.Truncated())
	}
}
