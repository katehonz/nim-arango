## nim-arango
##
## A modern, type-safe ArangoDB driver for Nim.
##
## ## Quick Start
##
## ```nim
## import nim_arango
##
## let client = newClient(
##   withEndpoint("http://localhost:8529"),
##   withBasicAuth("root", "password")
## )
##
## let db = client.database("mydb")
## let col = db.collection("users")
##
## type User = object
##   name: string
##   age: int
##
## let meta = col.createDocument(User(name: "Alice", age: 30))
## echo "Created: ", meta.key
##
## let doc = col.readDocument[User](meta.key)
## echo "Read: ", doc.data.name
##
## client.close()
## ```

import nim_arango/[transport, transport/http, transport/retry, transport/async, auth, errors, options, types, client, database, collection, document, query, graph, view, index, analyzer, pregel, foxx, user, logging, batch, health, circuit, import_api, backup, replication, cluster, metrics, agency, macros, orm]

export transport, http, retry, async, auth, errors, options, types, client, database, collection, document, query, graph, view, index, analyzer, pregel, foxx, user, logging, batch, health, circuit, import_api, backup, replication, cluster, metrics, agency, macros, orm
