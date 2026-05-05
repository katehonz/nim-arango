import std/[unittest, json]
import ../src/nim_arango/[orm, collection, document, types, options as opts]

type
  TestUser = object
    name: string
    age: int

  TestProduct = object
    title: string
    price: float

suite "Model creation":
  test "newModel creates model with isNew=true":
    let col = Collection(name: "test")
    let m = newModel(col, TestUser(name: "Alice", age: 30))
    check m.isNew == true
    check m.data.name == "Alice"
    check m.data.age == 30
    check m.col.name == "test"

  test "newModel with key":
    let col = Collection(name: "test")
    let m = newModel(col, TestUser(name: "Bob", age: 25), key = "user_bob")
    check m.isNew == true
    check m.key == "user_bob"
    check m.data.name == "Bob"

  test "newModelFromDoc creates model from document":
    let col = Collection(name: "test")
    let doc = Document[TestUser](
      meta: DocumentMeta(key: "k1", id: "test/k1", rev: "r1"),
      data: TestUser(name: "Charlie", age: 35),
    )
    let m = newModelFromDoc(col, doc)
    check m.isNew == false
    check m.key == "k1"
    check m.id == "test/k1"
    check m.rev == "r1"
    check m.data.name == "Charlie"

suite "Model properties":
  test "key accessor":
    let col = Collection(name: "test")
    let m = newModel(col, TestUser(name: "Test", age: 10), key = "mykey")
    check m.key == "mykey"

  test "id accessor":
    let col = Collection(name: "test")
    let doc = Document[TestUser](
      meta: DocumentMeta(key: "k1", id: "col/k1", rev: "r1"),
      data: TestUser(name: "Test", age: 10),
    )
    let m = newModelFromDoc(col, doc)
    check m.id == "col/k1"

  test "rev accessor":
    let col = Collection(name: "test")
    let doc = Document[TestUser](
      meta: DocumentMeta(key: "k1", id: "col/k1", rev: "abc123"),
      data: TestUser(name: "Test", age: 10),
    )
    let m = newModelFromDoc(col, doc)
    check m.rev == "abc123"

suite "Validation":
  test "validate with custom validator":
    let validator: Validator[TestUser] = proc(u: TestUser): ValidateResult =
      var errors: seq[string] = @[]
      if u.name.len == 0:
        errors.add("name is required")
      if u.age < 0:
        errors.add("age must be non-negative")
      ValidateResult(valid: errors.len == 0, errors: errors)

    let col = Collection(name: "test")

    let validUser = newModel(col, TestUser(name: "Alice", age: 30))
    let r1 = validUser.validate(validator)
    check r1.valid == true
    check r1.errors.len == 0

    let invalidUser = newModel(col, TestUser(name: "", age: -1))
    let r2 = invalidUser.validate(validator)
    check r2.valid == false
    check r2.errors.len == 2

  test "isValid shortcut":
    let validator: Validator[TestProduct] = proc(p: TestProduct): ValidateResult =
      ValidateResult(valid: p.price >= 0, errors: @[])

    let col = Collection(name: "products")
    let good = newModel(col, TestProduct(title: "Widget", price: 9.99))
    check good.isValid(validator) == true

    let bad = newModel(col, TestProduct(title: "Bad", price: -1.0))
    check bad.isValid(validator) == false

suite "ValidateResult":
  test "valid result":
    let r = ValidateResult(valid: true, errors: @[])
    check r.valid == true
    check r.errors.len == 0

  test "invalid result":
    let r = ValidateResult(valid: false, errors: @["error1", "error2"])
    check r.valid == false
    check r.errors.len == 2
    check r.errors[0] == "error1"
