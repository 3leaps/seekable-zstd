# Tool installation (user-space bin dir; overridable with BINDIR=...)
#
# Defaults:
# - macOS/Linux: $HOME/.local/bin
# - Windows (Git Bash / MSYS / MINGW / Cygwin): %USERPROFILE%\\bin (or $HOME/bin)
BINDIR ?=
BINDIR_RESOLVE = \
	BINDIR="$(BINDIR)"; \
	if [ -z "$$BINDIR" ]; then \
		OS_RAW="$$(uname -s 2>/dev/null || echo unknown)"; \
		case "$$OS_RAW" in \
			MINGW*|MSYS*|CYGWIN*) \
				if [ -n "$$USERPROFILE" ]; then \
					if command -v cygpath >/dev/null 2>&1; then \
						BINDIR="$$(cygpath -u "$$USERPROFILE")/bin"; \
					else \
						BINDIR="$$USERPROFILE/bin"; \
					fi; \
				elif [ -n "$$HOME" ]; then \
					BINDIR="$$HOME/bin"; \
				else \
					BINDIR="./bin"; \
				fi ;; \
			*) \
				if [ -n "$$HOME" ]; then \
					BINDIR="$$HOME/.local/bin"; \
				else \
					BINDIR="./bin"; \
				fi ;; \
		esac; \
	fi

# Tooling (installed into user-space bindir)
GONEAT_VERSION ?= v0.3.20
GONEAT := goneat

SFETCH_RESOLVE = \
	$(BINDIR_RESOLVE); \
	SFETCH=""; \
	if [ -x "$$BINDIR/sfetch" ]; then SFETCH="$$BINDIR/sfetch"; fi; \
	if [ -z "$$SFETCH" ]; then SFETCH="$$(command -v sfetch 2>/dev/null || true)"; fi

GONEAT_RESOLVE = \
	$(BINDIR_RESOLVE); \
	GONEAT_BIN=""; \
	if [ -x "$$BINDIR/goneat" ]; then GONEAT_BIN="$$BINDIR/goneat"; fi; \
	if [ -z "$$GONEAT_BIN" ]; then GONEAT_BIN="$$(command -v goneat 2>/dev/null || true)"; fi

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)

# macOS builds: target older deployment for broad compatibility.
ifeq ($(OS),darwin)
	BUILD_RUST_ENV := MACOSX_DEPLOYMENT_TARGET=11.0
else
	BUILD_RUST_ENV :=
endif

# Fix arch names
ifeq ($(ARCH),x86_64)
	ARCH = amd64
endif
ifeq ($(ARCH),aarch64)
	ARCH = arm64
endif

PREBUILT_LIB_ROOT := bindings/go/lib
LOCAL_LIB_ROOT := $(PREBUILT_LIB_ROOT)/local

GO_TAGS ?=

GO_TAGS_ARG :=
ifneq ($(strip $(GO_TAGS)),)
	GO_TAGS_ARG := -tags "$(GO_TAGS)"
endif

GO_LIB_SUFFIX :=
ifneq (,$(findstring musl,$(GO_TAGS)))
	GO_LIB_SUFFIX := -musl
endif

RUST_TARGET ?=

LIB_DIR := $(LOCAL_LIB_ROOT)/$(OS)-$(ARCH)$(GO_LIB_SUFFIX)

# Quality gates
.PHONY: quality
quality: format-check lint test-fast

.PHONY: quality-rust
quality-rust: format-check-rust lint-rust test-fast

.PHONY: format
format:
	cargo fmt
	cd bindings/go && go fmt ./...
	# Python formatting with ruff (via uvx)
	uvx ruff format crates/seekable-zstd-py
	# TypeScript/JavaScript formatting with biome
	cd bindings/nodejs && npx @biomejs/biome format --write .

.PHONY: format-check
format-check:
	cargo fmt -- --check
	# Check if go fmt would make changes
	@if [ -n "$$(cd bindings/go && go fmt ./...)" ]; then echo "Go code needs formatting"; exit 1; fi
	# Check Python formatting with ruff (via uvx)
	uvx ruff format --check crates/seekable-zstd-py
	# Check TypeScript/JavaScript formatting with biome (no write)
	cd bindings/nodejs && npx @biomejs/biome check --javascript-linter-enabled=false .
	$(MAKE) format-check-md

.PHONY: format-check-rust
format-check-rust:
	cargo fmt -- --check

