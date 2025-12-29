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

func TestEncoderRoundtrip(t *testing.T) {
	tmpFile := filepath.Join(t.TempDir(), "test.szst")

	encoder, err := NewEncoder(tmpFile, 0)
	if err != nil {
		t.Fatalf("NewEncoder failed: %v", err)
	}

	testData := []byte("Hello, seekable zstd!")
	if _, err := encoder.Write(testData); err != nil {
		_ = encoder.Close()
		t.Fatalf("Write failed: %v", err)
	}

	compressedSize, err := encoder.Finish()
	if err != nil {
		t.Fatalf("Finish failed: %v", err)
	}
	if compressedSize <= 0 {
		t.Fatalf("expected compressedSize > 0, got %d", compressedSize)
	}

	r, err := Open(tmpFile)
	if err != nil {
		t.Fatalf("Open failed: %v", err)
	}
	defer r.Close()

	if r.Size() != uint64(len(testData)) {
		t.Fatalf("expected size %d, got %d", len(testData), r.Size())
	}

	got, err := r.ReadRange(0, uint64(len(testData)))
	if err != nil {
		t.Fatalf("ReadRange failed: %v", err)
	}
	if string(got) != string(testData) {
		t.Fatalf("expected %q, got %q", string(testData), string(got))
	}
}

func TestEncoderLargeFileRandomAccess(t *testing.T) {
	tmpFile := filepath.Join(t.TempDir(), "large.szst")

	encoder, err := NewEncoder(tmpFile, 64*1024)
	if err != nil {
		t.Fatalf("NewEncoder failed: %v", err)
	}

	data := make([]byte, 1024*1024)
	for i := range data {
		data[i] = byte(i % 256)
	}

	if _, err := encoder.Write(data); err != nil {
		_ = encoder.Close()
		t.Fatalf("Write failed: %v", err)
	}

	if _, err := encoder.Finish(); err != nil {
		t.Fatalf("Finish failed: %v", err)
	}

	r, err := Open(tmpFile)
	if err != nil {
		t.Fatalf("Open failed: %v", err)
	}
	defer r.Close()

	start := uint64(500_000)
	end := uint64(500_100)
	got, err := r.ReadRange(start, end)
	if err != nil {
		t.Fatalf("ReadRange failed: %v", err)
	}

	want := data[start:end]
	if len(got) != len(want) {
		t.Fatalf("expected len %d, got %d", len(want), len(got))
	}

	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("byte mismatch at %d: expected %d, got %d", i, want[i], got[i])
		}
	}
}

func TestEncoderEmptyFile(t *testing.T) {
	tmpFile := filepath.Join(t.TempDir(), "empty.szst")

	encoder, err := NewEncoder(tmpFile, 0)
	if err != nil {
		t.Fatalf("NewEncoder failed: %v", err)
	}

	if _, err := encoder.Finish(); err != nil {
		t.Fatalf("Finish failed: %v", err)
	}

	r, err := Open(tmpFile)
	if err != nil {
		t.Fatalf("Open failed: %v", err)
	}
	defer r.Close()

	if r.Size() != 0 {
		t.Fatalf("expected size 0, got %d", r.Size())
	}
}

func TestEncoderAbort(t *testing.T) {
	tmpFile := filepath.Join(t.TempDir(), "aborted.szst")

	encoder, err := NewEncoder(tmpFile, 0)
	if err != nil {
		t.Fatalf("NewEncoder failed: %v", err)
	}

	if _, err := encoder.Write([]byte("partial")); err != nil {
		_ = encoder.Close()
		t.Fatalf("Write failed: %v", err)
	}

	if err := encoder.Close(); err != nil {
		t.Fatalf("Close failed: %v", err)
	}

	if _, err := Open(tmpFile); err == nil {
		t.Fatalf("expected Open to fail after abort")
	}
}
