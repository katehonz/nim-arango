import std/[unittest, json, tables]
import ../src/nim_arango/[query, types]

suite "Query Builder":
  test "newQuery creates empty query":
    let q = newQuery("FOR u IN users RETURN u")
    check q.aql == "FOR u IN users RETURN u"
    check q.bindVars.len == 0
    check q.opts.len == 0

  test "bindParam string":
    let q = newQuery("FOR u IN users FILTER u.name == @name RETURN u")
      .bindParam("name", "Alice")
    check q.bindVars["name"] == %"Alice"

  test "bindParam int":
    let q = newQuery("FOR u IN users FILTER u.age > @age RETURN u")
      .bindParam("age", 18)
    check q.bindVars["age"] == %(18.int64)

  test "bindParam float":
    let q = newQuery("FOR p IN products FILTER p.price > @price RETURN p")
      .bindParam("price", 99.9)
    check q.bindVars["price"] == %99.9

  test "bindParam bool":
    let q = newQuery("FOR u IN users FILTER u.active == @active RETURN u")
      .bindParam("active", true)
    check q.bindVars["active"] == %true

  test "bindParam chains":
    let q = newQuery("FOR u IN users FILTER u.age > @age AND u.active == @active RETURN u")
      .bindParam("age", 18)
      .bindParam("active", true)
    check q.bindVars["age"] == %(18.int64)
    check q.bindVars["active"] == %true

  test "batchSize sets option":
    let q = newQuery("FOR u IN users RETURN u").batchSize(50)
    check q.opts["batchSize"] == %50

  test "fullCount sets option":
    let q = newQuery("FOR u IN users RETURN u").fullCount()
    check q.opts["fullCount"] == %true

  test "profile sets option":
    let q = newQuery("FOR u IN users RETURN u").profile(2)
    check q.opts["profile"] == %2

  test "maxRuntime sets option":
    let q = newQuery("FOR u IN users RETURN u").maxRuntime(5.5)
    check q.opts["maxRuntime"] == %5.5

  test "memoryLimit sets option":
    let q = newQuery("FOR u IN users RETURN u").memoryLimit(1024000)
    check q.opts["memoryLimit"] == %(1024000.int64)

  test "cache sets option":
    let q = newQuery("FOR u IN users RETURN u").cache(true)
    check q.opts["cache"] == %true

  test "method chaining":
    let q = newQuery("FOR u IN users FILTER u.age > @age RETURN u")
      .bindParam("age", 18)
      .batchSize(100)
      .fullCount()
    check q.bindVars["age"] == %(18.int64)
    check q.opts["batchSize"] == %100
    check q.opts["fullCount"] == %true

suite "Query Options":
  test "buildQueryOptions string":
    let q = newQuery("FOR u IN users RETURN u")
      .cache(true)
      .profile(1)
    check q.opts["cache"] == %true
    check q.opts["profile"] == %1
