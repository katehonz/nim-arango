## Cluster management API.

import std/[json, strformat]
import client, types

type
  ClusterEndpoint* = object
    endpoint*: string
    version*: string
    status*: string

  ClusterStatistics* = object
    dbServers*: int
    coordinators*: int
    agents*: int

proc clusterEndpoints*(c: Client): seq[ClusterEndpoint] =
  let j = c.doRequestJson("GET", "_api/cluster/endpoints")
  result = @[]
  if j.hasKey("endpoints"):
    for ep in j["endpoints"].getElems():
      result.add(ClusterEndpoint(
        endpoint: ep{"endpoint"}.getStr(""),
        version: ep{"version"}.getStr(""),
        status: ep{"status"}.getStr(""),
      ))

proc clusterStatistics*(c: Client): ClusterStatistics =
  let j = c.doRequestJson("GET", "_api/cluster/statistics")
  result = ClusterStatistics(
    dbServers: j{"dbServers"}.getInt(0),
    coordinators: j{"coordinators"}.getInt(0),
    agents: j{"agents"}.getInt(0),
  )

proc clusterHealth*(c: Client): JsonNode =
  result = c.doRequestJson("GET", "_api/cluster/health")

proc moveShard*(c: Client, database, collection, shard, fromServer, toServer: string): JsonNode =
  let body = %*{
    "database": database,
    "collection": collection,
    "shard": shard,
    "fromServer": fromServer,
    "toServer": toServer,
  }
  result = c.doRequestJson("PUT", "_api/cluster/moveShard", $body)

proc rebalanceShards*(c: Client, database: string = ""): JsonNode =
  var body = newJObject()
  if database.len > 0:
    body["database"] = %database
  result = c.doRequestJson("PUT", "_api/cluster/rebalanceShards", $body)
