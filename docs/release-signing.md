# Release Signing (Manual)

Release artifacts are built in CI, but **signing is done locally** with minisign.
Private keys are never stored in CI or this repository.

This workflow is Go-centric for v0.1.x and does not publish to registries.

## Environment Variables

Required:

- `RELEASE_TAG` - Pure semver (example: `0.1.1`)
- `SEEKABLE_ZSTD_MINISIGN_KEY` - Path to the minisign private key
- `SEEKABLE_ZSTD_MINISIGN_PUB` - Path to the minisign public key

Optional:

- `SEEKABLE_ZSTD_RELEASE_TAG` - Alias for `RELEASE_TAG` (overrides if set)

Derived:

- Git tag name: `v${RELEASE_TAG}`
- Release notes file: `docs/releases/v${RELEASE_TAG}.md` (optional)

## Manual Signing Flow

The Makefile targets below orchestrate release signing. They are designed to
run locally with `gh` authenticated to this repo.

```bash
export RELEASE_TAG=0.1.1
export SEEKABLE_ZSTD_MINISIGN_KEY="$HOME/.minisign/seekable-zstd.key"
export SEEKABLE_ZSTD_MINISIGN_PUB="$HOME/.minisign/seekable-zstd.pub"

make release-download
make release-checksums
make release-sign
make release-export-keys
make release-upload-signatures
```

The signing outputs uploaded to the GitHub Release include:

- `SHA256SUMS` + `SHA256SUMS.minisig`
- `SHA512SUMS` + `SHA512SUMS.minisig`
- `minisign.pub`
- `docs/releases/v${RELEASE_TAG}.md` (if present)

Use `make release-clean` to remove local staging directories when done.
