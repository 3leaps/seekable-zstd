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
	# Check Python linting (if ruff is installed)
	if command -v ruff >/dev/null; then ruff check crates/seekable-zstd-py; fi
	# Check Node.js (if npm is installed)
	if command -v npm >/dev/null && [ -d bindings/nodejs/node_modules ]; then \
		cd bindings/nodejs && npm run build; \
	fi

.PHONY: test-fast
test-fast:
	cargo test --lib

.PHONY: test
test: test-rust test-go test-python test-node

.PHONY: test-rust
test-rust:
	cargo test

.PHONY: test-go
test-go: build-rust-lib
	cd bindings/go && go test ./...

.PHONY: test-python
test-python:
	# Requires dev dependencies installed via uv or pip
	if command -v pytest >/dev/null; then \
		cd crates/seekable-zstd-py && maturin develop && pytest; \
	else \
		echo "Skipping Python tests (pytest not found)"; \
	fi

.PHONY: test-node
test-node:
	# Requires npm dependencies
	if command -v npm >/dev/null && [ -d bindings/nodejs/node_modules ]; then \
		cd bindings/nodejs && npm test; \
	else \
		echo "Skipping Node.js tests (npm modules not installed)"; \
	fi

.PHONY: build-rust-lib
build-rust-lib:
	mkdir -p $(LIB_DIR)
	cargo build --release -p seekable-zstd-core
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

# Build targets
.PHONY: build
build: build-rust-lib
	@echo "Build complete"

.PHONY: clean
clean:
	cargo clean
	rm -rf bindings/go/lib/*/libseekable_zstd_core.a
	rm -rf bindings/nodejs/target
	rm -rf crates/seekable-zstd-py/.venv
	rm -rf crates/seekable-zstd-py/target
	@echo "Clean complete"

# Benchmarks
.PHONY: bench
bench:
	cargo bench

# Version bumping (updates all package versions)
.PHONY: bump-patch
bump-patch:
	@echo "Bumping patch version..."
	@VERSION=$$(cat VERSION); \
	MAJOR=$$(echo $$VERSION | cut -d. -f1); \
	MINOR=$$(echo $$VERSION | cut -d. -f2); \
	PATCH=$$(echo $$VERSION | cut -d. -f3); \
	NEW_VERSION="$$MAJOR.$$MINOR.$$((PATCH + 1))"; \
	echo "$$VERSION -> $$NEW_VERSION"; \
	echo "$$NEW_VERSION" > VERSION; \
	$(MAKE) _set-version VERSION=$$NEW_VERSION

.PHONY: bump-minor
bump-minor:
	@echo "Bumping minor version..."
	@VERSION=$$(cat VERSION); \
	MAJOR=$$(echo $$VERSION | cut -d. -f1); \
	MINOR=$$(echo $$VERSION | cut -d. -f2); \
	NEW_VERSION="$$MAJOR.$$((MINOR + 1)).0"; \
	echo "$$VERSION -> $$NEW_VERSION"; \
	echo "$$NEW_VERSION" > VERSION; \
	$(MAKE) _set-version VERSION=$$NEW_VERSION

.PHONY: bump-major
bump-major:
	@echo "Bumping major version..."
	@VERSION=$$(cat VERSION); \
	MAJOR=$$(echo $$VERSION | cut -d. -f1); \
	NEW_VERSION="$$((MAJOR + 1)).0.0"; \
	echo "$$VERSION -> $$NEW_VERSION"; \
	echo "$$NEW_VERSION" > VERSION; \
	$(MAKE) _set-version VERSION=$$NEW_VERSION

.PHONY: _set-version
_set-version:
	@if [ -z "$(VERSION)" ]; then echo "VERSION not set"; exit 1; fi
	# Update Rust crates (using cargo-edit if available would be cleaner, but sed works for now)
	# macOS sed requires empty string for -i
	sed -i '' 's/^version = ".*"/version = "$(VERSION)"/' crates/seekable-zstd-core/Cargo.toml
	sed -i '' 's/^version = ".*"/version = "$(VERSION)"/' crates/seekable-zstd-py/Cargo.toml
	sed -i '' 's/^version = ".*"/version = "$(VERSION)"/' bindings/nodejs/Cargo.toml
	
	# Update Node.js package.json
	sed -i '' 's/"version": ".*"/"version": "$(VERSION)"/' bindings/nodejs/package.json
	
	# Update Python pyproject.toml
	sed -i '' 's/^version = ".*"/version = "$(VERSION)"/' crates/seekable-zstd-py/pyproject.toml
	
	# Update Go binding documentation (Go versioning is via git tags, but docs reference it)
	# Also update the Version() constant in seekable.go
	sed -i '' 's/return ".*"/return "$(VERSION)"/' bindings/go/seekable.go
	
	@echo "Updated all versions to $(VERSION)"

