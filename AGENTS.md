# AGENTS.md

## Build Commands

```bash
nimble check     # nim check src/nim_arango.nim
nimble test      # runs all 7 unit test suites (53 tests)
nimble examples  # builds all 8 examples
nimble bench     # runs benchmarks (requires ArangoDB)
```

## Testing

- Unit tests: `tests/test_transport.nim`, `test_client.nim`, `test_metrics.nim`, `test_query.nim`, `test_errors.nim`, `test_macros.nim`, `test_orm.nim`
- Integration tests: `tests/test_integration.nim` — requires ArangoDB on port 8529 (password: `password`)
- Build single example: `nim c --path:src examples/<name>.nim`

## Architecture

- Package: `nim_arango` (srcDir = `src`)
- Main entry: `src/nim_arango.nim` — exports all modules
- Key modules: `transport`, `auth`, `client`, `database`, `collection`, `document`, `query`, `graph`, `view`, `index`, `analyzer`, `pregel`, `foxx`, `user`, `batch`, `health`, `circuit`, `backup`, `replication`, `cluster`, `agency`, `import_api`, `metrics`, `logging`, `macros`, `orm`
- Connection pooling via `std/httpclient` with keep-alive
- Functional options pattern (`withEndpoint`, `withBasicAuth`, etc.)
- Type-safe documents via generics: `readDocument[User](key)` returns `Document[User]`
- Compile-time macro: `documentApi(User)` generates `createUser`, `readUser`, etc.
- ORM: `Model[T]` with `save()`, `delete()`, `refresh()`, `findByKey()`, `findWhere()`, validation

## CI

- Nim version: 2.2.0
- CI pipeline: check → build → test → examples
- Integration tests use Docker `arangodb:3.11`

## References

- Roadmap: `ROADMAP.md` (Bulgarian)
- Full API examples: `README.md`, `examples/`
