# Contributing to nim-arango

Thank you for your interest in contributing!

## Development Setup

```bash
git clone git@github.com:katehonz/nim-arango.git
cd nim-arango
nimble install
docker-compose up -d  # Start ArangoDB for integration tests
```

## Running Tests

```bash
nimble test          # Unit tests
nimble check         # Compilation check
nimble examples      # Build examples
```

## Integration Tests

```bash
docker-compose up -d
nim c --path:src -r tests/test_integration.nim
```

## Code Style

- Use 2 spaces for indentation
- Prefix private procs with no `*`, export public procs with `*`
- Add `##` doc comments for all public APIs
- Follow Nim style guide

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure `nimble test` passes
5. Submit a pull request
