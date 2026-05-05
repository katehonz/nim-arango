## Health check and cluster monitoring API.

import std/[json, strformat]
import client, types

type
  ClusterHealth* = object
    status*: string
    agency*: JsonNode
    nodes*: seq[NodeHealth]

  NodeHealth* = object
    endpoint*: string
    status*: string
    version*: string
    uptime*: int

  ServerRole* = enum
    srSingle = "SINGLE"
    srCoordinator = "COORDINATOR"
    srPrimary = "PRIMARY"
    srAgent = "AGENT"
    srUndefined = "UNDEFINED"

proc serverRole*(c: Client): ServerRole =
  let j = c.doRequestJson("GET", "_admin/server/role")
  case j{"role"}.getStr("UNDEFINED")
  of "SINGLE": srSingle
  of "COORDINATOR": srCoordinator
  of "PRIMARY": srPrimary
  of "AGENT": srAgent
  else: srUndefined

proc clusterHealth*(c: Client): ClusterHealth =
  let j = c.doRequestJson("GET", "_admin/cluster/health")
  var nodes: seq[NodeHealth] = @[]
  if j.hasKey("Health"):
    for k, v in j["Health"]:
      nodes.add(NodeHealth(
        endpoint: v{"Endpoint"}.getStr(""),
        status: v{"Status"}.getStr(""),
        version: v{"Version"}.getStr(""),
        uptime: v{"Uptime"}.getInt(0),
      ))
  result = ClusterHealth(
    status: j{"status"}.getStr(""),
    agency: j{"agency"},
    nodes: nodes,
  )

proc ping*(c: Client): bool =
  try:
    let resp = c.doRequest("GET", "_api/version")
    result = resp.statusCode == 200
  except CatchableError:
    result = false

proc isAvailable*(c: Client): bool =
  ## Check if the server is reachable.
  ping(c)
