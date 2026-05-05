## Client API — entry point for the ArangoDB driver.
##
## Provides database management, server info, and lifecycle control.

import std/[json, strformat, tables, options]
import transport, transport/http, auth, errors, options as opts, types

proc newClient*(optsArgs: varargs[ClientOption]): Client =
  var cfg = ClientConfig(retryOn: defaultRetryOn())
  for opt in optsArgs:
    opt(cfg)

  if cfg.endpoints.len == 0:
    raise newException(ValueError, "client: at least one endpoint required")

  let tr = newHttpTransport(cfg.endpoints, cfg.timeout, cfg.userAgent)
  if cfg.driverInfo.len > 0:
    tr.setDriverInfo(cfg.driverInfo)

  result = Client(transport: tr, auth: cfg.auth, cfg: cfg)

proc doRequest*(c: Client, verb, path: string, body = ""): Response =
  var req = newRequest(verb, path)
  if body.len > 0:
    discard req.setBody(body)
  if c.auth != nil:
    c.auth.apply(req)
  result = c.transport.execute(nil, req)
  raiseOnError(result.body, result.statusCode)

proc doRequestJson*(c: Client, verb, path: string, body = ""): JsonNode =
  let resp = c.doRequest(verb, path, body)
  result = parseJson(resp.body)

# --- Database management ---

proc databases*(c: Client): seq[DatabaseInfo] =
  let j = c.doRequestJson("GET", "_api/database")
  result = @[]
  for name in j["result"].getElems():
    result.add(DatabaseInfo(name: name.getStr()))

proc database*(c: Client, name: string): Database =
  ## Return a Database handle (does not verify existence).
  Database(client: c, name: name)

proc createDatabase*(c: Client, name: string, users: seq[tuple[username: string, password: string]] = @[]): Database =
  var body = %*{"name": name}
  if users.len > 0:
    var userArr = newJArray()
    for u in users:
      userArr.add(%*{"username": u.username, "passwd": u.password})
    body["users"] = userArr

  discard c.doRequestJson("POST", "_api/database", $body)
  result = Database(client: c, name: name)

proc dropDatabase*(c: Client, name: string) =
  discard c.doRequestJson("DELETE", "_api/database/" & name)

# --- Server info ---

proc version*(c: Client): VersionInfo =
  let j = c.doRequestJson("GET", "_api/version")
  result = VersionInfo(
    server: j{"server"}.getStr("arango"),
    license: j{"license"}.getStr("community"),
    version: j{"version"}.getStr(""),
  )

proc license*(c: Client): string =
  let j = c.doRequestJson("GET", "_api/admin/license")
  result = j{"license"}.getStr("")

# --- Lifecycle ---

proc close*(c: Client) =
  c.transport.close()

# --- JWT helpers ---

proc jwtLogin*(c: Client) =
  ## Perform JWT login if JWT auth is configured.
  if c.auth of JwtAuth:
    let jwt = JwtAuth(c.auth)
    let body = %*{
      "username": jwt.username,
      "password": jwt.password,
    }
    let j = c.doRequestJson("POST", "_open/auth", $body)
    jwt.token = j{"jwt"}.getStr("")

proc jwtRefresh*(c: Client) =
  ## Refresh an existing JWT token.
  if c.auth of JwtAuth:
    let jwt = JwtAuth(c.auth)
    if jwt.token.len == 0:
      raise newException(ValueError, "auth: no token to refresh")
    let body = %*{"jwt": jwt.token}
    let j = c.doRequestJson("POST", "_open/auth", $body)
    jwt.token = j{"jwt"}.getStr("")
