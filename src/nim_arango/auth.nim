## Authentication strategies for ArangoDB.
##
## Supports Basic Auth, JWT, and raw header authentication.

import std/[base64, json, tables, strformat]
import transport, errors

type
  Authenticator* = ref object of RootObj
    ## Base authenticator type.

  BasicAuth* = ref object of Authenticator
    username*: string
    password*: string

  JwtAuth* = ref object of Authenticator
    username*: string
    password*: string
    token*: string

  RawAuth* = ref object of Authenticator
    value*: string

method apply*(a: Authenticator, req: Request) {.base.} =
  ## Apply authentication to an outgoing request.
  discard

method apply*(a: BasicAuth, req: Request) =
  let credentials = base64.encode(a.username & ":" & a.password)
  req.headers["Authorization"] = "Basic " & credentials

method apply*(a: JwtAuth, req: Request) =
  if a.token.len > 0:
    req.headers["Authorization"] = "Bearer " & a.token

proc newBasicAuth*(username, password: string): BasicAuth =
  BasicAuth(username: username, password: password)

proc newJwtAuth*(username, password: string): JwtAuth =
  JwtAuth(username: username, password: password, token: "")

proc newRawAuth*(value: string): RawAuth =
  RawAuth(value: value)

method apply*(a: RawAuth, req: Request) =
  req.headers["Authorization"] = a.value
