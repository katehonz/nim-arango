## Agency API — ArangoDB cluster coordination.

import std/[json, strformat]
import client, types

type
  AgencyOperation* = object
    op*: string
    key*: string
    value*: JsonNode
    old*: JsonNode
    ttl*: int

  AgencyTransaction* = object
    operations*: seq[AgencyOperation]

proc read*(c: Client, keys: varargs[string]): JsonNode =
  ## Read values from the agency.
  let body = %keys
  result = c.doRequestJson("POST", "_api/agency/read", $body)

proc write*(c: Client, ops: seq[AgencyOperation]): JsonNode =
  ## Write operations to the agency.
  var arr = newJArray()
  for op in ops:
    var node = newJObject()
    node[op.key] = %op.op
    if op.value != nil:
      node["val"] = op.value
    if op.old != nil:
      node["old"] = op.old
    if op.ttl > 0:
      node["ttl"] = %op.ttl
    arr.add(node)
  result = c.doRequestJson("POST", "_api/agency/write", $arr)

proc set*(c: Client, key: string, value: JsonNode, ttl: int = 0): JsonNode =
  ## Set a key in the agency.
  var op = AgencyOperation(op: "set", key: key, value: value, ttl: ttl)
  result = write(c, @[op])

proc delete*(c: Client, key: string): JsonNode =
  ## Delete a key from the agency.
  var op = AgencyOperation(op: "delete", key: key)
  result = write(c, @[op])

proc cas*(c: Client, key: string, value, old: JsonNode): JsonNode =
  ## Compare-and-swap operation.
  var op = AgencyOperation(op: "cas", key: key, value: value, old: old)
  result = write(c, @[op])

proc agencyConfig*(c: Client): JsonNode =
  ## Get agency configuration.
  result = c.doRequestJson("GET", "_api/agency/config")

proc agencyState*(c: Client): JsonNode =
  ## Get agency state.
  result = c.doRequestJson("GET", "_api/agency/state")
