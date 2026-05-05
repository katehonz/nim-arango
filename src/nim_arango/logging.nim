## Structured logging for nim-arango.
##
## Uses std/logging for all internal log output.

import std/[logging, times, strformat]

type
  ArangoLogger* = ref object
    logger*: ConsoleLogger
    enabled*: bool = true

var defaultLogger*: ArangoLogger

proc initArangoLogger*() =
  defaultLogger = ArangoLogger(logger: newConsoleLogger(), enabled: true)

proc logRequest*(verb, path: string, statusCode: int, durationMs: int64, endpoint: string, retryCount: int = 0) =
  if defaultLogger == nil or not defaultLogger.enabled:
    return
  let msg = &"[{getTime().format(\"yyyy-MM-dd HH:mm:ss\")}] {verb} {path} => {statusCode} ({durationMs}ms) endpoint={endpoint} retries={retryCount}"
  if statusCode >= 500:
    defaultLogger.logger.log(lvlError, msg)
  elif statusCode >= 400:
    defaultLogger.logger.log(lvlWarn, msg)
  else:
    defaultLogger.logger.log(lvlDebug, msg)

proc logError*(msg: string) =
  if defaultLogger == nil or not defaultLogger.enabled:
    return
  defaultLogger.logger.log(lvlError, &"[{getTime().format(\"yyyy-MM-dd HH:mm:ss\")}] {msg}")

proc logInfo*(msg: string) =
  if defaultLogger == nil or not defaultLogger.enabled:
    return
  defaultLogger.logger.log(lvlInfo, &"[{getTime().format(\"yyyy-MM-dd HH:mm:ss\")}] {msg}")

proc logDebug*(msg: string) =
  if defaultLogger == nil or not defaultLogger.enabled:
    return
  defaultLogger.logger.log(lvlDebug, &"[{getTime().format(\"yyyy-MM-dd HH:mm:ss\")}] {msg}")

proc setLogLevel*(level: Level) =
  setLogFilter(level)

initArangoLogger()
