## Compile-time Document API Macro Example
##
## Shows how to use documentApi for type-safe, ergonomic CRUD.
##
## Run against a local ArangoDB:
##   docker run -d -p 8529:8529 -e ARANGO_ROOT_PASSWORD=password arangodb

import nim_arango

type
  User = object
    name: string
    email: string
    age: int

  Product = object
    title: string
    price: float
    category: string

# Generate type-safe API at compile time
# This creates: createUser, readUser, updateUser, replaceUser,
#   removeUser, userExists, allUsers, batchCreateUsers
documentApi(User)
documentApi(Product)

proc main() =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  let db = client.createDatabase("macro_demo")
  let users = db.createCollection("users")
  let products = db.createCollection("products")

  # CREATE — no need for type parameters!
  let alice = users.createUser(User(name: "Alice", email: "alice@example.com", age: 30))
  let bob = users.createUser(User(name: "Bob", email: "bob@example.com", age: 25))
  echo "Created users: ", alice.key, ", ", bob.key

  # READ
  let aliceDoc = users.readUser(alice.key)
  echo "Read: ", aliceDoc.data.name, " (age ", aliceDoc.data.age, ")"

  # UPDATE
  discard users.updateUser(alice.key, User(name: "Alice Updated", email: "alice@example.com", age: 31))
  echo "Updated Alice"

  # REPLACE
  discard users.replaceUser(bob.key, User(name: "Robert", email: "robert@example.com", age: 26))
  echo "Replaced Bob with Robert"

  # EXISTS
  echo "Alice exists: ", users.userExists(alice.key)

  # ALL
  let foundUsers = users.allUsers()
  echo "Total users: ", foundUsers.len
  for u in foundUsers:
    echo "  - ", u.data.name, " (", u.data.email, ")"

  # BATCH CREATE
  let prods = @[
    Product(title: "Laptop", price: 999.99, category: "Electronics"),
    Product(title: "Mouse", price: 29.99, category: "Electronics"),
    Product(title: "Desk", price: 199.99, category: "Furniture"),
  ]
  let prodMetas = products.batchCreateProducts(prods)
  echo "Batch created ", prodMetas.len, " products"

  # Product CRUD also works
  let laptop = products.readProduct(prodMetas[0].key)
  echo "Product: ", laptop.data.title, " $", laptop.data.price

  # DELETE
  discard users.removeUser(alice.key)
  discard users.removeUser(bob.key)
  echo "Deleted all users"

  # Cleanup
  db.dropCollection("users")
  db.dropCollection("products")
  client.dropDatabase("macro_demo")
  client.close()

when isMainModule:
  main()
