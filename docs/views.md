# ArangoSearch Views

Full-text search views for ArangoDB.

## Creating an ArangoSearch View

```nim
import nim_arango
import std/json

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)
let db = client.createDatabase("myapp")
```

### Basic View

```nim
let view = db.createArangoSearchView("mySearch")
```

### View With Links

```nim
let view = db.createArangoSearchView("mySearch",
  withLinks(%*{
    "users": {
      "analyzers": ["text_en"],
      "fields": {
        "name": {"analyzers": ["text_en"]},
        "description": {"analyzers": ["text_en"]},
      },
      "includeAllFields": false,
    },
  }),
)
```

### View With Primary Sort & Stored Values

```nim
let view = db.createArangoSearchView("mySearch",
  withLinks(%*{
    "users": {
      "analyzers": ["text_en"],
      "includeAllFields": true,
    },
  }),
  withPrimarySort(%*[
    {"field": "createdAt", "direction": "desc"},
  ]),
  withStoredValues(%*[
    ["name", "email"],
  ]),
)
```

## Search Alias View

```nim
let aliasView = db.createSearchAliasView("myAlias",
  indexes = %*[
    {"collection": "users", "index": "name"},
    {"collection": "users", "index": "description"},
  ],
)
```

## View Properties

```nim
# Get properties
let props = view.properties()
echo props.cleanupIntervalStep
echo props.consolidationIntervalMsec
echo props.links

# Update properties
var newProps = ArangoSearchViewProperties(
  cleanupIntervalStep: 10,
  consolidationIntervalMsec: 500,
)
view.setProperties(newProps)
```

## Listing and Dropping Views

```nim
# List all views (Database level)
for v in db.views():
  echo v.name, " (", v.`type`, ")"

# Drop a view
view.drop()
```

## Using Views in Queries

Once a view is created, query it via AQL:

```nim
let cursor = db.query("""
  FOR doc IN mySearch
    SEARCH ANALYZER(doc.name == TOKENS("Alice", "text_en"), "text_en")
    SORT BM25(doc) DESC
    LIMIT 10
    RETURN doc
""").exec[JsonNode](db)

while cursor.next():
  let (doc, _) = cursor.read()
  echo doc

cursor.close()
```

## Types

```nim
type
  ArangoSearchViewProperties* = object
    cleanupIntervalStep*: int
    consolidationIntervalMsec*: int64
    consolidationPolicy*: JsonNode
    primarySort*: JsonNode
    storedValues*: JsonNode
    links*: JsonNode

  ViewInfo* = object
    name*: string
    id*: string
    `type`*: string
```

## Public API

```nim
# View creation (Database)
proc createArangoSearchView*(db: Database, name: string, optsArgs: varargs[CreateViewOption]): View
proc createSearchAliasView*(db: Database, name: string, indexes: JsonNode): View

# List views (Database)
proc views*(db: Database): seq[ViewInfo]

# View creation options
proc withLinks*(links: JsonNode): CreateViewOption
proc withPrimarySort*(sort: JsonNode): CreateViewOption
proc withStoredValues*(values: JsonNode): CreateViewOption

# View instance methods
proc properties*(v: View): ArangoSearchViewProperties
proc setProperties*(v: View, props: ArangoSearchViewProperties)
proc drop*(v: View)
```
