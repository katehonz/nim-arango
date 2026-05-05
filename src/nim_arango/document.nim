## Document API with Nim generics.
##
## Type-safe CRUD operations using Nim's powerful generic system.

import std/[json, options, strformat]
import client, collection, types, errors, options as opts

proc toJson*[T](doc: T): string =
  ## Serialize a Nim object to JSON.
  ## Works for objects, tuples, and basic types.
  when T is object or T is tuple:
    result = $(%doc)
  elif T is string:
    result = escapeJson(doc)
  elif T is int or T is int64 or T is float or T is bool:
    result = $doc
  else:
    result = $(%doc)

proc fromJson*[T](j: JsonNode): T =
  ## Deserialize JSON to a Nim object.
  when T is object or T is tuple:
    result = j.to(T)
  elif T is string:
    result = j.getStr()
  elif T is int:
    result = j.getInt()
  elif T is int64:
    result = j.getInt().int64
  elif T is float:
    result = j.getFloat()
  elif T is bool:
    result = j.getBool()
  else:
    result = j.to(T)

proc buildWriteConfig*(optsArgs: varargs[WriteOpt]): WriteConfig =
  result = WriteConfig(keepNull: true, mergeObjects: true, ignoreRevs: true)
  for opt in optsArgs:
    opt(result)

proc createDocument*[T](col: Collection, doc: T, optsArgs: varargs[WriteOpt]): DocumentMeta =
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  let body = toJson[T](doc)
  let j = col.db.client.doRequestJson("POST", "_api/document/" & col.name & qs, body)
  result = parseDocumentMeta(j)

proc readDocument*[T](col: Collection, key: string, optsArgs: varargs[WriteOpt]): Document[T] =
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  let j = col.db.client.doRequestJson("GET", "_api/document/" & col.name & "/" & key & qs)
  let meta = parseDocumentMeta(j)

  # Remove ArangoDB metadata fields before deserializing user data
  var dataNode = j
  dataNode.delete("_key")
  dataNode.delete("_id")
  dataNode.delete("_rev")
  dataNode.delete("_oldRev")

  result = Document[T](
    meta: meta,
    data: fromJson[T](dataNode),
  )

proc updateDocument*[T](col: Collection, key: string, patch: T, optsArgs: varargs[WriteOpt]): DocumentMeta =
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  let body = toJson[T](patch)
  let j = col.db.client.doRequestJson("PATCH", "_api/document/" & col.name & "/" & key & qs, body)
  result = parseDocumentMeta(j)

proc replaceDocument*[T](col: Collection, key: string, doc: T, optsArgs: varargs[WriteOpt]): DocumentMeta =
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  let body = toJson[T](doc)
  let j = col.db.client.doRequestJson("PUT", "_api/document/" & col.name & "/" & key & qs, body)
  result = parseDocumentMeta(j)

proc removeDocument*(col: Collection, key: string, optsArgs: varargs[WriteOpt]): DocumentMeta =
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  let j = col.db.client.doRequestJson("DELETE", "_api/document/" & col.name & "/" & key & qs)
  result = parseDocumentMeta(j)

proc documentExists*(col: Collection, key: string): bool =
  try:
    let resp = col.db.client.doRequest("HEAD", "_api/document/" & col.name & "/" & key)
    result = resp.statusCode == 200
  except ArangoError:
    result = false

# --- Bulk operations ---

proc createDocuments*[T](col: Collection, docs: seq[T], optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  var arr = newJArray()
  for doc in docs:
    arr.add(parseJson(toJson[T](doc)))
  let j = col.db.client.doRequestJson("POST", "_api/document/" & col.name & qs, $arr)
  result = @[]
  for node in j.getElems():
    result.add(parseDocumentMeta(node))
