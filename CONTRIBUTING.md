# Contributing

Thanks for contributing to Jido.Evolve.

## Development Setup

1. Install Elixir `~> 1.18`.
2. Install dependencies:

```bash
mix setup
```

## Quality Gates

Run all required checks before opening a PR:

```bash
mix quality
mix test
mix coveralls
mix docs
```

## Commit Conventions

Use conventional commits:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Refactor without behavior change
- `test`: Test changes
- `chore`: Tooling/dependency maintenance
- `ci`: CI/CD changes

Examples:

```bash
git commit -m "feat(api): simplify evolve/1 options"
git commit -m "fix(engine): normalize mutation override wiring"
```

## Pull Requests

- Keep changes focused and reviewable.
- Include tests for behavior changes.
- Update README and CHANGELOG when public behavior changes.
