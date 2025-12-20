# Release Checklist

This repo is currently **alpha**. For v0.1.x we prioritize:

- Tagging stable snapshots
- CI-built prebuilt artifacts (especially Go CGO static libs)

Publishing to package registries (crates.io / PyPI / npm) is planned for v0.2.x.

---

## Read This First

- `docs/cicd.md` (why CI artifacts are required)
- `docs/go-binding.md` (expected `bindings/go/lib/**` layout)
- `docs/development.md` (local targets like `make ci-offline`)
- `docs/release-signing.md` (manual minisign flow)
- `docs/releases/README.md` (release notes naming)

---

## Release Flow (Go-first)

Goal: the `vX.Y.Z` tag must include the correct `bindings/go/lib/**` prebuilt libs.

```mermaid
graph TD
  A[Merge changes to main] --> B[CI green on main]
  B --> C[Run artifacts.yml workflow_dispatch
commit_to_main=true]
  C --> D[Artifacts workflow commits
bindings/go/lib/** to main]
  D --> E[Run go-prebuilt-libs.yml
(workflow_dispatch)]
  E --> F[Tag vX.Y.Z on the commit
that contains the libs]
  F --> G[release.yml runs on tag
and uploads release assets]
  G --> H[Manual signing and upload]
```

---

## Steps

1. Ensure `main` is green in CI (`.github/workflows/ci.yml`).

2. Run local workflow lint checks:

```bash
make lint-actions
```

3. Prepare committed Go prebuilt libs (release prep)

This step produces a commit on `main` that updates `bindings/go/lib/**`. The release tag must point to that commit.

**GitHub UI:**

- Run `.github/workflows/artifacts.yml`
- Set input `commit_to_main=true`

**From local with `gh`:**

```bash
# Trigger release prep build + commit-to-main
gh workflow run "Build Artifacts" --ref main -f commit_to_main=true

# Watch it complete
gh run watch --exit-status
```

## Credentials for `gh`

To run workflow_dispatch from local using `gh`, your token must be able to dispatch workflows in this repo.

Recommended: **fine-grained PAT** scoped to `3leaps/seekable-zstd` with:

- Actions: Read and write
- Workflows: Read and write
- Contents: Read

The workflow itself performs the commit via `contents: write` on the `commit-artifacts` job.

4. Validate Linux linking for Go users:

**GitHub UI:**

- Run `.github/workflows/go-prebuilt-libs.yml`

**From local with `gh`:**

```bash
gh workflow run "Go Prebuilt Lib Validation" --ref main

gh run watch --exit-status
```

Expect both glibc (Debian) and musl (Alpine) jobs to pass.

5. Update versions if needed:

- `make bump-patch` / `make bump-minor` / `make bump-major`
- Update `CHANGELOG.md`
- Push the version bump commit.

6. Create the tag on the correct commit:

- Tag the exact commit SHA that:
  - includes the updated `bindings/go/lib/**`, and
  - is the commit validated by the Go prebuilt validation run you’re relying on.

Do not tag a commit newer than the validation run’s SHA.

7. Verify release assets:

- Confirm `.github/workflows/release.yml` ran on the tag and uploaded Go bundle assets.

8. Manual signing (local):

- Set environment variables:
  - `RELEASE_TAG=0.1.1` (pure semver)
  - `SEEKABLE_ZSTD_RELEASE_TAG=0.1.1` (alias for `RELEASE_TAG`)
  - `SEEKABLE_ZSTD_MINISIGN_KEY=/path/to/minisign.key`
  - `SEEKABLE_ZSTD_MINISIGN_PUB=/path/to/minisign.pub`
- Run the Make targets:
  - `make release-download`
  - `make release-checksums`
  - `make release-sign`
  - `make release-export-keys`
  - `make release-upload-signatures`

If you have a release note at `docs/releases/v${RELEASE_TAG}.md`, it is uploaded
alongside the signatures.

9. Post-release:

- Announce to early Go users which tag to test.
- Track any required fixes as patch releases.
