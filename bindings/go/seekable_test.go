package seekable

import (
	"io"
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

	// Test ReadRange
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

	// Test ReadAt
	buf := make([]byte, 5)
	n, err := r.ReadAt(buf, 0)
	if err != nil {
		t.Fatalf("ReadAt(0) failed: %v", err)
	}
	if n != 5 {
		t.Errorf("Expected n=5, got %d", n)
	}
	if string(buf) != "Hello" {
		t.Errorf("Expected 'Hello', got '%s'", string(buf))
	}

	// Test ReadAt Offset
	n, err = r.ReadAt(buf, 6)
	if err != nil {
		t.Fatalf("ReadAt(6) failed: %v", err)
	}
	if n != 5 {
		t.Errorf("Expected n=5, got %d", n)
	}
	if string(buf) != "World" {
		t.Errorf("Expected 'World', got '%s'", string(buf))
	}

	// Test EOF
	n, err = r.ReadAt(buf, 11)
	if err != io.EOF {
		t.Errorf("Expected EOF at end, got %v", err)
	}
	if n != 0 {
		t.Errorf("Expected n=0 at EOF, got %d", n)
	}
}
