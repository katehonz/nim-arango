import std/[unittest, json, tables]
import ../src/nim_arango/[client, types, options, transport, collection]

suite "Client Options":
  test "ClientOption builds config":
    var cfg = ClientConfig(retryOn: defaultRetryOn())
    let opt = withEndpoint("http://localhost:8529")
    opt(cfg)
    check cfg.endpoints == @["http://localhost:8529"]

  test "multiple options combine":
    var cfg = ClientConfig(retryOn: defaultRetryOn())
    let opt1 = withEndpoint("http://host1:8529")
    let opt2 = withTimeout(5000)
    opt1(cfg)
    opt2(cfg)
    check cfg.endpoints == @["http://host1:8529"]
    check cfg.timeout == 5000

suite "Write Options":
  test "WriteOpt modifies config":
    var cfg = WriteConfig(keepNull: true, mergeObjects: true, ignoreRevs: true)
    let opt = withWaitForSync()
    opt(cfg)
    check cfg.waitForSync == true

  test "buildWriteQueryString":
    var cfg = WriteConfig(keepNull: true, mergeObjects: true, ignoreRevs: true)
    cfg.returnNew = true
    cfg.waitForSync = true
    let qs = buildWriteQueryString(cfg)
    check qs == "?returnNew=true&waitForSync=true&keepNull=true&mergeObjects=true&ignoreRevs=true"
