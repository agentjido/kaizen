# Usage Rules

These rules define recommended usage for AI-assisted development with this package.

## Intended Use

- Use `Jido.Evolve.evolve/1` as the canonical public entrypoint.
- Prefer explicit fitness modules with deterministic behavior for repeatable runs.
- Provide a random seed in config for reproducible test scenarios.

## Safety and Reliability

- Treat fitness functions as untrusted runtime code; always handle `{:error, reason}` returns.
- Keep mutation and selection strategies side-effect free.
- Validate user input through public constructors and options parsers.

## Documentation Expectations

- Public modules/functions should include docs and examples.
- Internal plumbing may use `@moduledoc false` and `@doc false` when intentionally private.

## Release Rules

- Do not publish unless `mix quality`, `mix coveralls`, and `mix docs` all pass.
- Update `CHANGELOG.md` for every public release.
