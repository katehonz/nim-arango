## Bulk import API for high-performance data loading.

import std/[json, strformat, strutils]
import client, collection, types

type
  ImportConfig* = object
    waitForSync*: bool
    complete*: bool
    details*: bool
    overwrite*: bool
    onDuplicate*: string  ## "error", "update", "replace", "ignore"

proc importDocuments*[T](col: Collection, docs: seq[T], cfg: ImportConfig = ImportConfig()): JsonNode =
  ## Bulk import documents into a collection.
  ## Returns detailed import statistics.
  var body = newJArray()
  for doc in docs:
    body.add(%doc)

  var qs = "?collection=" & col.name
  if cfg.waitForSync: qs &= "&waitForSync=true"
  if cfg.complete: qs &= "&complete=true"
  if cfg.details: qs &= "&details=true"
  if cfg.overwrite: qs &= "&overwrite=true"
  if cfg.onDuplicate.len > 0: qs &= "&onDuplicate=" & cfg.onDuplicate

  result = col.db.client.doRequestJson("POST", "_api/import" & qs, $body)

proc importJsonLines*(col: Collection, lines: seq[string], cfg: ImportConfig = ImportConfig()): JsonNode =
  ## Import documents from JSON Lines format.
  var qs = "?type=auto&collection=" & col.name
  if cfg.waitForSync: qs &= "&waitForSync=true"
  if cfg.complete: qs &= "&complete=true"
  if cfg.details: qs &= "&details=true"
  if cfg.overwrite: qs &= "&overwrite=true"
  if cfg.onDuplicate.len > 0: qs &= "&onDuplicate=" & cfg.onDuplicate

  let body = lines.join("\n")
  result = col.db.client.doRequestJson("POST", "_api/import" & qs, body)
