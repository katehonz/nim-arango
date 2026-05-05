## ORM Example for nim-arango
##
## Shows how to use the Model[T] wrapper for higher-level document operations.
##
## Run against a local ArangoDB:
##   docker run -d -p 8529:8529 -e ARANGO_ROOT_PASSWORD=password arangodb

import nim_arango
import std/[json, strutils]

type
  User = object
    name: string
    email: string
    age: int

  UserValidator = proc(u: User): ValidateResult

proc validateUser(u: User): ValidateResult =
  var errors: seq[string] = @[]
  if u.name.len == 0:
    errors.add("name is required")
  if u.email.len == 0 or u.email.find("@") < 0:
    errors.add("valid email is required")
  if u.age < 0 or u.age > 200:
    errors.add("age must be between 0 and 200")
  ValidateResult(valid: errors.len == 0, errors: errors)

proc main() =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  let db = client.createDatabase("orm_demo")
  let users = db.createCollection("users")

  echo "=== ORM Example ==="

  # CREATE via Model
  var alice = newModel(users, User(name: "Alice", email: "alice@example.com", age: 30))
  echo "Valid: ", alice.isValid(validateUser)
  let meta = alice.save()
  echo "Saved Alice: key=", meta.key, " isNew=", alice.isNew

  var bob = newModel(users, User(name: "Bob", email: "bob@example.com", age: 25))
  discard bob.save()
  echo "Saved Bob: key=", bob.key

  # Validation
  var invalid = newModel(users, User(name: "", email: "bad", age: -5))
  let validation = invalid.validate(validateUser)
  if not validation.valid:
    echo "Validation failed:"
    for err in validation.errors:
      echo "  - ", err

  # FIND by key
  let found = findByKey[User](users, alice.key)
  echo "Found: ", found.data.name, " (", found.data.email, ")"

  # FIND all
  let allUsers = findAll[User](users)
  echo "All users: ", allUsers.len
  for u in allUsers:
    echo "  - ", u.data.name

  # UPDATE via Model
  found.data.age = 31
  discard found.save()
  echo "Updated Alice's age to ", found.data.age

  # REFRESH from database
  found.refresh()
  echo "Refreshed: age=", found.data.age

  # FIND with AQL filter
  let adults = findWhere[User](users, "doc.age >= @age", %*{"age": 18})
  echo "Adults (>=18): ", adults.len
  for u in adults:
    echo "  - ", u.data.name, " (age ", u.data.age, ")"

  # DELETE
  discard found.delete()
  echo "Deleted Alice, isNew=", found.isNew

  # COUNT
  let count = countDocuments[User](users)
  echo "Remaining users: ", count

  # Cleanup
  db.dropCollection("users")
  client.dropDatabase("orm_demo")
  client.close()

when isMainModule:
  main()
