## CRUD Example for nim-arango
##
## Run this against a local ArangoDB instance:
##   docker run -d -p 8529:8529 -e ARANGO_ROOT_PASSWORD=password arangodb

import nim_arango
import std/json

# Define your data model
type User = object
  name: string
  email: string
  age: int

proc main() =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  # Create database
  let db = client.createDatabase("demo")
  echo "Created database: ", db.name()

  # Create collection
  let users = db.createCollection("users")
  echo "Created collection: ", users.name()

  # CREATE
  let user = User(name: "Alice", email: "alice@example.com", age: 30)
  let meta = users.createDocument(user)
  echo "Created document key: ", meta.key

  # READ
  let doc = users.readDocument[User](meta.key)
  echo "Read: ", doc.data.name, " (", doc.data.age, ")"

  # UPDATE
  let patch = User(name: "Alice Updated", email: "alice@example.com", age: 31)
  let updateMeta = users.updateDocument(meta.key, patch)
  echo "Updated rev: ", updateMeta.rev

  # REPLACE
  let replacement = User(name: "Bob", email: "bob@example.com", age: 25)
  let replaceMeta = users.replaceDocument(meta.key, replacement)
  echo "Replaced key: ", replaceMeta.key

  # DELETE
  let delMeta = users.removeDocument(meta.key)
  echo "Deleted key: ", delMeta.key

  # Cleanup
  db.dropCollection("users")
  client.dropDatabase("demo")
  client.close()

when isMainModule:
  main()
