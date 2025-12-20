# Release Notes

Each release can include a Markdown note under `docs/releases/` named with the
Git tag prefix:

```
docs/releases/vX.Y.Z.md
```

Use the pure semver in `RELEASE_TAG` (example: `0.1.1`). The Git tag and
release notes filename are derived as:

- Tag: `v${RELEASE_TAG}`
- Notes: `docs/releases/v${RELEASE_TAG}.md`

Release notes are optional for v0.1.x, but if present they are uploaded to the
GitHub Release alongside signatures.
