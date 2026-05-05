## Transport layer for ArangoDB driver.
## Defines the Transport base type, Request/Response types, and protocol constants.

import std/[tables, strformat, strutils, algorithm]

type
  Protocol* = enum
    protHTTP = "http"
    protVST = "vst"

  Request* = ref object
    verb*: string
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
    ## Base transport type. Override `execute`, `endpoints`, `protocol`, `close` via inheritance.

method execute*(t: Transport, ctx: pointer, req: Request): Response {.base.} =
  raise newException(ValueError, "Transport.execute not implemented")

method endpoints*(t: Transport): seq[string] {.base.} =
  raise newException(ValueError, "Transport.endpoints not implemented")

method protocol*(t: Transport): Protocol {.base.} =
  raise newException(ValueError, "Transport.protocol not implemented")

method close*(t: Transport) {.base.} =
  discard

proc newRequest*(verb, path: string): Request =
  Request(verb: verb, path: path, query: initTable[string, string](), headers: initTable[string, string]())

proc setQuery*(r: Request, key, value: string): Request =
  r.query[key] = value
  r

proc setHeader*(r: Request, key, value: string): Request =
  r.headers[key] = value
  r

proc setBody*(r: Request, body: string): Request =
  r.body = body
  r

proc queryString*(r: Request): string =
  if r.query.len == 0:
    return ""
  var parts: seq[string]
  var keys: seq[string]
  for k in r.query.keys:
    keys.add k
  keys.sort()
  for k in keys:
    parts.add k & "=" & r.query[k]
  "?" & parts.join("&")
