## Async HTTP transport wrapper using std/asyncdispatch.

import std/[asyncdispatch, httpclient, strutils, tables, uri, random, times]
import ../transport, ../logging

proc normalizeEndpoints(endpoints: seq[string]): seq[string] =
  for ep in endpoints:
    var e = ep.strip(chars = {'/'})
    if not (e.startsWith("http://") or e.startsWith("https://")):
      e = "http://" & e
    result.add e

proc verbToHttpMethod(m: string): HttpMethod =
  case m.toUpperAscii()
  of "GET": HttpGet
  of "POST": HttpPost
  of "PUT": HttpPut
  of "PATCH": HttpPatch
  of "DELETE": HttpDelete
  of "HEAD": HttpHead
  of "OPTIONS": HttpOptions
  else: raise newException(ValueError, "http: unsupported verb: " & m)

type
  AsyncHttpTransport* = ref object of Transport
    endpoints: seq[string]
    client: AsyncHttpClient
    userAgent: string
    driverInfo: string
    closed: bool

proc newAsyncHttpTransport*(endpoints: seq[string], timeout: int = 30000, userAgent = "nim-arango-driver/0.1.0"): AsyncHttpTransport =
  if endpoints.len == 0:
    raise newException(ValueError, "http: at least one endpoint required")

  let normEndpoints = normalizeEndpoints(endpoints)
  randomize()

  let client = newAsyncHttpClient()
  client.headers["User-Agent"] = userAgent
  client.headers["Connection"] = "keep-alive"
  client.headers["Accept"] = "application/json"

  AsyncHttpTransport(
    endpoints: normEndpoints,
    client: client,
    userAgent: userAgent,
  )

proc pickEndpoint(ht: AsyncHttpTransport): string =
  if ht.endpoints.len == 1:
    return ht.endpoints[0]
  ht.endpoints[rand(ht.endpoints.len - 1)]

method execute*(ht: AsyncHttpTransport, ctx: pointer, req: Request): transport.Response =
  ## Synchronous wrapper for async transport.
  ## For true async, use `executeAsync` directly.
  if ht.closed:
    raise newException(ValueError, "http: connection closed")

  let endpoint = ht.pickEndpoint()
  var fullUrl = endpoint & "/" & req.path.strip(chars = {'/'})
  let qs = req.queryString()
  if qs.len > 0:
    fullUrl &= qs

  let originalHeaders = ht.client.headers

  for k, v in req.headers.pairs:
    ht.client.headers[k] = v

  if ht.userAgent.len > 0 and not req.headers.hasKey("User-Agent"):
    ht.client.headers["User-Agent"] = ht.userAgent
  if ht.driverInfo.len > 0:
    ht.client.headers["x-arango-driver"] = ht.driverInfo
  if req.body.len > 0 and not req.headers.hasKey("Content-Type"):
    ht.client.headers["Content-Type"] = "application/json"

  let startTime = getTime()
  var resp: transport.Response

  proc doRequest(): Future[void] {.async.} =
    let httpResp = await ht.client.request(fullUrl, httpMethod = verbToHttpMethod(req.verb), body = req.body)
    let statusCode = httpResp.code.int
    let durationMs = (getTime() - startTime).inMilliseconds

    var respHeaders = initTable[string, string]()
    for k, v in httpResp.headers.pairs:
      respHeaders[k] = v

    let body = await httpResp.body
    resp = transport.Response(
      statusCode: statusCode,
      headers: respHeaders,
      body: body,
      endpoint: endpoint,
    )
    logRequest(req.verb, req.path, statusCode, durationMs, endpoint)

  waitFor doRequest()
  ht.client.headers = originalHeaders
  resp

method endpoints*(ht: AsyncHttpTransport): seq[string] = ht.endpoints

method protocol*(ht: AsyncHttpTransport): Protocol = protHTTP

method close*(ht: AsyncHttpTransport) =
  ht.closed = true
  ht.client.close()

proc setUserAgent*(ht: AsyncHttpTransport, ua: string) =
  ht.userAgent = ua

proc setDriverInfo*(ht: AsyncHttpTransport, info: string) =
  ht.driverInfo = info
