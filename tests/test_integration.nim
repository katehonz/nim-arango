## Integration tests against a real ArangoDB instance.
## Requires ArangoDB running on localhost:8529 with root/password.

import std/[unittest, json, os]
import ../src/nim_arango

const
  testEndpoint = "http://localhost:8529"
  testUser = "root"
  testPass = "password"

var testClient: Client
var testDb: Database

suite "Integration: Client":
  test "connect and get version":
    let client = newClient(
      withEndpoint(testEndpoint),
      withBasicAuth(testUser, testPass)
    )
    let ver = client.version()
    check ver.version.len > 0
    check ver.server == "arango"
    client.close()

  test "ping":
    let client = newClient(
      withEndpoint(testEndpoint),
      withBasicAuth(testUser, testPass)
    )
    check client.ping() == true
    client.close()

suite "Integration: Database":
  setup:
    testClient = newClient(
      withEndpoint(testEndpoint),
      withBasicAuth(testUser, testPass)
    )

  teardown:
    testClient.close()

  test "create and drop database":
    let dbName = "nim_test_" & $getTime().toUnix()
    let db = testClient.createDatabase(dbName)
    check db.name() == dbName

    testClient.dropDatabase(dbName)

suite "Integration: Collection & Document":
  setup:
    testClient = newClient(
      withEndpoint(testEndpoint),
      withBasicAuth(testUser, testPass)
    )
    let dbName = "nim_test_doc_" & $getTime().toUnix()
    testDb = testClient.createDatabase(dbName)

  teardown:
    testClient.dropDatabase(testDb.name())
    testClient.close()

  test "create and read document":
    let col = testDb.createCollection("test_users")

    type TestUser = object
      name: string
      age: int

    let meta = createDocument(col, TestUser(name: "Alice", age: 30))
    check meta.key.len > 0

    let doc = readDocument[TestUser](col, meta.key)
    check doc.data.name == "Alice"
    check doc.data.age == 30

  test "query documents":
    let col = testDb.createCollection("test_products")

    type Product = object
      name: string
      price: float

    discard createDocument(col, Product(name: "Laptop", price: 999.0))
    discard createDocument(col, Product(name: "Mouse", price: 29.0))

    let q = query(testDb, "FOR p IN test_products FILTER p.price > @min RETURN p")
      .bindParam("min", 100.0)

    let cursor = exec[Product](q, testDb)
    var count = 0
    while cursor.next():
      let (product, _) = cursor.read()
      count += 1
      check product.price > 100.0
    cursor.close()
    check count >= 1
