## ArangoDB error types and codes.
##
## Maps ArangoDB HTTP error responses to Nim exceptions.

import std/[json, strformat]

type
  ArangoErrorCode* = distinct int

  ArangoError* = ref object of CatchableError
    code*: int           ## HTTP status code
    errorNum*: int       ## ArangoDB server error number
    errorMessage*: string

const
  # Common ArangoDB error codes
  ERROR_NO_ERROR* = ArangoErrorCode(0)
  ERROR_FAILED* = ArangoErrorCode(1)
  ERROR_SYS_ERROR* = ArangoErrorCode(2)
  ERROR_OUT_OF_MEMORY* = ArangoErrorCode(3)
  ERROR_INTERNAL* = ArangoErrorCode(4)
  ERROR_ILLEGAL_NUMBER* = ArangoErrorCode(5)
  ERROR_NUMERIC_OVERFLOW* = ArangoErrorCode(6)
  ERROR_ILLEGAL_OPTION* = ArangoErrorCode(7)
  ERROR_DEAD_PID* = ArangoErrorCode(8)
  ERROR_NOT_IMPLEMENTED* = ArangoErrorCode(9)
  ERROR_BAD_PARAMETER* = ArangoErrorCode(10)
  ERROR_HTTP_BAD_PARAMETER* = ArangoErrorCode(11)
  ERROR_FORBIDDEN* = ArangoErrorCode(12)
  ERROR_HTTP_CORRUPTED_JSON* = ArangoErrorCode(600)
  ERROR_HTTP_SUPERFLUOUS_SUFFICES* = ArangoErrorCode(601)

  # Internal ArangoDB errors
  ERROR_ARANGO_ILLEGAL_STATE* = ArangoErrorCode(1000)
  ERROR_ARANGO_READ_ONLY* = ArangoErrorCode(1004)
  ERROR_ARANGO_DUPLICATE_IDENTIFIER* = ArangoErrorCode(1005)
  ERROR_ARANGO_DATAFILE_SEALED* = ArangoErrorCode(1006)
  ERROR_ARANGO_UNKNOWN_COLLECTION_TYPE* = ArangoErrorCode(1007)
  ERROR_ARANGO_READ_ONLY_REPLICATION* = ArangoErrorCode(1009)
  ERROR_ARANGO_EMPTY_DATADIR* = ArangoErrorCode(1011)

  # External ArangoDB errors
  ERROR_REPLICATION_NO_RESPONSE* = ArangoErrorCode(1411)
  ERROR_REPLICATION_INVALID_RESPONSE* = ArangoErrorCode(1412)
  ERROR_REPLICATION_MASTER_ERROR* = ArangoErrorCode(1413)
  ERROR_REPLICATION_MASTER_INCOMPATIBLE* = ArangoErrorCode(1414)
  ERROR_REPLICATION_MASTER_CHANGE* = ArangoErrorCode(1415)
  ERROR_REPLICATION_LOOP* = ArangoErrorCode(1416)
  ERROR_REPLICATION_UNEXPECTED_MARKER* = ArangoErrorCode(1417)
  ERROR_REPLICATION_INVALID_APPLIER_STATE* = ArangoErrorCode(1418)
  ERROR_REPLICATION_UNEXPECTED_TRANSACTION* = ArangoErrorCode(1419)
  ERROR_REPLICATION_SHARD_SYNC_ATTEMPT_TIMEOUT* = ArangoErrorCode(1420)
  ERROR_REPLICATION_LOW_LEVEL_CATCHUP_STARTED* = ArangoErrorCode(1421)

  # General ArangoDB errors
  ERROR_ARANGO_CONFLICT* = ArangoErrorCode(1200)
  ERROR_ARANGO_DATADIR_LOCKED* = ArangoErrorCode(1201)
  ERROR_ARANGO_DOCUMENT_NOT_FOUND* = ArangoErrorCode(1202)
  ERROR_ARANGO_DATABASE_NOT_FOUND* = ArangoErrorCode(1228)
  ERROR_ARANGO_DATABASE_NAME_INVALID* = ArangoErrorCode(1229)
  ERROR_ARANGO_USE_SYSTEM_DATABASE* = ArangoErrorCode(1230)
  ERROR_ARANGO_INVALID_KEY_GENERATOR* = ArangoErrorCode(1231)
  ERROR_ARANGO_INVALID_EDGE_ATTRIBUTE* = ArangoErrorCode(1232)
  ERROR_ARANGO_INDEX_DOCUMENT_ATTRIBUTE_MISSING* = ArangoErrorCode(1233)
  ERROR_ARANGO_INDEX_CREATION_FAILED* = ArangoErrorCode(1234)
  ERROR_ARANGO_WRITE_THROTTLE_TIMEOUT* = ArangoErrorCode(1235)
  ERROR_ARANGO_COLLECTION_TYPE_INVALID* = ArangoErrorCode(1236)
  ERROR_ARANGO_ATTRIBUTE_PARSER_FAILED* = ArangoErrorCode(1237)
  ERROR_ARANGO_DOCUMENT_KEY_BAD* = ArangoErrorCode(1238)
  ERROR_ARANGO_DOCUMENT_KEY_UNEXPECTED* = ArangoErrorCode(1239)
  ERROR_ARANGO_DATA_SOURCE_NOT_FOUND* = ArangoErrorCode(1203)
  ERROR_ARANGO_DATA_SOURCE_ALREADY_EXISTS* = ArangoErrorCode(1207)
  ERROR_ARANGO_CORRUPTED_DATAFILE* = ArangoErrorCode(1100)
  ERROR_ARANGO_ILLEGAL_PARAMETER_FILE* = ArangoErrorCode(1101)
  ERROR_ARANGO_CORRUPTED_COLLECTION* = ArangoErrorCode(1102)
  ERROR_ARANGO_MMAP_FAILED* = ArangoErrorCode(1103)
  ERROR_ARANGO_FILESYSTEM_FULL* = ArangoErrorCode(1104)
  ERROR_ARANGO_NO_JOURNAL* = ArangoErrorCode(1105)
  ERROR_ARANGO_DATAFILE_ALREADY_EXISTS* = ArangoErrorCode(1106)
  ERROR_ARANGO_DATADIR_NOT_WRITABLE* = ArangoErrorCode(1107)
  ERROR_ARANGO_OUT_OF_KEYS* = ArangoErrorCode(1108)
  ERROR_ARANGO_DOCUMENT_TOO_LARGE* = ArangoErrorCode(1109)
  ERROR_ARANGO_SERVER_NOT_OPERATIONAL* = ArangoErrorCode(1110)

