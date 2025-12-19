# CI/CD and Artifacts

seekable-zstd is a multi-language library. For Go (CGO) in particular, the repository must ship prebuilt static libraries under `bindings/go/lib/**` so `go test` and downstream consumers can link without requiring Rust toolchains.

This means the CI workflows are not just “nice-to-have discipline” — they are part of how we produce the distributable artifacts for real users.

---

## Key ideas

- **CI builds artifacts continuously**: On every `main` push, we build the prebuilt static libraries and upload them as workflow artifacts.
- **Tags must include committed libs**: When we cut a release tag (`vX.Y.Z`), that tag should point to a commit that already contains the correct `bindings/go/lib/**` outputs.
- **Release prep is explicit**: We run a manual “release prep” workflow that commits updated prebuilt libs to `main`. Then we tag that commit.

---

## Workflows

- ` .github/workflows/ci.yml`
  - Runs on `main` and PRs
  - Installs trusted tools once per OS and distributes via job artifacts
  - Runs Rust/Go/Python/Node tests

- ` .github/workflows/artifacts.yml`
  - Runs on `main` pushes and tags `v*` to build/upload prebuilt libs
  - Supports `workflow_dispatch` input `commit_to_main=true` to commit `bindings/go/lib/**` to `main` (release prep)

- ` .github/workflows/go-prebuilt-libs.yml`
  - Manual validation job to prove Linux glibc + musl linking against committed `bindings/go/lib/**`

See `RELEASE_CHECKLIST.md` for the release ordering.

---

## Local builds (when needed)

Most users should not need to build the cross-platform prebuilt libs locally.

However, maintainers can build locally for debugging, experimentation, or when CI is unavailable.

### Linux cross builds via cargo-zigbuild

We standardize on `cargo-zigbuild` for Linux glibc+musl cross builds.

High-level intent:

- glibc: `x86_64-unknown-linux-gnu.2.17` and `aarch64-unknown-linux-gnu.2.17`
- musl: `x86_64-unknown-linux-musl` and `aarch64-unknown-linux-musl`

The canonical build logic lives in `.github/workflows/artifacts.yml`.

### Remote builders

If you have access to a remote build environment (e.g., a managed dev VM / build runner), the same commands used in `.github/workflows/artifacts.yml` can be executed there.

The important part is **reproducibility**:

- use the same targets
- produce the same filenames
- verify correctness by running Go validation (glibc + musl)

---

## Why artifacts grow over time

As the project expands, we expect additional artifact needs, such as:

- Signed release bundles
- Checksums and provenance/attestation
- More platform variants (Windows, arm64 parity)

This is normal for a multi-language, cross-platform library. The goal is to keep the process explicit, documented, and reproducible.
