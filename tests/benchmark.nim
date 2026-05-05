## Benchmarks for nim-arango driver.
##
## Run with: nim c -d:release -r tests/benchmark.nim
##
## Requires ArangoDB running on localhost:8529 with root/password.
## Start with: docker-compose up -d

import std/[times, strformat, strutils, json, tables, math]
import ../src/nim_arango

const
  endpoint = "http://localhost:8529"
  username = "root"
  password = "password"

type BenchDoc = object
  name: string
  value: int
  data: string

# --- Benchmark helpers ---

type BenchResult = object
  name: string
  iterations: int
  elapsed: float
  opsPerSec: float

var results: seq[BenchResult]

proc bench(name: string, iterations: int, fn: proc()) =
  let start = cpuTime()
  for i in 0 ..< iterations:
    fn()
  let elapsed = cpuTime() - start
  let opsPerSec = iterations.float / elapsed
  results.add(BenchResult(name: name, iterations: iterations, elapsed: elapsed, opsPerSec: opsPerSec))
  echo &"  {name:40s} {iterations:>6d} ops | {elapsed:>8.3f}s | {opsPerSec:>10.0f} ops/sec"

proc sectionHeader(title: string) =
  echo ""
  echo &"--- {title} ---"

# --- Main ---

proc main() =
  let client = newClient(
    withEndpoint(endpoint),
    withBasicAuth(username, password)
  )

  if not client.ping():
    echo "ArangoDB not available at ", endpoint
    echo "Start with: docker-compose up -d"
    return

  echo "nim-arango Benchmarks"
  echo "============================"

  let dbName = "bench_" & $getTime().toUnix()
  let db = client.createDatabase(dbName)
  let col = db.createCollection("bench_docs")

  # Setup data
  let doc = BenchDoc(name: "bench-test", value: 42, data: "x".repeat(100))
  let setupMeta = createDocument(col, doc)

  # === Create ===
  sectionHeader("Document Create")
  var createdKeys: seq[string] = @[]
  bench("createDocument (single, 1000 reqs)", 1000) do ():
    let meta = createDocument(col, doc)
    createdKeys.add(meta.key)

  # Clean up created docs
  for k in createdKeys:
    try: discard removeDocument(col, k)
    except: discard
  createdKeys = @[]

  # === Read ===
  sectionHeader("Document Read")
  bench("readDocument (single, 1000 reqs)", 1000) do ():
    discard readDocument[BenchDoc](col, setupMeta.key)

  # === Update ===
  sectionHeader("Document Update")
  var updateDoc = BenchDoc(name: "updated", value: 99, data: "updated".repeat(20))
  bench("updateDocument (single, 1000 reqs)", 1000) do ():
    discard updateDocument(col, setupMeta.key, updateDoc)

  # === Replace ===
  sectionHeader("Document Replace")
  bench("replaceDocument (single, 1000 reqs)", 1000) do ():
    discard replaceDocument(col, setupMeta.key, doc)

  # === Query ===
  sectionHeader("AQL Query")
  let q = db.query("FOR d IN bench_docs LIMIT 10 RETURN d")
  bench("exec query + cursor (10 docs, 100 iters)", 100) do ():
    let cursor = exec[BenchDoc](q, db)
    var count = 0
    while cursor.next():
      let (d, _) = cursor.read()
      count += 1
    cursor.close()

  # === Bulk Create ===
  sectionHeader("Bulk Create")
  var bulkDocs: seq[BenchDoc] = @[]
  for i in 0 ..< 100:
    bulkDocs.add(BenchDoc(name: "bulk" & $i, value: i, data: "y".repeat(50)))

  bench("createDocuments (100 docs/batch, 100 reqs)", 100) do ():
    discard createDocuments(col, bulkDocs)

  # Clean up bulk docs
  var allDocs = findAll[BenchDoc](col)
  for d in allDocs:
    try: discard removeDocument(col, d.meta.key)
    except: discard

  # === ORM ===
  sectionHeader("ORM Operations")
  var testModel = newModel(col, BenchDoc(name: "orm-test", value: 1, data: "orm".repeat(20)))
  bench("ORM save (500 ops)", 500) do ():
    discard testModel.save()

  bench("ORM refresh (500 ops)", 500) do ():
    testModel.refresh()

  # === Raw metrics ===
  sectionHeader("Metrics")
  let metrics = renderMetrics()
  echo &"  Metrics output: {metrics.split('\\n').len} lines"

  # Cleanup
  try:
    discard removeDocument(col, setupMeta.key)
  except:
    discard
  client.dropDatabase(dbName)
  client.close()

  # === Summary ===
  echo ""
  echo "=== Summary ==="
  echo "Benchmark                                 Ops     Time  Ops/sec  Latency"
  echo "---------------------------------------- ------ -------- -------- --------"
  for r in results:
    let lat = r.elapsed / r.iterations.float * 1000
    echo &"{r.name:40s} {r.iterations:>6d} {r.elapsed:>7.3f}s {r.opsPerSec:>8.0f} {lat:.6f}ms"
  echo ""

when isMainModule:
  main()
