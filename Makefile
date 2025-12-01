GONEAT := ./bin/goneat

# Quality gates
.PHONY: quality
quality: format-check lint test-fast

.PHONY: format
format:
	cargo fmt

.PHONY: format-check
format-check:
	cargo fmt -- --check

.PHONY: lint
lint:
	cargo clippy -- -D warnings

.PHONY: test-fast
test-fast:
	cargo test --lib

.PHONY: test
test:
	cargo test

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
	rustup component add rustfmt clippy
	@echo "Bootstrap complete"
