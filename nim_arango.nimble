# Package

version       = "0.1.0"
author        = "Kilo"
description   = "Modern, type-safe ArangoDB driver for Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.0.0"

# Tasks
task test, "Run unit tests":
  exec "nim c -r tests/test_transport.nim"
  exec "nim c -r tests/test_client.nim"
  exec "nim c -r tests/test_metrics.nim"
  exec "nim c -r tests/test_query.nim"
  exec "nim c -r tests/test_errors.nim"
  exec "nim c -r tests/test_macros.nim"
  exec "nim c -r tests/test_orm.nim"

task check, "Check compilation":
  exec "nim check src/nim_arango.nim"

task examples, "Build examples":
  exec "nim c --path:src examples/crud.nim"
  exec "nim c --path:src examples/query.nim"
  exec "nim c --path:src examples/graph.nim"
  exec "nim c --path:src examples/batch.nim"
  exec "nim c --path:src examples/transaction.nim"
  exec "nim c --path:src examples/async_example.nim"
  exec "nim c --path:src examples/macro_api.nim"
  exec "nim c --path:src examples/orm.nim"
