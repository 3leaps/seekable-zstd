GONEAT := ./bin/goneat

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)

# Fix arch names
ifeq ($(ARCH),x86_64)
	ARCH = amd64
endif
ifeq ($(ARCH),aarch64)
	ARCH = arm64
endif

LIB_DIR := bindings/go/lib/$(OS)-$(ARCH)

# Quality gates
.PHONY: quality
quality: format-check lint test-fast

.PHONY: format
format:
	cargo fmt
	cd bindings/go && go fmt ./...

.PHONY: format-check
format-check:
	cargo fmt -- --check
	# Check if go fmt would make changes
	@if [ -n "$$(cd bindings/go && go fmt ./...)" ]; then echo "Go code needs formatting"; exit 1; fi

.PHONY: lint
lint:
	cargo clippy -- -D warnings
	cd bindings/go && go vet ./...

.PHONY: test-fast
test-fast:
	cargo test --lib

.PHONY: test
test: test-rust test-go

.PHONY: test-rust
test-rust:
	cargo test

.PHONY: test-go
test-go: build-rust-lib
	cd bindings/go && go test ./...

.PHONY: build-rust-lib
build-rust-lib:
	mkdir -p $(LIB_DIR)
	cargo build --release
	cp target/release/libseekable_zstd_core.a $(LIB_DIR)/libseekable_zstd_core.a

# Hook management
.PHONY: hooks-generate
hooks-generate:
	$(GONEAT) hooks generate

.PHONY: hooks-install
hooks-install: hooks-generate
	$(GONEAT) hooks install

.PHONY: hooks-remove
hooks-remove:
	@rm -f .git/hooks/pre-commit .git/hooks/pre-push

# Bootstrap
.PHONY: bootstrap
bootstrap: 
	./scripts/bootstrap-tools.sh
	$(MAKE) hooks-install
	@echo "Checking required tools..."
	@command -v rustc >/dev/null 2>&1 || (echo "rustc required" && exit 1)
	@command -v cargo >/dev/null 2>&1 || (echo "cargo required" && exit 1)
	@command -v go >/dev/null 2>&1 || (echo "go required" && exit 1)
	rustup component add rustfmt clippy
	@echo "Bootstrap complete"
