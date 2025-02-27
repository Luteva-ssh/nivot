# Package

version       = "0.1.0"
author        = "Janni Adamski"
description   = "nivot is a simple pivot library for nim."
license       = "MIT"
srcDir        = "src"
bin           = @["nivot"]

# Dependencies

requires "nim >= 2.2.0"

# Exports
installExt = @["nim"]
skipDirs = @["tests"]

# Tasks
task docs, "Generate documentation":
  exec "nim doc --project --out:docs src/nivot.nim"
  exec "nim doc --project --out:docs src/nivotpkg.nim"

task test, "Run tests":
  exec "nim c -r tests/all"
