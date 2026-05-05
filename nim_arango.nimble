# Package

version       = "0.1.0"
author        = "Kilo"
description   = "Modern, type-safe ArangoDB driver for Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.0.0"

# Tasks
task test, "Run tests":
  exec "nim c -r tests/test_transport.nim"

task check, "Check compilation":
  exec "nim check src/nim_arango.nim"

task examples, "Build examples":
  exec "nim c --path:src examples/crud.nim"
  exec "nim c --path:src examples/query.nim"
  exec "nim c --path:src examples/graph.nim"
