## Benchmarks for nim-arango.
##
## Run with: nim c -d:release -r tests/benchmark.nim

import std/[times, strformat, strutils]
import ../src/nim_arango

const endpoint = "http://localhost:8529"
const username = "root"
const password = "password"

type BenchDoc = object
  name: string
  value: int
  data: string

proc bench(name: string, iterations: int, fn: proc()) =
  let start = cpuTime()
  for i in 0 ..< iterations:
    fn()
  let elapsed = cpuTime() - start
  let opsPerSec = iterations.float / elapsed
  echo &"{name}: {iterations} ops in {elapsed:.3f}s ({opsPerSec:.0f} ops/sec)"

proc main() =
  let client = newClient(
    withEndpoint(endpoint),
    withBasicAuth(username, password)
  )

  if not client.ping():
    echo "ArangoDB not available at " & endpoint
    echo "Start with: docker-compose up -d"
    return

  # Setup
  let dbName = "bench_" & $getTime().toUnix()
  let db = client.createDatabase(dbName)
  let col = db.createCollection("bench_docs")

  let doc = BenchDoc(name: "test", value: 42, data: "x".repeat(100))

  # Benchmark create
  var keys: seq[string] = @[]
  bench("createDocument", 1000) do:
    let meta = createDocument(col, doc)
    keys.add(meta.key)

  # Benchmark read
  bench("readDocument", 1000) do:
    discard readDocument[BenchDoc](col, keys[0])

  # Benchmark bulk create
  var docs: seq[BenchDoc] = @[]
  for i in 0 ..< 100:
    docs.add(BenchDoc(name: "bulk" & $i, value: i, data: "y".repeat(50)))
  bench("createDocuments (x100)", 100) do:
    discard createDocuments(col, docs)

  # Cleanup
  client.dropDatabase(dbName)
  client.close()

when isMainModule:
  main()
