import std/[unittest, strutils]
import ../src/nim_arango/errors

suite "ArangoError Codes":
  test "error codes are distinct":
    check ERROR_NO_ERROR != ERROR_FAILED
    check ERROR_BAD_PARAMETER != ERROR_FORBIDDEN

  test "error codes equality":
    check ERROR_NO_ERROR == ERROR_NO_ERROR
    check ERROR_ARANGO_CONFLICT == ERROR_ARANGO_CONFLICT

  test "error code to string":
    check $ERROR_NO_ERROR == "0"
    check $ERROR_ARANGO_CONFLICT == "1200"

suite "ArangoError Creation":
  test "newArangoError":
    let err = newArangoError(404, 1202, "document not found")
    check err.code == 404
    check err.errorNum == 1202
    check err.errorMessage == "document not found"
    check err.msg.find("1202") >= 0
    check err.msg.find("document not found") >= 0

  test "ArangoError is CatchableError":
    let err = newArangoError(500, 1000, "internal error")
    var caught = false
    try:
      raise err
    except ArangoError:
      caught = true
    except:
      discard
    check caught

suite "raiseOnError":
  test "raises on error JSON":
    let json = """{"error":true,"errorNum":1202,"errorMessage":"not found"}"""
    expect ArangoError:
      raiseOnError(json, 404)

  test "does not raise on success JSON":
    let json = """{"result":[]}"""
    raiseOnError(json, 200)
    check true

  test "does not raise on empty body":
    raiseOnError("", 200)
    check true

  test "does not raise on malformed JSON":
    raiseOnError("not json", 200)
    check true

suite "Error Helpers":
  test "isNotFound":
    let err1 = newArangoError(404, 1202, "document not found")
    let err2 = newArangoError(404, 1203, "data source not found")
    let err3 = newArangoError(409, 1200, "conflict")
    check err1.isNotFound == true
    check err2.isNotFound == true
    check err3.isNotFound == false

  test "isConflict":
    let err1 = newArangoError(409, 1200, "conflict")
    let err2 = newArangoError(404, 1202, "not found")
    check err1.isConflict == true
    check err2.isConflict == false
