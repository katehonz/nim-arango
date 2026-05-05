## User management API.

import std/[json, strformat]
import client, types

type
  UserInfo* = object
    user*: string
    active*: bool
    extra*: JsonNode

  UserPermissions* = object
    database*: string
    collection*: string
    permission*: string

proc users*(c: Client): seq[UserInfo] =
  let j = c.doRequestJson("GET", "_api/user")
  result = @[]
  for node in j{"result"}.getElems():
    result.add(UserInfo(
      user: node{"user"}.getStr(""),
      active: node{"active"}.getBool(true),
      extra: node{"extra"},
    ))

proc createUser*(c: Client, username, password: string, active: bool = true, extra: JsonNode = nil): UserInfo =
  var body = %*{
    "user": username,
    "passwd": password,
    "active": active,
  }
  if extra != nil:
    body["extra"] = extra
  let j = c.doRequestJson("POST", "_api/user", $body)
  result = UserInfo(
    user: j{"user"}.getStr(""),
    active: j{"active"}.getBool(true),
    extra: j{"extra"},
  )

proc removeUser*(c: Client, username: string) =
  discard c.doRequestJson("DELETE", "_api/user/" & username)

proc user*(c: Client, username: string): UserInfo =
  let j = c.doRequestJson("GET", "_api/user/" & username)
  result = UserInfo(
    user: j{"user"}.getStr(""),
    active: j{"active"}.getBool(true),
    extra: j{"extra"},
  )

proc setPassword*(c: Client, username, password: string) =
  let body = %*{ "passwd": password }
  discard c.doRequestJson("PUT", "_api/user/" & username & "/password", $body)

proc setActive*(c: Client, username: string, active: bool) =
  let body = %*{ "active": active }
  discard c.doRequestJson("PUT", "_api/user/" & username, $body)

proc databaseAccess*(c: Client, username, database: string): string =
  let j = c.doRequestJson("GET", "_api/user/" & username & "/database/" & database)
  result = j{"result"}.getStr("none")

proc setDatabaseAccess*(c: Client, username, database, permission: string) =
  let body = %*{ "grant": permission }
  discard c.doRequestJson("PUT", "_api/user/" & username & "/database/" & database, $body)

proc collectionAccess*(c: Client, username, database, collection: string): string =
  let j = c.doRequestJson("GET", "_api/user/" & username & "/database/" & database & "/" & collection)
  result = j{"result"}.getStr("none")

proc setCollectionAccess*(c: Client, username, database, collection, permission: string) =
  let body = %*{ "grant": permission }
  discard c.doRequestJson("PUT", "_api/user/" & username & "/database/" & database & "/" & collection, $body)
