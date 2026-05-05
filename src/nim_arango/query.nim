## AQL Query builder and Cursor iterator.

import std/[json, tables, strformat]
import client, database, types, errors

proc newQuery*(aql: string): Query =
  Query(aql: aql, bindVars: initTable[string, JsonNode](), opts: initTable[string, JsonNode]())

proc bindParam*[T](q: Query, name: string, value: T): Query =
  when T is string:
    q.bindVars[name] = %value
  elif T is int or T is int64:
    q.bindVars[name] = %value.int64
  elif T is float:
    q.bindVars[name] = %value
  elif T is bool:
    q.bindVars[name] = %value
  elif T is object or T is tuple:
    q.bindVars[name] = %value
  else:
    q.bindVars[name] = %($value)
  result = q

proc batchSize*(q: Query, n: int): Query =
  q.opts["batchSize"] = %n
  result = q

proc fullCount*(q: Query): Query =
  q.opts["fullCount"] = %true
  result = q

proc profile*(q: Query, level: int): Query =
  q.opts["profile"] = %level
  result = q

proc maxRuntime*(q: Query, seconds: float): Query =
  q.opts["maxRuntime"] = %seconds
  result = q

proc memoryLimit*(q: Query, bytes: int64): Query =
  q.opts["memoryLimit"] = %bytes
  result = q

proc cache*(q: Query, enabled: bool): Query =
  q.opts["cache"] = %enabled
  result = q

proc execImpl(q: Query, db: Database): JsonNode =
  var body = %*{
    "query": q.aql,
    "bindVars": {},
    "options": {},
  }
  for k, v in q.bindVars:
    body["bindVars"][k] = v
  for k, v in q.opts:
    body["options"][k] = v

  result = db.client.doRequestJson("POST", "_api/cursor", $body)

proc exec*[T](q: Query, db: Database): Cursor[T] =
  let j = execImpl(q, db)
  let hasMore = j{"hasMore"}.getBool(false)
  let id = j{"id"}.getStr("")
  var items: seq[JsonNode] = @[]
  if j.hasKey("result"):
    for node in j["result"].getElems():
      items.add(node)
  result = Cursor[T](
    db: db,
    id: id,
    count: j{"count"}.getInt(-1).int64,
    items: items,
    hasMore: hasMore,
    pos: 0,
  )

proc execOne*[T](q: Query, db: Database): T =
  let j = execImpl(q, db)
  if j.hasKey("result") and j["result"].len > 0:
    result = j["result"][0].to(T)
  else:
    raise newException(ValueError, "query returned no results")

proc execExplain*(q: Query, db: Database): JsonNode =
  var body = %*{
    "query": q.aql,
    "bindVars": {},
  }
  for k, v in q.bindVars:
    body["bindVars"][k] = v
  result = db.client.doRequestJson("POST", "_api/explain", $body)

# --- Cursor methods ---

proc fetchMore[T](c: Cursor[T]) =
  if c.id.len == 0 or not c.hasMore:
    return
  let j = c.db.client.doRequestJson("PUT", "_api/cursor/" & c.id)
  c.hasMore = j{"hasMore"}.getBool(false)
  c.items = @[]
  c.pos = 0
  if j.hasKey("result"):
    for node in j["result"].getElems():
      c.items.add(node)

proc next*[T](c: Cursor[T]): bool =
  if c.pos >= c.items.len:
    if c.hasMore:
      c.fetchMore()
    else:
      return false
  result = c.pos < c.items.len

proc read*[T](c: Cursor[T]): (T, DocumentMeta) =
  if c.pos >= c.items.len:
    raise newException(ValueError, "cursor: no more items")
  let node = c.items[c.pos]
  c.pos += 1

  var dataNode = node
  var meta = DocumentMeta(
    key: node{"_key"}.getStr(""),
    id: node{"_id"}.getStr(""),
    rev: node{"_rev"}.getStr(""),
  )
  dataNode.delete("_key")
  dataNode.delete("_id")
  dataNode.delete("_rev")
  dataNode.delete("_oldRev")

  result = (dataNode.to(T), meta)

proc count*[T](c: Cursor[T]): int64 =
  result = c.count

proc all*[T](c: Cursor[T]): seq[Document[T]] =
  result = @[]
  while c.next():
    let (data, meta) = c.read()
    result.add(Document[T](meta: meta, data: data))

proc each*[T](c: Cursor[T], fn: proc(doc: Document[T])) =
  while c.next():
    let (data, meta) = c.read()
    fn(Document[T](meta: meta, data: data))

proc close*[T](c: Cursor[T]) =
  if c.id.len > 0:
    try:
      discard c.db.client.doRequest("DELETE", "_api/cursor/" & c.id)
    except CatchableError:
      discard
  c.hasMore = false
  c.items = @[]
