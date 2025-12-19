# Release Checklist

This repo is currently **alpha**. For v0.1.x we prioritize:

- Tagging stable snapshots
- CI-built prebuilt artifacts (especially Go CGO static libs)

Publishing to package registries (crates.io / PyPI / npm) is planned for v0.2.x.

---

## SSOT

- Process notes / MVP: `.plans/active/v0.1.0/bootstrap-completion.md`
- CI auth (GitHub App tokens): `.plans/active/github-app-auth-for-ci.md`

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
  F --> G[artifacts.yml runs on tag
and uploads build artifacts]
```

---

## Steps

1. Ensure `main` is green in CI (`.github/workflows/ci.yml`).

2. Prepare committed Go prebuilt libs (release prep)

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

Required privileges to run this from local:

- Your `gh` auth must be able to trigger `workflow_dispatch` in this repo.
- The workflow itself performs the commit via `contents: write` on the `commit-artifacts` job.

3. Validate Linux linking for Go users:

- Run `.github/workflows/go-prebuilt-libs.yml` via GitHub UI (or `gh workflow run`)
- Expect both glibc (Debian) and musl (Alpine) jobs to pass.

4. Update versions if needed:

- `make bump-patch` / `make bump-minor` / `make bump-major`
- Update `CHANGELOG.md`
- Push the version bump commit.

5. Create the tag on the correct commit:

- Tag the `main` commit that includes the updated `bindings/go/lib/**`.

6. Verify tag build artifacts:

- Confirm `.github/workflows/artifacts.yml` ran on the tag and uploaded platform artifacts.

7. Post-release:

- Announce to early Go users which tag to test.
- Track any required fixes as patch releases.
