## Circuit Breaker pattern for resilient connections.

import std/[times, locks]
import transport, logging

type
  CircuitState* = enum
    csClosed     ## Normal operation
    csOpen       ## Failing, reject requests
    csHalfOpen   ## Testing if recovered

  CircuitBreakerConfig* = object
    failureThreshold*: int = 5
    successThreshold*: int = 3
    timeout*: Duration = initDuration(seconds = 30)

  CircuitBreakerTransport* = ref object of Transport
    inner*: Transport
    cfg*: CircuitBreakerConfig
    state*: CircuitState
    failureCount*: int
    successCount*: int
    lastFailureTime*: Time
    lock*: Lock

proc newCircuitBreakerTransport*(inner: Transport, cfg: CircuitBreakerConfig): CircuitBreakerTransport =
  result = CircuitBreakerTransport(
    inner: inner,
    cfg: cfg,
    state: csClosed,
  )
  initLock(result.lock)

proc canAttempt(cb: CircuitBreakerTransport): bool =
  withLock cb.lock:
    case cb.state
    of csClosed:
      result = true
    of csOpen:
      if getTime() - cb.lastFailureTime > cb.cfg.timeout:
        cb.state = csHalfOpen
        cb.successCount = 0
        result = true
      else:
        result = false
    of csHalfOpen:
      result = true

proc recordSuccess(cb: CircuitBreakerTransport) =
  withLock cb.lock:
    case cb.state
    of csClosed:
      cb.failureCount = 0
    of csHalfOpen:
      cb.successCount += 1
      if cb.successCount >= cb.cfg.successThreshold:
        cb.state = csClosed
        cb.failureCount = 0
        logInfo("circuit breaker: closed")
    of csOpen:
      discard

proc recordFailure(cb: CircuitBreakerTransport) =
  withLock cb.lock:
    cb.failureCount += 1
    cb.lastFailureTime = getTime()
    case cb.state
    of csClosed:
      if cb.failureCount >= cb.cfg.failureThreshold:
        cb.state = csOpen
        logError("circuit breaker: opened")
    of csHalfOpen:
      cb.state = csOpen
      logError("circuit breaker: opened (half-open failure)")
    of csOpen:
      discard

method execute*(cb: CircuitBreakerTransport, ctx: pointer, req: Request): Response =
  if not cb.canAttempt():
    raise newException(ValueError, "circuit breaker: open")

  try:
    result = cb.inner.execute(ctx, req)
    if result.statusCode >= 500:
      cb.recordFailure()
    else:
      cb.recordSuccess()
  except CatchableError:
    cb.recordFailure()
    raise

method endpoints*(cb: CircuitBreakerTransport): seq[string] = cb.inner.endpoints()

method protocol*(cb: CircuitBreakerTransport): Protocol = cb.inner.protocol()

method close*(cb: CircuitBreakerTransport) = cb.inner.close()