.PHONY: lint
lint:
	cargo clippy -- -D warnings
	cd bindings/go && go vet ./...
	# Python linting with ruff (via uvx)
	uvx ruff check crates/seekable-zstd-py
	# TypeScript/JavaScript linting with biome
	cd bindings/nodejs && npx @biomejs/biome lint .
	# Check Node.js build (if npm is installed)
	if command -v npm >/dev/null && [ -d bindings/nodejs/node_modules ]; then \
		cd bindings/nodejs && npm run build; \
	fi

.PHONY: lint-actions
lint-actions:
	@command -v yamllint >/dev/null 2>&1 || (echo "❌ yamllint not found. Run 'make bootstrap' or 'goneat doctor tools --scope foundation --install --yes'" && exit 1)
	@command -v actionlint >/dev/null 2>&1 || (echo "❌ actionlint not found. Run 'make bootstrap' or 'goneat doctor tools --scope foundation --install --yes'" && exit 1)
	yamllint .github/workflows/*.yml .goneat/tools.yaml .yamllint
	actionlint .github/workflows/*.yml

.PHONY: ci-preflight
ci-preflight:
	@set -eu; \
	TOOLCHAIN="$${TOOLCHAIN:-1.88.0}"; \
	if ! command -v rustup >/dev/null 2>&1; then echo "❌ rustup not found"; exit 1; fi; \
	echo "→ Installing Rust toolchain $$TOOLCHAIN (minimal)..."; \
	rustup toolchain install "$$TOOLCHAIN" --profile minimal >/dev/null; \
	tmp="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp"' EXIT; \
	echo "→ Preflight cargo check with $$TOOLCHAIN"; \
	CARGO_TARGET_DIR="$$tmp" cargo +"$$TOOLCHAIN" check -p seekable-zstd-core -p seekable-zstd-node --all-targets

.PHONY: lint-rust
lint-rust:
	cargo clippy -- -D warnings

.PHONY: test-fast
test-fast:
	cargo test --lib

.PHONY: precommit
precommit: quality

.PHONY: prepush
prepush: quality test

.PHONY: format-md
format-md:
	npx prettier --write "**/*.{md,json,yaml,yml}"

.PHONY: format-check-md
format-check-md:
	npx prettier --check "**/*.{md,json,yaml,yml}"

.PHONY: test
test: test-rust test-go test-python test-node

.PHONY: test-rust
test-rust:
	cargo test

.PHONY: test-go
test-go: build-rust-lib
	cd bindings/go && CGO_ENABLED=1 go test $(GO_TAGS_ARG) ./...

# Build/test helper for musl-based Linux environments (e.g. Alpine).
# Note: Go does NOT automatically enable the "musl" tag.
# Use this target (or pass GO_TAGS=musl) when building in musl containers.
.PHONY: test-go-musl
test-go-musl:
	@if [ "$(OS)" != "linux" ]; then echo "test-go-musl is linux-only"; exit 1; fi
	@arch="$(ARCH)"; \
	if [ "$$arch" = "amd64" ]; then rust_target="x86_64-unknown-linux-musl"; \
	elif [ "$$arch" = "arm64" ]; then rust_target="aarch64-unknown-linux-musl"; \
	else echo "unsupported ARCH=$$arch"; exit 1; fi; \
	$(MAKE) test-go GO_TAGS=musl RUST_TARGET="$$rust_target"

.PHONY: test-python
test-python:
	# Prefer uv for consistent virtualenv + lockfile resolution.
	if command -v uv >/dev/null 2>&1; then \
		cd crates/seekable-zstd-py && uv sync --dev && uv run maturin develop && uv run pytest; \
	elif command -v pytest >/dev/null 2>&1; then \
		cd crates/seekable-zstd-py && maturin develop && pytest; \
	else \
		echo "Skipping Python tests (uv/pytest not found)"; \
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
	@if [ -n "$(RUST_TARGET)" ]; then \
		$(BUILD_RUST_ENV) cargo build --release --target "$(RUST_TARGET)" -p seekable-zstd-core; \
		cp "target/$(RUST_TARGET)/release/libseekable_zstd_core.a" "$(LIB_DIR)/libseekable_zstd_core.a"; \
	else \
		$(BUILD_RUST_ENV) cargo build --release -p seekable-zstd-core; \
		cp target/release/libseekable_zstd_core.a "$(LIB_DIR)/libseekable_zstd_core.a"; \
	fi

