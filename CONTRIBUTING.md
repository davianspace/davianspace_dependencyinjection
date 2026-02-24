# Contributing to davianspace_dependencyinjection

Thank you for your interest in contributing! This document provides guidelines
and instructions for contributing to this project.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Commit Convention](#commit-convention)
- [Architecture Guidelines](#architecture-guidelines)
- [Documentation](#documentation)
- [Reporting Issues](#reporting-issues)

---

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/)
code of conduct. By participating, you are expected to uphold this code.
Please report unacceptable behaviour to the maintainers.

---

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally.
3. Run `dart pub get` to install dependencies.
4. Run `dart test` to verify all tests pass.
5. Create a **feature branch** for your change.

---

## Development Setup

**Requirements:**
- Dart SDK `>=3.3.0`
- No Flutter needed — pure Dart package

```bash
# Get dependencies
dart pub get

# Run tests
dart test

# Run analysis
dart analyze

# Format code
dart format .

# Score the package locally
dart pub global activate pana
pana .
```

---

## Coding Standards

- Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide.
- Use `dart format` — all PRs are format-checked.
- `dart analyze` must report zero issues — the `analysis_options.yaml` uses the `lints` package with additional rules.
- All public API members must have dartdoc comments.
- Prefer `final` over `late` where possible.
- Use explicit types on public APIs.

---

## Testing Requirements

- **All tests must pass** (`dart test`).
- New features must include tests covering:
  - Happy path (feature works as expected)
  - Error path (appropriate exceptions thrown)
  - Edge cases (empty inputs, boundary conditions)
- Maintain or improve code coverage — aim for ≥ 95%.

---

## Pull Request Process

1. Ensure `dart format .` and `dart analyze .` both pass with zero issues.
2. Run the full test suite: `dart test`.
3. Update `CHANGELOG.md` under the `[Unreleased]` section.
4. Reference the related issue in your PR description.
5. Await code review — at least one approval is required before merging.

---

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use for |
|---|---|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation changes only |
| `test:` | Adding/updating tests |
| `refactor:` | Refactoring without feature/fix |
| `perf:` | Performance improvement |
| `chore:` | Build, tooling, dependency updates |
| `BREAKING CHANGE:` | Breaking API change (add to body) |

**Examples:**
```
feat: add tryGetAsync<T> to ServiceProviderBase
fix: propagate ResolutionChain through transitive dependencies
docs: add getAll multi-registration example to README
```

---

## Architecture Guidelines

The package uses a **two-phase** architecture:

**Build phase** (`ServiceCollection.buildServiceProvider()`):
- `CallSiteResolver` converts `ServiceDescriptor` objects into an immutable `Map<Type, CallSite>` tree.
- `DependencyGraph` detects circular dependencies.
- `CallSiteValidator` detects scope violations (captive dependencies).
- `RootServiceProvider` stores the compiled maps, `SingletonCache`, and `DisposalTracker`.

**Resolve phase** (calls to `getRequired<T>()` etc.):
- `CallSiteExecutor` walks the `CallSite` tree.
- `ResolutionChain` (O(1) `Set`-backed) detects runtime cycles.
- Results are cached per their lifetime (`SingletonCache` / `ScopedCache`).

**Key contracts:**
- `ServiceDescriptor` is immutable once created.
- `ServiceCollection` is single-use — build once, then frozen.
- All constructor injection is AOT-safe via `ReflectionHelper`.

---

## Documentation

- Every public API element needs a dartdoc comment.
- Code examples in dartdoc should use triple-backtick Dart blocks.
- Update `README.md` for new end-user features.
- Update `CHANGELOG.md` for every user-visible change.

---

## Reporting Issues

Please open a GitHub issue and include:

- Dart SDK version (`dart --version`).
- Minimal reproducible example.
- Expected vs actual behaviour.
- Full stack trace if an exception was thrown.
