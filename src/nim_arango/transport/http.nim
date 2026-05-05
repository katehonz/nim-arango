## HTTP transport implementation with connection pooling via std/httpclient.

import std/[httpclient, strutils, uri, random, tables, times]
import ../transport, ../logging, ../metrics

proc normalizeEndpoints(endpoints: seq[string]): seq[string] =
  for ep in endpoints:
    var e = ep.strip(chars = {'/'})
    if not (e.startsWith("http://") or e.startsWith("https://")):
      e = "http://" & e
    result.add e

type
  HttpTransport* = ref object of Transport
    endpoints: seq[string]
    client: HttpClient
    userAgent: string
    driverInfo: string
    closed: bool

proc newHttpTransport*(endpoints: seq[string], timeout: int = 30000, userAgent = "nim-arango-driver/0.1.0"): HttpTransport =
  if endpoints.len == 0:
    raise newException(ValueError, "http: at least one endpoint required")

  let normEndpoints = normalizeEndpoints(endpoints)
  randomize()

  let client = newHttpClient(timeout = timeout)
  client.headers["User-Agent"] = userAgent
  client.headers["Connection"] = "keep-alive"
  client.headers["Accept"] = "application/json"

  HttpTransport(
    endpoints: normEndpoints,
    client: client,
    userAgent: userAgent,
  )

proc pickEndpoint(ht: HttpTransport): string =
  if ht.endpoints.len == 1:
    return ht.endpoints[0]
  ht.endpoints[rand(ht.endpoints.len - 1)]

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

method execute*(ht: HttpTransport, ctx: pointer, req: Request): transport.Response =
  if ht.closed:
    raise newException(ValueError, "http: connection closed")

  let endpoint = ht.pickEndpoint()
  var fullUrl = endpoint & "/" & req.path.strip(chars = {'/'})
  let qs = req.queryString()
  if qs.len > 0:
    fullUrl &= qs

  # Save original headers to restore later
  let originalHeaders = ht.client.headers

  # Apply request-specific headers
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
  try:
    let httpResp = ht.client.request(fullUrl, httpMethod = verbToHttpMethod(req.verb), body = req.body)
    let statusCode = httpResp.code.int
    let durationMs = (getTime() - startTime).inMilliseconds

    var respHeaders = initTable[string, string]()
    for k, v in httpResp.headers.pairs:
      respHeaders[k] = v

    let body = httpResp.body
    resp = transport.Response(
      statusCode: statusCode,
      headers: respHeaders,
      body: body,
      endpoint: endpoint,
    )

    logRequest(req.verb, req.path, statusCode, durationMs, endpoint)

    # Metrics
    let reqCounter = getOrCreateCounter("nim_arango_requests_total")
    reqCounter.inc()
    let hist = getOrCreateHistogram("nim_arango_request_duration_seconds", @[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0])
    hist.observe(durationMs.float64 / 1000.0)

  except CatchableError as e:
    # Restore headers even on error
    ht.client.headers = originalHeaders
    logError("http: request failed: " & e.msg)
    let errCounter = getOrCreateCounter("nim_arango_request_errors_total")
    errCounter.inc()
    raise newException(ValueError, "http: request failed: " & e.msg)

  # Restore original headers
  ht.client.headers = originalHeaders
  resp

method endpoints*(ht: HttpTransport): seq[string] = ht.endpoints

method protocol*(ht: HttpTransport): Protocol = protHTTP

method close*(ht: HttpTransport) =
  ht.closed = true
  ht.client.close()

proc setUserAgent*(ht: HttpTransport, ua: string) =
  ht.userAgent = ua

proc setDriverInfo*(ht: HttpTransport, info: string) =
  ht.driverInfo = info