proc `==`*(a, b: ArangoErrorCode): bool {.borrow.}
proc `$`*(c: ArangoErrorCode): string {.borrow.}

proc newArangoError*(httpCode, errorNum: int, message: string): ArangoError =
  ArangoError(
    msg: &"ArangoDB error {errorNum}: {message} (HTTP {httpCode})",
    code: httpCode,
    errorNum: errorNum,
    errorMessage: message,
  )

proc raiseOnError*(respBody: string, statusCode: int) =
  ## Parse JSON response and raise ArangoError if the response contains an error.
  try:
    let j = parseJson(respBody)
    if j.hasKey("error") and j["error"].getBool():
      let errNum = if j.hasKey("errorNum"): j["errorNum"].getInt() else: 0
      let errMsg = if j.hasKey("errorMessage"): j["errorMessage"].getStr() else: "unknown error"
      raise newArangoError(statusCode, errNum, errMsg)
  except JsonParsingError:
    # Not JSON or malformed — ignore, let caller handle raw body
    discard

proc isNotFound*(e: ArangoError): bool =
  e.errorNum == ERROR_ARANGO_DOCUMENT_NOT_FOUND.int or e.errorNum == ERROR_ARANGO_DATA_SOURCE_NOT_FOUND.int

proc isConflict*(e: ArangoError): bool =
  e.errorNum == ERROR_ARANGO_CONFLICT.int
