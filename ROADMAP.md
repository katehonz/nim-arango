# Пътна карта за създаване на Nim ArangoDB Driver

## Съдържание
1. [Архитектурни цели](#архитектурни-цели)
2. [Фаза 0: Анализ на референтния Go драйвър](#фаза-0-анализ-на-референтния-go-драйвър)
3. [Фаза 1: Ядро — Connection & Transport](#фаза-1-ядро--connection--transport)
4. [Фаза 2: Client & Database API](#фаза-2-client--database-api)
5. [Фаза 3: Collection & Document API](#фаза-3-collection--document-api)
6. [Фаза 4: AQL Query & Cursor](#фаза-4-aql-query--cursor)
7. [Фаза 5: Graph, View, Index, Analyzer](#фаза-5-graph-view-index-analyzer)
8. [Фаза 6: Advanced — Transactions, Pregel, Foxx](#фаза-6-advanced--transactions-pregel-foxx)
9. [Фаза 7: Observability, Retry, Resilience](#фаза-7-observability-retry-resilience)
10. [Фаза 8: Тестове и Документация](#фаза-8-тестове-и-документация)

---

## Прогрес ✅

| Фаза | Статус | Бележки |
|------|--------|---------|
| 0. Анализ Go driver | ✅ Готово | go-driver/ проучен |
| 1. Transport | ✅ Готово | HTTP, retry, async |
| 2. Client & Database | ✅ Готово | server admin, JWT |
| 3. Collection & Document | ✅ Готово | Generics |
| 4. Query & Cursor | ✅ Готово | |
| 5. Graph/View/Index/Analyzer | ✅ Готово | inverted, fulltext, geo, TTL |
| 6. Transactions/Pregel/Foxx | ✅ Готово | status, running list |
| 7. Observability | ✅ Готово | logging, metrics, circuit |
| 8. Tests & Docs | ✅ Готово | 50 unit tests, 8 examples |

---

## Оставаща работа

### Приоритет 1 — Нужни преди release
- [x] Изчисти unused imports
- [x] Повече unit тестове
- [x] Примери: batch, transactions, async
- [x] Server Admin APIs (serverMode, shutdown, serverMetrics, serverStatistics)
- [x] Transaction status + running list
- [x] Cluster management (cleanOutServer, resignServer, removeServer, databaseInventory)
- [x] Index helpers (indexExists, getIndex, createInvertedIndex, createFulltextIndex)
- [x] Analyzer improvements (getAnalyzer, analyzerExists, force remove)

### Приоритет 2 — Подобрения
- [x] Compile-time document API generation macro (`documentApi(User)`)
- [x] ORM layer с macros (`Model[T]`, save/delete/refresh/findByKey/findWhere/validate)
- [ ] VST протокол поддръжка (complex, low priority)

### Приоритет 3 — След release
- [ ] Connection pool metrics
- [ ] Benchmarks vs Go driver
- [ ] Nimble package registry publish

---

## Архитектурни цели

### Предимства на Nim пред Go за database driver

| Характеристика | Go | Nim |
|---------------|----|-----|
| **Generics** | `func Read[T](key) Document[T]` — статично | `proc read[T](key: string): Document[T]` — по-мощни, концепти |
| **Макроси** | Няма | `generateDocumentApi(User)` — генерира типобезопасен API |
| **Compile-time** | `//go:generate` (външен инструмент) | `staticRead`, `compileTime`, `when` — вграден |
| **Memory** | GC | По избор: GC, ARC, ORC, None |
| **Error handling** | `if err != nil` навсякъде | `try/except` или `Result[T]` тип |
| **Async** | goroutines (runtime) | `{.async.}` + `asyncdispatch` — без тежък runtime |
| **Performance** | Компилиран, бърз | Компилиран (C/С++ бекенд), често по-бърз |

### Цели на Nim драйвъра

1. **Type-safe** — Nim generics + концепти за compile-time проверки
2. **Ergonomic API** — Nim method chaining, builder pattern, по-малко boilerplate
3. **Performant** — ARC/ORC memory, async I/O, connection pooling
4. **Resilient** — Вграден retry, failover между endpoint-и
5. **Observable** — Nim logging, metrics (Prometheus exporter)
6. **Testable** — Mockable types, integration test suite с Docker
7. **Well-documented** — Nim doc коментари, примери, tutorials

---

## Фаза 0: Анализ на референтния Go драйвър (1 ден)

### 0.1 Какво взимаме от Go драйвъра (go-driver/)
- Структура на API-тата (client, database, collection, document)
- HTTP request/response формат
- ArangoDB REST API endpoints
- Error кодове и обработка

### 0.2 Какво подобряваме с Nim
- Макроси вместо `interface{}` → compile-time генерация на типове
- `Result[T]` тип за error handling вместо `(T, error)` tuple
- `asyncdispatch` за неблокиращи заявки
- ARC memory за предвидима производителност

---

## Фаза 1: Ядро — Connection & Transport (3 дни)

### 1.1 Структура на проекта

```
nim-arango/
├── nim_arango.nimble          # Package manifest
├── src/
│   ├── nim_arango.nim         # Главен модул, public API
│   └── nim_arango/
│       ├── transport.nim      # Transport base type + Request/Response
│       ├── transport/
│       │   ├── http.nim       # HTTP транспорт с pooling
│       │   └── retry.nim      # Retry wrapper с exponential backoff
│       ├── auth.nim           # Basic, JWT, Raw аутентикация
│       ├── client.nim         # Client API + опции
│       ├── database.nim       # Database API
│       ├── collection.nim     # Collection API + WriteOpt
│       ├── document.nim       # Document API с generics [T]
│       ├── query.nim          # Query builder + Cursor[T] итератор
│       ├── graph.nim          # Graph API
│       ├── view.nim           # View/Analyzer API
│       ├── index.nim          # Index API
│       ├── transaction.nim    # Streaming transactions
│       ├── foxx.nim           # Foxx service API
│       ├── user.nim           # User management
│       ├── options.nim        # Functional options (ClientOption, DocumentOption, ...)
│       └── errors.nim         # ArangoError, error codes
├── examples/
│   ├── crud.nim               # Базови CRUD операции
│   ├── query.nim              # AQL заявки
│   └── graph.nim              # Работа с graphs
├── tests/
│   ├── test_transport.nim
│   ├── test_client.nim
│   ├── test_document.nim
│   └── test_query.nim
└── ROADMAP.md
```

### 1.2 Transport base type (src/nim_arango/transport.nim)

```nim
type
  Request* = ref object
    method*: string
    path*: string
    query*: Table[string, string]
    headers*: Table[string, string]
    body*: string

  Response* = ref object
    statusCode*: int
    headers*: Table[string, string]
    body*: string
    endpoint*: string

  Transport* = ref object of RootObj
    ## Base transport. Override methods.

method execute*(t: Transport, req: Request): Response {.base.} =
  raise newException(ValueError, "not implemented")

method endpoints*(t: Transport): seq[string] {.base.} =
  raise newException(ValueError, "not implemented")

method protocol*(t: Transport): Protocol {.base.} = protHTTP

method close*(t: Transport) {.base.} = discard
```

### 1.3 HTTP транспорт (src/nim_arango/transport/http.nim)

- `newHttpTransport(endpoints: seq[string])` — създава HTTP транспорт
- Connection pooling чрез `std/httpclient` (keep-alive)
- Random endpoint selection за клъстери
- Content-Type автоматично задаване
- x-arango-driver header

### 1.4 Retry wrapper (src/nim_arango/transport/retry.nim)

```nim
type
  RetryConfig* = object
    maxRetries*: int = 3
    initialBackoff*: Duration = 200.milliseconds
    maxBackoff*: Duration = 5.seconds
    backoffFactor*: float = 2.0
    retryOn*: seq[int] = @[429, 500, 502, 503, 504]

proc newRetryTransport*(inner: Transport, cfg: RetryConfig): Transport
```

---

## Фаза 2: Client & Database API (2 дни)

### 2.1 Client API

```nim
type Client* = ref object
  transport*: Transport
  auth: Authenticator

proc newClient*(opts: varargs[ClientOption]): Client

# Database management
proc database*(c: Client, name: string): Database
proc databases*(c: Client): seq[DatabaseInfo]
proc createDatabase*(c: Client, name: string, opts: varargs[CreateDatabaseOption]): Database
proc dropDatabase*(c: Client, name: string)

# Server info
proc version*(c: Client): VersionInfo
proc license*(c: Client): LicenseInfo

# Lifecycle
proc close*(c: Client)
```

### 2.2 Functional Options

```nim
type
  ClientOption* = proc(cfg: var ClientConfig)

proc withEndpoint*(endpoint: string): ClientOption
proc withEndpoints*(endpoints: varargs[string]): ClientOption
proc withBasicAuth*(username, password: string): ClientOption
proc withJwtAuth*(username, password: string): ClientOption
proc withRawAuth*(value: string): ClientOption
proc withTimeout*(ms: int): ClientOption
proc withUserAgent*(ua: string): ClientOption
proc withRetryConfig*(cfg: RetryConfig): ClientOption
```

### 2.3 Database API

```nim
type Database* = ref object
  client: Client
  name: string

# Properties
proc name*(db: Database): string
proc info*(db: Database): DatabaseInfo
proc remove*(db: Database)

# Collections
proc collection*(db: Database, name: string): Collection
proc collections*(db: Database): seq[CollectionInfo]
proc createCollection*(db: Database, name: string, opts: varargs[CreateCollectionOption]): Collection
proc dropCollection*(db: Database, name: string)

# Views
proc views*(db: Database): seq[ViewInfo]

# Query
proc query*(db: Database, aql: string): Query
```

---

## Фаза 3: Collection & Document API (3 дни)

### 3.1 Collection

```nim
type Collection* = ref object
  db: Database
  name: string

# Метаданни
proc name*(c: Collection): string
proc count*(c: Collection): int64
proc properties*(c: Collection): CollectionProperties

# Управление
proc truncate*(c: Collection)
proc load*(c: Collection)
proc unload*(c: Collection)
proc rename*(c: Collection, newName: string)
proc drop*(c: Collection)
```

### 3.2 Document API с Nim Generics — НАЙ-ГОЛЯМАТА ИНОВАЦИЯ

```nim
type
  DocumentMeta* = object
    key* {.json: "_key".}: string
    id* {.json: "_id".}: string
    rev* {.json: "_rev".}: string

  Document*[T] = object
    meta*: DocumentMeta
    data*: T

  DocumentResult*[T] = object
    meta*: DocumentMeta
    doc*: T       ## returned document
    old*: Option[T]  ## returnOld
    newDoc*: Option[T]  ## returnNew

# CRUD с generics
proc createDocument*[T](col: Collection, doc: T, opts: varargs[WriteOpt]): DocumentMeta
proc readDocument*[T](col: Collection, key: string, opts: varargs[WriteOpt]): Document[T]
proc updateDocument*[T](col: Collection, key: string, patch: T, opts: varargs[WriteOpt]): DocumentMeta
proc replaceDocument*[T](col: Collection, key: string, doc: T, opts: varargs[WriteOpt]): DocumentMeta
proc removeDocument*(col: Collection, key: string, opts: varargs[WriteOpt]): DocumentMeta
proc documentExists*(col: Collection, key: string): bool
```

### 3.3 WriteOpt (document options)

```nim
type WriteOpt* = proc(wc: var WriteConfig)

proc withReturnNew*(): WriteOpt
proc withReturnOld*(): WriteOpt
proc withWaitForSync*(): WriteOpt
proc withSilent*(): WriteOpt
proc withKeepNull*(v: bool): WriteOpt
proc withMergeObjects*(v: bool): WriteOpt
proc withIgnoreRevs*(): WriteOpt
proc withOverwriteMode*(mode: string): WriteOpt
proc withRevision*(rev: string): WriteOpt
proc withIfMatch*(rev: string): WriteOpt
```

---

## Фаза 4: AQL Query & Cursor (2 дни)

### 4.1 Query Builder

```nim
type Query* = ref object
  db: Database
  aql: string
  bindVars: Table[string, JsonNode]
  opts: Table[string, JsonNode]

proc newQuery*(aql: string): Query

# Method chaining
proc bind*[T](q: Query, name: string, value: T): Query
proc batchSize*(q: Query, n: int): Query
proc fullCount*(q: Query): Query
proc profile*(q: Query, level: int): Query
proc maxRuntime*(q: Query, seconds: float): Query
proc memoryLimit*(q: Query, bytes: int64): Query
proc cache*(q: Query, enabled: bool): Query

# Execution
proc exec*[T](q: Query): Cursor[T]
proc execOne*[T](q: Query): T
proc execExplain*(q: Query): ExplainResult
```

### 4.2 Cursor[T] итератор

```nim
type Cursor*[T] = ref object
  db: Database
  id: string
  count: int64
  items: seq[JsonNode]
  hasMore: bool
  pos: int
  error: ref CatchableError
  currentData: T
  currentMeta: DocumentMeta

# Iterator pattern
proc next*(c: Cursor[T]): bool
proc read*(c: Cursor[T]): (T, DocumentMeta)
proc error*(c: Cursor[T]): ref CatchableError
proc close*(c: Cursor[T])

# Convenience
proc count*(c: Cursor[T]): int64
proc all*[T](c: Cursor[T]): seq[Document[T]]
proc each*[T](c: Cursor[T], fn: proc(doc: Document[T]))
```

**Примерна употреба:**

```nim
type User = object
  name: string
  age: int

let cursor = db.query("FOR u IN users FILTER u.age > @age RETURN u")
  .bind("age", 18)
  .exec[User]()

defer: cursor.close()

while cursor.next():
  let (user, meta) = cursor.read()
  echo &"User {meta.key}: {user.name} (age {user.age})"

if cursor.error() != nil:
  echo "Query error: ", cursor.error().msg
```

---

## Фаза 5: Graph, View, Index, Analyzer (3 дни)

### 5.1 Graph API

```nim
type Graph* = ref object
  db: Database
  name: string

proc name*(g: Graph): string
proc info*(g: Graph): GraphInfo
proc drop*(g: Graph)

# Traversal — връща Cursor[T]
proc traversal*[T](g: Graph, startVertex: string, opts: varargs[TraverseOpt]): Cursor[T]
```

### 5.2 Views

```nim
type
  View* = ref object of RootObj
  ArangoSearchView* = ref object of View
  ArangoSearchAliasView* = ref object of View

proc createArangoSearchView*(db: Database, name: string, opts: varargs[CreateViewOption]): ArangoSearchView
proc properties*(v: View): ViewProperties
proc setProperties*(v: View, props: ViewProperties)
```

### 5.3 Indexes

```nim
type IndexType* = enum
  idxPersistent, idxTTL, idxGeo, idxFulltext, idxZKD, idxInverted

proc indexes*(col: Collection): seq[IndexInfo]
proc createIndex*(col: Collection, typ: IndexType, fields: seq[string], opts: varargs[CreateIndexOption]): Index
proc dropIndex*(col: Collection, name: string)
```

### 5.4 Analyzers

```nim
type Analyzer* = ref object
  db: Database
  name: string

proc analyzers*(db: Database): seq[AnalyzerInfo]
proc createAnalyzer*(db: Database, name: string, opts: varargs[AnalyzerOption]): Analyzer
proc remove*(a: Analyzer)
```

---

## Фаза 6: Advanced — Transactions, Pregel, Foxx (2 дни)

### 6.1 Streaming Transactions

```nim
type Transaction* = ref object
  id: string
  db: Database

proc beginTransaction*(db: Database, opts: varargs[TransactionOption]): Transaction
proc commit*(tx: Transaction)
proc abort*(tx: Transaction)
proc id*(tx: Transaction): string

# Transaction-scoped операции
proc query*(tx: Transaction, aql: string): Query
proc collection*(tx: Transaction, name: string): Collection
```

### 6.2 Pregel API

```nim
proc startPregelJob*(db: Database, opts: varargs[PregelOption]): string  # returns job ID
proc getPregelJob*(db: Database, id: string): PregelJobInfo
proc cancelPregelJob*(db: Database, id: string)
proc listPregelJobs*(db: Database): seq[PregelJobInfo]
```

### 6.3 Foxx API

```nim
proc installFoxxService*(c: Client, dbName, mount: string, zipPath: string, opts: varargs[FoxxOption])
proc uninstallFoxxService*(c: Client, dbName, mount: string)
proc replaceFoxxService*(c: Client, dbName, mount: string, zipPath: string, opts: varargs[FoxxOption])
proc listFoxxServices*(c: Client, dbName: string): seq[FoxxServiceInfo]
```

---

## Фаза 7: Observability, Retry, Resilience (2 дни)

### 7.1 Structured Logging

```nim
import std/logging

# Всички вътрешни логове ползват std/logging
# Нива: lvlDebug, lvlInfo, lvlWarn, lvlError
# Ключове: method, path, status_code, duration, endpoint, retry_count
```

### 7.2 Retry & Circuit Breaker

```nim
type
  RetryConfig* = object
    maxRetries*: int
    initialBackoff*: Duration
    maxBackoff*: Duration
    backoffFactor*: float64
    retryOn*: seq[int]  # HTTP статус кодове

  CircuitBreakerConfig* = object
    failureThreshold*: int
    successThreshold*: int
    timeout*: Duration
```

### 7.3 Metrics (Prometheus/Statsd)

- `nim_arango_requests_total`
- `nim_arango_request_duration_seconds`
- `nim_arango_connection_pool_size`
- `nim_arango_retries_total`

---

## Фаза 8: Тестове и Документация (3 дни)

### 8.1 Unit тестове
- Mock `Transport` за unit тестове без ArangoDB
- Тестове за всяка публична процедура
- Table-driven тестове с Nim `suite`/`test`

### 8.2 Integration тестове
- Docker Compose с ArangoDB (single + cluster)
- Test fixtures
- Тестове за CRUD, AQL, Graph, Transaction
- Тестове за retry и failover

### 8.3 Benchmarks
- Сравнение с Go драйвъра
- Bulk insert performance
- Query cursor performance
- Concurrency benchmarks (async vs sync)

### 8.4 Документация
- `nim doc` коментари на всички публични procs
- README с quick start
- `/examples` с работещи примери
- `nim doc --project src/nim_arango.nim` за HTML документация

---

## Сравнение: Go драйвър vs Nim драйвър

| Характеристика | Go (`go-driver/`) | Nim (този проект) |
|---------------|-------------|-------------|
| **Типизиране** | `interface{}` → Generics `T any` | Generics `[T]` + концепти |
| **Опции** | `func(...ClientOption)` | `proc/varargs[ClientOption]` |
| **Connection** | HTTP/2 pool | HTTP keep-alive + pool |
| **Retry** | Exponential backoff | Exponential backoff + jitter |
| **Cursor** | `for cursor.Next()` | `while cursor.next()` |
| **Error handling** | `(T, error)` | `try/except` + ArangoError |
| **Async** | goroutines (heavy) | `{.async.}` (lightweight) |
| **Макроси** | Няма | Compile-time API генерация |
| **Memory** | GC | ARC/ORC (optional GC) |
| **Документация** | GoDoc | `nim doc` (вграден) |

---

## Nim-специфични подобрения спрямо Go

1. **Макроси за compile-time типобезопасност**
```nim
macro documentApi(colName: static string, T: typedesc): untyped =
  ## Генерира типобезопасен API за конкретна колекция
  quote do:
    proc `create colName`(doc: `T`): DocumentMeta = createDocument[`T`](`colName`, doc)
    proc `read colName`(key: string): Document[`T`] = readDocument[`T`](`colName`, key)
```

2. **{.async.} за неблокиращи заявки**
```nim
proc createDocumentAsync*[T](col: Collection, doc: T): Future[DocumentMeta] {.async.}
```

3. **ARC memory — без GC затихвания**
```nim
{.push arc.}
# Целият драйвър ползва ARC — детерминистично освобождаване на памет
```

4. **Compile-time endpoint validation**
```nim
static:
  for ep in endpoints:
    assert ep.startsWith("http"), "Invalid endpoint: " & ep
```

---

## График (общо ~16 работни дни)

| Фаза | Дни | Седмица |
|------|-----|---------|
| Фаза 1 — Transport | 3 дена | 1 |
| Фаза 2 — Client/Database | 2 дена | 1-2 |
| Фаза 3 — Collection/Document (generics) | 3 дена | 2 |
| Фаза 4 — Query/Cursor | 2 дена | 3 |
| Фаза 5 — Graph/View/Index/Analyzer | 3 дена | 3 |
| Фаза 6 — Advanced (Transactions, Pregel, Foxx) | 2 дена | 4 |
| Фаза 7 — Observability, Retry | 2 дена | 4 |
| Фаза 8 — Тестове, Документация | 3 дена | 5 |
| **Общо** | **~20 дена** | **~4 седмици** |

---

## Ключови технологични решения

1. **Nim 2.2+** — стабилни generics, ARC памет, подобрен `std/httpclient`
2. **Само HTTP+JSON** — VST протоколът е прекалено сложен; HTTP+JSON е достатъчно бърз за 95% от случаите
3. **ARC memory по подразбиране** — предвидима производителност, без GC паузи
4. **Async опционален** — и sync, и async API за различни use-cases
5. **Backwards incompatible** с Go API-то — нов, по-добър Nim-идиоматичен API

---

## Open Questions / Рискове

- [ ] ARC или ORC memory — кое е по-стабилно в production?
- [ ] Трябва ли async да е по подразбиране или opt-in?
- [ ] Как да handle-ваме `_id` формата при multi-database?
- [ ] Поддръжка на ArangoDB версии — 3.11+ или и по-стари?
- [ ] Нужен ли е ORM layer над драйвъра (object mapping macros)?
- [ ] Как да интегрираме с Nimble package registry?