# Maintainer convenience: regenerate committed macOS prebuilt libraries.
# Linux/Windows prebuilt libs are produced in CI via .github/workflows/artifacts.yml.
.PHONY: build-go-prebuilt-darwin
build-go-prebuilt-darwin:
	@rustup target add aarch64-apple-darwin x86_64-apple-darwin
	mkdir -p $(PREBUILT_LIB_ROOT)/darwin-arm64 $(PREBUILT_LIB_ROOT)/darwin-amd64
	MACOSX_DEPLOYMENT_TARGET=11.0 cargo build --release --target aarch64-apple-darwin -p seekable-zstd-core
	cp target/aarch64-apple-darwin/release/libseekable_zstd_core.a $(PREBUILT_LIB_ROOT)/darwin-arm64/libseekable_zstd_core.a
	MACOSX_DEPLOYMENT_TARGET=11.0 cargo build --release --target x86_64-apple-darwin -p seekable-zstd-core
	cp target/x86_64-apple-darwin/release/libseekable_zstd_core.a $(PREBUILT_LIB_ROOT)/darwin-amd64/libseekable_zstd_core.a

# Hook management
.PHONY: hooks-generate
hooks-generate:
	@$(GONEAT_RESOLVE); \
	if [ -z "$$GONEAT_BIN" ]; then echo "❌ goneat not found. Run 'make bootstrap' first."; exit 1; fi; \
	"$$GONEAT_BIN" hooks generate

.PHONY: hooks-install
hooks-install: hooks-generate
	@$(GONEAT_RESOLVE); \
	if [ -z "$$GONEAT_BIN" ]; then echo "❌ goneat not found. Run 'make bootstrap' first."; exit 1; fi; \
	"$$GONEAT_BIN" hooks install

.PHONY: hooks-remove
hooks-remove:
	@rm -f .git/hooks/pre-commit .git/hooks/pre-push

# Bootstrap
.PHONY: bootstrap
bootstrap:
	@set -eu; \
	$(BINDIR_RESOLVE); mkdir -p "$$BINDIR"; \
	$(SFETCH_RESOLVE); \
	if [ -z "$$SFETCH" ]; then \
		echo "→ Installing sfetch (trust anchor) into $$BINDIR..."; \
		curl -sSfL https://github.com/3leaps/sfetch/releases/latest/download/install-sfetch.sh | \
			bash -s -- --yes --dir "$$BINDIR"; \
		SFETCH="$$BINDIR/sfetch"; \
	fi; \
	echo "→ sfetch self-verify (trust anchor):"; \
	"$$SFETCH" --self-verify; \
	echo "→ Installing goneat $(GONEAT_VERSION) into $$BINDIR..."; \
	"$$SFETCH" --repo fulmenhq/goneat --tag $(GONEAT_VERSION) --dest-dir "$$BINDIR"; \
	OS_RAW="$$(uname -s 2>/dev/null || echo unknown)"; \
	case "$$OS_RAW" in MINGW*|MSYS*|CYGWIN*) if [ -f "$$BINDIR/goneat.exe" ] && [ ! -f "$$BINDIR/goneat" ]; then mv "$$BINDIR/goneat.exe" "$$BINDIR/goneat"; fi ;; esac; \
	$(GONEAT_RESOLVE); \
	if [ -z "$$GONEAT_BIN" ]; then echo "❌ goneat install failed"; exit 1; fi; \
	echo "→ goneat: $$($$GONEAT_BIN --version 2>&1 | head -n1 || true)"; \
	echo "→ Installing toolchains via goneat doctor..."; \
	"$$GONEAT_BIN" doctor tools --scope languages --install --install-package-managers --yes --no-cooling; \
	"$$GONEAT_BIN" doctor tools --scope foundation --install --install-package-managers --yes --no-cooling; \
	if [ -z "$${GITHUB_ACTIONS:-}" ]; then \
		$(MAKE) hooks-install; \
	else \
		echo "→ Skipping git hook install in CI"; \
	fi; \
	echo "Checking required tools..."; \
	command -v rustc >/dev/null 2>&1 || (echo "rustc required" && exit 1); \
	command -v cargo >/dev/null 2>&1 || (echo "cargo required" && exit 1); \
	rustup component add rustfmt clippy; \
	echo "✅ Bootstrap complete. Ensure $$BINDIR is on PATH"

# Build targets
.PHONY: build
build: build-rust-lib
	@echo "Build complete"

.PHONY: clean
clean:
	cargo clean
	rm -rf $(LOCAL_LIB_ROOT)
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
	sed -i '' 's/^version = ".*"/version = "$(VERSION)"/' crates/seekable-zstd/Cargo.toml
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

