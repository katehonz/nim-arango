import std/[unittest, tables]
import ../src/nim_arango/transport

suite "Transport Request/Response":
  test "newRequest creates correct request":
    let req = newRequest("GET", "_api/version")
    check req.verb == "GET"
    check req.path == "_api/version"
    check req.query.len == 0
    check req.headers.len == 0

  test "setQuery builds query string":
    let req = newRequest("GET", "_api/collection")
      .setQuery("excludeSystem", "true")
      .setQuery("sortBy", "name")
    check req.queryString() == "?excludeSystem=true&sortBy=name"

  test "setHeader adds headers":
    let req = newRequest("POST", "_api/document/users")
      .setHeader("Content-Type", "application/json")
    check req.headers["Content-Type"] == "application/json"

  test "empty query string":
    let req = newRequest("GET", "_api/version")
    check req.queryString() == ""
