## Async Example for nim-arango
##
## Run this against a local ArangoDB instance:
##   docker run -d -p 8529:8529 -e ARANGO_ROOT_PASSWORD=password arangodb
##
## Note: The driver uses async HTTP client internally but exposes sync API.
## For true async usage, wrap calls in async proc.

import nim_arango
import std/[asyncdispatch, json]

type User = object
  name: string
  email: string

proc asyncOperation() {.async.} =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  let db = client.createDatabase("async_demo")
  let users = db.createCollection("users")

  echo "=== Async Example ==="

  # CREATE
  let user = User(name: "AsyncAlice", email: "async@example.com")
  let meta = users.createDocument(user)
  echo "Created: ", meta.key

  # READ
  let doc = readDocument[User](users, meta.key)
  echo "Read: ", doc.data.name

  # QUERY
  let q = db.query("FOR u IN users RETURN u")
  let cursor = exec[User](q, db)
  var count = 0
  while cursor.next():
    let (u, _) = cursor.read()
    count += 1
    echo "Found: ", u.name
  cursor.close()
  echo "Total users: ", count

  # DELETE
  let delMeta = users.removeDocument(meta.key)
  echo "Deleted: ", delMeta.key

  # Cleanup
  db.dropCollection("users")
  client.dropDatabase("async_demo")
  client.close()

  echo "\nAsync operations completed!"

when isMainModule:
  waitfor asyncOperation()
