## ORM layer for nim-arango.
##
## Provides a higher-level abstraction over the document API with:
## - `Model[T]` wrapper that tracks collection + metadata
## - Instance methods: `save()`, `delete()`, `refresh()`
## - Class-level finders: `findByKey()`, `findAll()`, `findWhere()`
## - Field validation via `validate()` callback
## - Automatic key generation support
##
## Usage:
## ```nim
## import nim_arango
##
## type User = object
##   name: string
##   email: string
##   age: int
##
## let client = newClient(withEndpoint("http://localhost:8529"), withBasicAuth("root", "password"))
## let db = client.createDatabase("myapp")
## let users = db.createCollection("users")
##
## # Create
## var alice = newUser(users, User(name: "Alice", email: "alice@example.com", age: 30))
## alice.save()
##
## # Find
## let found = users.findByKey[User](alice.meta.key)
## let all = users.findAll[User]()
##
## # Update + save
## found.data.age = 31
## found.save()
##
## # Delete
## found.delete()
## ```

import std/[json]
import collection, document, query, types, options as opts

type
  Model*[T] = ref object
    ## A document wrapper that tracks its collection and metadata.
    col*: Collection
    meta*: DocumentMeta
    data*: T
    isNew*: bool

  ValidateResult* = object
    valid*: bool
    errors*: seq[string]

  Validator*[T] = proc(doc: T): ValidateResult

proc newModel*[T](col: Collection, data: T, key: string = ""): Model[T] =
  ## Create a new model instance. If key is empty, ArangoDB will auto-generate one.
  var meta = DocumentMeta(key: key)
  Model[T](col: col, meta: meta, data: data, isNew: true)

proc newModelFromDoc*[T](col: Collection, doc: Document[T]): Model[T] =
  ## Create a model from an existing document read from the database.
  Model[T](col: col, meta: doc.meta, data: doc.data, isNew: false)

proc save*[T](m: Model[T], optsArgs: varargs[WriteOpt]): DocumentMeta =
  ## Save the model to the database. Creates if new, replaces if existing.
  if m.isNew:
    let meta = createDocument[T](m.col, m.data, optsArgs)
    m.meta = meta
    m.isNew = false
    result = meta
  else:
    result = replaceDocument[T](m.col, m.meta.key, m.data, optsArgs)
    m.meta.rev = result.rev

proc delete*[T](m: Model[T], optsArgs: varargs[WriteOpt]): DocumentMeta =
  ## Delete the model from the database.
  result = removeDocument(m.col, m.meta.key, optsArgs)
  m.isNew = true

proc refresh*[T](m: Model[T]) =
  ## Re-read the model from the database to get the latest version.
  let doc = readDocument[T](m.col, m.meta.key)
  m.data = doc.data
  m.meta = doc.meta

proc key*[T](m: Model[T]): string = m.meta.key
proc id*[T](m: Model[T]): string = m.meta.id
proc rev*[T](m: Model[T]): string = m.meta.rev

# --- Class-level finders ---

proc findByKey*[T](col: Collection, key: string, optsArgs: varargs[WriteOpt]): Model[T] =
  ## Find a document by key and return it as a Model.
  let doc = readDocument[T](col, key, optsArgs)
  result = newModelFromDoc[T](col, doc)

proc findAll*[T](col: Collection, optsArgs: varargs[WriteOpt]): seq[Model[T]] =
  ## Find all documents in the collection.
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  let j = col.db.client.doRequestJson("GET", "_api/document/" & col.name & qs)
  result = @[]
  for node in j.getElems():
    var dataNode = node
    dataNode.delete("_key")
    dataNode.delete("_id")
    dataNode.delete("_rev")
    dataNode.delete("_oldRev")
    let doc = Document[T](
      meta: parseDocumentMeta(node),
      data: fromJson[T](dataNode),
    )
    result.add(newModelFromDoc[T](col, doc))

proc findWhere*[T](col: Collection, filter: string, bindVars: JsonNode = %*{}): seq[Model[T]] =
  ## Find documents matching an AQL FILTER expression.
  ## The filter should be a valid AQL filter clause, e.g. "doc.age > @age".
  let aql = "FOR doc IN " & col.name & " FILTER " & filter & " RETURN doc"
  var q = col.db.query(aql)
  for k, v in bindVars:
    q = q.bindParam(k, v)
  let cursor = exec[T](q, col.db)
  result = @[]
  while cursor.next():
    let (data, meta) = cursor.read()
    result.add(Model[T](col: col, meta: meta, data: data, isNew: false))
  cursor.close()

proc countDocuments*[T](col: Collection): int64 =
  ## Count documents in the collection.
  result = col.count()

proc exists*[T](col: Collection, key: string): bool =
  ## Check if a document exists.
  result = documentExists(col, key)

proc removeByKey*(col: Collection, key: string, optsArgs: varargs[WriteOpt]): DocumentMeta =
  ## Remove a document by key.
  result = removeDocument(col, key, optsArgs)

# --- Query helpers ---

proc findByQuery*[T](col: Collection, aql: string, bindVars: JsonNode = %*{}): seq[Model[T]] =
  ## Find documents using a custom AQL query.
  ## The query should return documents of type T.
  var q = col.db.query(aql)
  for k, v in bindVars:
    q = q.bindParam(k, v)
  let cursor = exec[T](q, col.db)
  result = @[]
  while cursor.next():
    let (data, meta) = cursor.read()
    result.add(Model[T](col: col, meta: meta, data: data, isNew: false))
  cursor.close()

# --- Validation ---

proc validate*[T](m: Model[T], validator: Validator[T]): ValidateResult =
  ## Run a validation function on the model's data.
  result = validator(m.data)

proc isValid*[T](m: Model[T], validator: Validator[T]): bool =
  ## Check if the model passes validation.
  result = validator(m.data).valid

# --- Batch ORM operations ---

proc saveAll*[T](models: var seq[Model[T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
  ## Save multiple models at once.
  result = @[]
  for m in models:
    result.add(m.save(optsArgs))

proc deleteAll*[T](models: var seq[Model[T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
  ## Delete multiple models at once.
  result = @[]
  for m in models:
    result.add(m.delete(optsArgs))
