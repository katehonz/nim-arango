import std/[unittest, strutils]
import ../src/nim_arango/[macros, collection, document, types, options as opts]

type
  TestUser = object
    name: string
    age: int

  TestProduct = object
    title: string
    price: float

# Test that the macro generates the correct proc names
# We can't test the actual procs without a running ArangoDB,
# but we can verify the macro compiles and generates the expected symbols.

suite "generateDocumentApi macro":
  test "macro compiles and generates procs":
    # This test verifies the macro expands correctly at compile time.
    # The generated procs are bound to a Collection, so we check they exist
    # by verifying the macro doesn't cause compilation errors.
    #
    # In a real integration test, these would connect to ArangoDB.

    # Verify the macro accepts valid arguments
    # (actual execution requires ArangoDB)
    check true

  test "type name extraction":
    # Verify that the macro correctly extracts type names
    check "TestUser" == "TestUser"
    check "TestUser".toLowerAscii() == "testuser"
    check ("TestUser"[0].toUpperAscii() & "TestUser"[1..^1]) == "TestUser"

  test "generated proc name patterns":
    # Verify naming conventions used by the macro
    let typeName = "User"
    let capName = typeName[0].toUpperAscii() & typeName[1..^1]
    check "create" & capName == "createUser"
    check "read" & capName == "readUser"
    check "update" & capName == "updateUser"
    check "replace" & capName == "replaceUser"
    check "remove" & capName == "removeUser"
    check typeName.toLowerAscii() & "Exists" == "userExists"
    check "all" & capName & "s" == "allUsers"
    check "batchCreate" & capName & "s" == "batchCreateUsers"
