# Contributing to seekable-zstd

Thank you for your interest in contributing to `seekable-zstd`!

## Getting Started

1.  **Read the Docs**:
    - [Development Guide](docs/development.md): Setup, build commands, and workflow.
    - [Standards](docs/standards/README.md): Coding and testing standards for all languages.

2.  **Environment Setup**:
    Run `make bootstrap` to install required tools and hooks:
    ```bash
    make bootstrap
    ```

3.  **Quality Gates**:
    We use strict quality gates enforced by git hooks. Ensure checks pass before committing:
    ```bash
    make quality
    ```

## AI Contributors

If you are an AI agent, please read [AGENTS.md](AGENTS.md) for specific instructions on operational safety, attribution, and architecture.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
