# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [0.2.0] - 2026-02-27

### Added
- Public release scaffolding: CI, release workflow, config files, contributing guide, usage rules, and getting-started guide.
- Canonical `Jido.Evolve.evolve/1` options validation layer.
- Centralized `Jido.Evolve.Error` module using Splode.
- Optional Igniter installer task: `mix jido_evolve.install`.

### Changed
- Breaking API update: `Jido.Evolve.evolve/1` now uses simplified options (`initial_population`, `fitness`, optional config/context/strategy overrides).
- Runtime config and state modeling migrated to Zoi-based struct validation patterns.
- Project quality gates aligned to ecosystem standard (`mix quality`, coverage, docs checks).

### Removed
- Deprecated NimbleOptions/typed-struct based config model.

[0.2.0]: https://github.com/agentjido/jido_evolve/releases/tag/v0.2.0
