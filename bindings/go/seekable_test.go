package seekable

import (
	"os"
	"path/filepath"
	"testing"
)

func TestOpen(t *testing.T) {
	// Locate fixture
	wd, _ := os.Getwd()
	// bindings/go -> ../../tests/fixtures/hello.szst
	fixturePath := filepath.Join(wd, "../../tests/fixtures/hello.szst")

	if _, err := os.Stat(fixturePath); os.IsNotExist(err) {
		t.Fatalf("Fixture not found at %s", fixturePath)
	}

	r, err := Open(fixturePath)
	if err != nil {
		t.Fatalf("Failed to open %s: %v", fixturePath, err)
	}
	defer r.Close()

	// "Hello World" is 11 bytes
	if r.Size() != 11 {
		t.Errorf("Expected size 11, got %d", r.Size())
	}

	data, err := r.ReadRange(0, 5)
	if err != nil {
		t.Fatalf("ReadRange(0, 5) failed: %v", err)
	}
	if string(data) != "Hello" {
		t.Errorf("Expected 'Hello', got '%s'", string(data))
	}

	data, err = r.ReadRange(6, 11)
	if err != nil {
		t.Fatalf("ReadRange(6, 11) failed: %v", err)
	}
	if string(data) != "World" {
		t.Errorf("Expected 'World', got '%s'", string(data))
	}
}
