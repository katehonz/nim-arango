## Retry transport wrapper with exponential backoff and jitter.

import std/[random, times, math, os]
import ../transport

type
  RetryConfig* = object
    maxRetries*: int = 3
    initialBackoff*: Duration = initDuration(milliseconds = 200)
    maxBackoff*: Duration = initDuration(seconds = 5)
    backoffFactor*: float = 2.0
    retryOn*: seq[int] = @[429, 500, 502, 503, 504]

  RetryTransport* = ref object of Transport
    inner*: Transport
    cfg*: RetryConfig

proc newRetryTransport*(inner: Transport, cfg: RetryConfig): RetryTransport =
  randomize()
  RetryTransport(inner: inner, cfg: cfg)

proc shouldRetry(cfg: RetryConfig, statusCode: int): bool =
  statusCode in cfg.retryOn

proc sleepWithBackoff(attempt: int, cfg: RetryConfig) =
  let base = cfg.initialBackoff.inMilliseconds.float * pow(cfg.backoffFactor, attempt.float)
  let capped = min(base, cfg.maxBackoff.inMilliseconds.float)
  let jitter = rand(capped)
  sleep(int(jitter))

method execute*(rt: RetryTransport, ctx: pointer, req: Request): transport.Response =
  var lastError: ref CatchableError
  for attempt in 0 ..< rt.cfg.maxRetries + 1:
    try:
      let resp = rt.inner.execute(ctx, req)
      if resp.statusCode >= 200 and resp.statusCode < 300:
        return resp
      if not shouldRetry(rt.cfg, resp.statusCode):
        return resp
      lastError = newException(ValueError, "HTTP " & $resp.statusCode)
    except CatchableError as e:
      lastError = e

    if attempt < rt.cfg.maxRetries:
      sleepWithBackoff(attempt, rt.cfg)

  raise newException(ValueError, "retry: all attempts failed: " & lastError.msg)

method endpoints*(rt: RetryTransport): seq[string] = rt.inner.endpoints()

method protocol*(rt: RetryTransport): Protocol = rt.inner.protocol()

method close*(rt: RetryTransport) = rt.inner.close()
