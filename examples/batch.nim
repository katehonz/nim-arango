## Batch Operations Example for nim-arango
##
## Run this against a local ArangoDB instance:
##   docker run -d -p 8529:8529 -e ARANGO_ROOT_PASSWORD=password arangodb

import nim_arango
import std/[json, sequtils]

type Product = object
  name: string
  price: float
  stock: int

proc main() =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  let db = client.createDatabase("batch_demo")
  let products = db.createCollection("products")

  # Bulk CREATE
  echo "=== Bulk Create ==="
  let items = @[
    Product(name: "Laptop", price: 999.99, stock: 10),
    Product(name: "Mouse", price: 29.99, stock: 100),
    Product(name: "Keyboard", price: 79.99, stock: 50),
    Product(name: "Monitor", price: 299.99, stock: 25),
    Product(name: "Headphones", price: 149.99, stock: 75),
  ]
  let metas = products.createDocuments(items)
  echo "Created ", metas.len, " products"
  for m in metas:
    echo "  - key: ", m.key

  # Bulk UPDATE
  echo "\n=== Bulk Update ==="
  var updates: seq[tuple[key: string, patch: Product]]
  for m in metas:
    updates.add((key: m.key, patch: Product(name: "Updated", price: 9.99, stock: 0)))
  let updateMetas = products.updateDocuments(updates)
  echo "Updated ", updateMetas.len, " products"

  # Bulk REPLACE
  echo "\n=== Bulk Replace ==="
  var replacements: seq[tuple[key: string, doc: Product]]
  for i, m in metas:
    replacements.add((key: m.key, doc: Product(name: "Replaced", price: 19.99, stock: 99)))
  let replaceMetas = products.replaceDocuments(replacements)
  echo "Replaced ", replaceMetas.len, " products"

  # Bulk DELETE
  echo "\n=== Bulk Delete ==="
  let keys = metas.mapIt(it.key)
  let deleteMetas = products.removeDocuments(keys)
  echo "Deleted ", deleteMetas.len, " products"

  # Cleanup
  db.dropCollection("products")
  client.dropDatabase("batch_demo")
  client.close()

when isMainModule:
  main()
