# nim-arango

Модерен, **типобезопасен ArangoDB драйвър за Nim**.

## Възможности

- **Типобезопасни документи** с Nim generics — `readDocument[User](key)` връща `Document[User]`
- **Fluent query builder** с method chaining и AQL параметри
- **Connection pooling** чрез `std/httpclient` с keep-alive
- **Retry с експоненциално забавяне** — конфигурируем за всеки клиент
- **Graph API** — обхождания, edge дефиниции, vertex колекции
- **ArangoSearch Views** — конфигурация за пълнотекстово търсене
- **Управление на индекси** — persistent, geo, TTL, inverted и други
- **Streaming transactions** — ACID в множество операции
- **Pregel** — разпределен графов анализ
- **Foxx** — управление на микросървиси
- **Управление на потребители** — права и контрол на достъп

## Инсталация

```bash
nimble install nim_arango
```

Или добави в `.nimble` файла:

```nim
requires "nim_arango >= 0.1.0"
```

## Бърз старт

```nim
import nim_arango

type User = object
  name: string
  email: string
  age: int

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)

let db = client.createDatabase("myapp")
let users = db.createCollection("users")

# Създаване
let meta = users.createDocument(User(name: "Алиса", email: "alice@example.com", age: 30))
echo "Създаден: ", meta.key

# Четене (типобезопасно!)
let doc = users.readDocument[User](meta.key)
echo "Прочетен: ", doc.data.name, " (", doc.data.age, ")"

# Заявка с параметри
let cursor = db.query("FOR u IN users FILTER u.age > @age RETURN u")
  .bindParam("age", 18)
  .batchSize(100)
  .exec[User]()

while cursor.next():
  let (user, m) = cursor.read()
  echo user.name

cursor.close()
client.close()
```

## Преглед на API

### Client

```nim
let client = newClient(
  withEndpoints("http://node1:8529", "http://node2:8529"),
  withBasicAuth("root", "password"),
  withTimeout(10000),
  withRetryConfig(maxRetries = 5)
)

let version = client.version()
let db = client.database("mydb")
```

### Database

```nim
let db = client.createDatabase("newdb")
db.dropCollection("oldcol")
let col = db.createCollection("users", withNumberOfShards(3))
```

### Collection & Documents

```nim
let users = db.collection("users")

# CRUD с generics
let meta = users.createDocument(User(name: "Алиса", age: 30))
let doc = users.readDocument[User](meta.key)
users.updateDocument(meta.key, User(name: "Алиса Обновена", age: 31))
users.replaceDocument(meta.key, User(name: "Боб", age: 25))
users.removeDocument(meta.key)

# Масово вмъкване
let metas = users.createDocuments(@[u1, u2, u3])
```

### Query

```nim
let cursor = db.query("FOR p IN products FILTER p.price > @min RETURN p")
  .bindParam("min", 10.0)
  .fullCount()
  .exec[Product]()

let all = cursor.all()
cursor.close()
```

### Graph

```nim
let g = db.createGraph("social", @[
  EdgeDefinition(
    collection: "follows",
    fromCollections: @["people"],
    toCollections: @["people"]
  )
])

let cursor = g.traversal[Person]("people/alice",
  withDirection("outbound"),
  withMaxDepth(3)
)
```

### Index

```nim
discard col.createIndex(idxPersistent, @["email"], withUnique(true))
discard col.createGeoIndex(@["location"], geoJson = true)
discard col.createTTLIndex("createdAt", 3600)
```

### View

```nim
let view = db.createArangoSearchView("searchView",
  withLinks(%*{ "users": { "fields": { "name": { "analyzers": ["text_en"] }}})
)
```

## Структура на проекта

```
src/nim_arango/
├── transport.nim       # Базов транспорт + Request/Response
├── transport/
│   ├── http.nim        # HTTP транспорт с keep-alive
│   └── retry.nim       # Retry wrapper с backoff
├── auth.nim            # Basic, JWT, Raw автентикация
├── errors.nim          # ArangoError типове и кодове
├── options.nim         # Functional options pattern
├── types.nim           # Основни типове
├── client.nim          # Client API
├── database.nim        # Database API
├── collection.nim      # Collection API
├── document.nim        # Document CRUD с generics
├── query.nim           # AQL query builder + Cursor[T]
├── graph.nim           # Graph API
├── view.nim            # ArangoSearch views
├── index.nim           # Управление на индекси
├── analyzer.nim        # Текстови анализатори
├── pregel.nim          # Pregel задачи
├── foxx.nim            # Foxx сървиси
└── user.nim            # Управление на потребители
```

## Тестване

```bash
nimble test
```

## Пътна карта

Виж [ROADMAP.md](ROADMAP.md) за пълния план за разработка.

## Лиценз

MIT
