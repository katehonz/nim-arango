# Package

version       = "0.1.0"
author        = "Kilo"
description   = "Modern, type-safe ArangoDB driver for Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.0.0"

task check, "Check compilation":
  exec "nim check src/nim_arango.nim"
