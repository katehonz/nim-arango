## Batch document operations for efficient bulk processing.

import std/[json, options, strformat]
import client, collection, document, types, errors, options as opts

proc documentBatch*[T](col: Collection, docs: seq[T], verb: string, optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
  ## Generic batch operation for create/update/replace documents.
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  var arr = newJArray()
  for doc in docs:
    arr.add(parseJson(toJson[T](doc)))
  let j = col.db.client.doRequestJson(verb, "_api/document/" & col.name & qs, $arr)
  result = @[]
  for node in j.getElems():
    result.add(parseDocumentMeta(node))

proc updateDocuments*[T](col: Collection, docs: seq[tuple[key: string, patch: T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
  ## Batch update documents by key.
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  var arr = newJArray()
  for item in docs:
    var node = parseJson(toJson[T](item.patch))
    node["_key"] = %item.key
    arr.add(node)
  let j = col.db.client.doRequestJson("PATCH", "_api/document/" & col.name & qs, $arr)
  result = @[]
  for node in j.getElems():
    result.add(parseDocumentMeta(node))

proc replaceDocuments*[T](col: Collection, docs: seq[tuple[key: string, doc: T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
  ## Batch replace documents by key.
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  var arr = newJArray()
  for item in docs:
    var node = parseJson(toJson[T](item.doc))
    node["_key"] = %item.key
    arr.add(node)
  let j = col.db.client.doRequestJson("PUT", "_api/document/" & col.name & qs, $arr)
  result = @[]
  for node in j.getElems():
    result.add(parseDocumentMeta(node))

proc removeDocuments*(col: Collection, keys: seq[string], optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
  ## Batch remove documents by key.
  let cfg = buildWriteConfig(optsArgs)
  let qs = buildWriteQueryString(cfg)
  var arr = newJArray()
  for key in keys:
    arr.add(%key)
  let j = col.db.client.doRequestJson("DELETE", "_api/document/" & col.name & qs, $arr)
  result = @[]
  for node in j.getElems():
    result.add(parseDocumentMeta(node))
