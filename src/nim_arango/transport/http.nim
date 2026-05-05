## HTTP transport implementation with connection pooling via std/httpclient.

import std/[httpclient, strutils, uri, random]
import ../transport

type
  HttpTransport* = ref object of Transport
    endpoints: seq[string]
    client: HttpClient
    userAgent: string
    driverInfo: string
    closed: bool

proc newHttpTransport*(endpoints: seq[string], timeout: int = 30000, userAgent = "nim-arango-driver"): HttpTransport =
  if endpoints.len == 0:
    raise newException(ValueError, "http: at least one endpoint required")

  let normEndpoints = normalizeEndpoints(endpoints)

  let client = newHttpClient(timeout = timeout)
  client.headers["User-Agent"] = userAgent
  client.headers["Connection"] = "keep-alive"

  HttpTransport(
    endpoints: normEndpoints,
    client: client,
    userAgent: userAgent,
  )

proc normalizeEndpoints(endpoints: seq[string]): seq[string] =
  for ep in endpoints:
    var e = ep.strip(chars = {'/'})
    if not (e.startsWith("http://") or e.startsWith("https://")):
      e = "http://" & e
    result.add e

proc pickEndpoint(ht: HttpTransport): string =
  if ht.endpoints.len == 1:
    return ht.endpoints[0]
  rand(ht.endpoints.len)
  ht.endpoints[rand(ht.endpoints.len - 1)]

method execute*(ht: HttpTransport, ctx: pointer, req: Request): Response =
  if ht.closed:
    raise newException(ValueError, "http: connection closed")

  let endpoint = ht.pickEndpoint()
  var fullUrl = endpoint & "/" & req.path
  let qs = req.queryString()
  if qs.len > 0:
    fullUrl &= qs

  for k, v in req.headers:
    ht.client.headers[k] = v
  if ht.userAgent.len > 0 and "User-Agent" notin req.headers:
    ht.client.headers["User-Agent"] = ht.userAgent
  if ht.driverInfo.len > 0:
    ht.client.headers["x-arango-driver"] = ht.driverInfo

  var respBody: string
  var statusCode: int
  var respHeaders = initTable[string, string]()

  try:
    case req.method
    of "GET":
      respBody = ht.client.getContent(fullUrl)
    of "POST":
      ht.client.headers["Content-Type"] = "application/json"
      respBody = ht.client.postContent(fullUrl, body = req.body)
    of "PUT":
      ht.client.headers["Content-Type"] = "application/json"
      respBody = ht.client.putContent(fullUrl, body = req.body)
    of "PATCH":
      ht.client.headers["Content-Type"] = "application/json"
      respBody = ht.client.request(fullUrl, httpMethod = HttpPatch, body = req.body).body
    of "DELETE":
      respBody = ht.client.deleteContent(fullUrl)
    else:
      raise newException(ValueError, "http: unsupported method: " & req.method)
    statusCode = 200
  except HttpRequestError as e:
    raise newException(ValueError, "http: request failed: " & e.msg)
  except CatchableError as e:
    raise newException(ValueError, "http: " & e.msg)

  for k, v in ht.client.headers.pairs:
    respHeaders[k] = v

  Response(statusCode: statusCode, headers: respHeaders, body: respBody, endpoint: endpoint)

method endpoints*(ht: HttpTransport): seq[string] = ht.endpoints

method protocol*(ht: HttpTransport): Protocol = protHTTP

method close*(ht: HttpTransport) =
  ht.closed = true
  ht.client.close()

proc setUserAgent*(ht: HttpTransport, ua: string) =
  ht.userAgent = ua

proc setDriverInfo*(ht: HttpTransport, info: string) =
  ht.driverInfo = info
