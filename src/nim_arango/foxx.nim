## Foxx API — microservice management.

import std/[json, strformat, os, uri]
import client, transport, types, auth

type
  FoxxOption* = proc(cfg: var FoxxConfig)

  FoxxConfig* = object
    mount*: string
    teardown*: bool = true
    setup*: bool = true
    legacy*: bool = false
    force*: bool = false

  FoxxServiceInfo* = object
    mount*: string
    name*: string
    version*: string
    development*: bool
    legacy*: bool
    provides*: seq[JsonNode]
    scripts*: seq[string]

proc withTeardown*(v: bool): FoxxOption =
  proc opt(cfg: var FoxxConfig) = cfg.teardown = v
  opt

proc withSetup*(v: bool): FoxxOption =
  proc opt(cfg: var FoxxConfig) = cfg.setup = v
  opt

proc withLegacy*(v: bool): FoxxOption =
  proc opt(cfg: var FoxxConfig) = cfg.legacy = v
  opt

proc withForce*(): FoxxOption =
  proc opt(cfg: var FoxxConfig) = cfg.force = true
  opt

proc installFoxxService*(c: Client, dbName, mount, zipPath: string, optsArgs: varargs[FoxxOption]) =
  var cfg = FoxxConfig(mount: mount)
  for opt in optsArgs:
    opt(cfg)

  let url = "_api/foxx?mount=" & encodeUrl(mount)
  let body = readFile(zipPath)
  var req = newRequest("POST", url)
  discard req.setBody(body)
  discard req.setHeader("Content-Type", "application/zip")
  if c.auth != nil:
    c.auth.apply(req)
  discard c.transport.execute(nil, req)

proc uninstallFoxxService*(c: Client, dbName, mount: string, teardown: bool = true) =
  var url = "_api/foxx/service?mount=" & encodeUrl(mount)
  if teardown:
    url &= "&teardown=true"
  discard c.doRequest("DELETE", url)

proc replaceFoxxService*(c: Client, dbName, mount, zipPath: string, optsArgs: varargs[FoxxOption]) =
  var cfg = FoxxConfig(mount: mount)
  for opt in optsArgs:
    opt(cfg)

  let url = "_api/foxx/service?mount=" & encodeUrl(mount) & "&teardown=" & $cfg.teardown & "&setup=" & $cfg.setup
  let body = readFile(zipPath)
  var req = newRequest("PUT", url)
  discard req.setBody(body)
  discard req.setHeader("Content-Type", "application/zip")
  if c.auth != nil:
    c.auth.apply(req)
  discard c.transport.execute(nil, req)

proc listFoxxServices*(c: Client, dbName: string): seq[FoxxServiceInfo] =
  let j = c.doRequestJson("GET", "_api/foxx")
  result = @[]
  for node in j.getElems():
    var scripts: seq[string] = @[]
    if node.hasKey("scripts"):
      for s in node["scripts"].getElems():
        scripts.add(s.getStr())
    var provides: seq[JsonNode] = @[]
    if node.hasKey("provides"):
      for p in node["provides"].getElems():
        provides.add(p)
    result.add(FoxxServiceInfo(
      mount: node{"mount"}.getStr(""),
      name: node{"name"}.getStr(""),
      version: node{"version"}.getStr(""),
      development: node{"development"}.getBool(false),
      legacy: node{"legacy"}.getBool(false),
      provides: provides,
      scripts: scripts,
    ))
