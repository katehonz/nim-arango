## Compile-time document API generation macro.
##
## Generates type-safe CRUD procs for a collection type,
## eliminating boilerplate and providing a more ergonomic API.
##
## Usage:
## ```nim
## import nim_arango
##
## type User = object
##   name: string
##   age: int
##
## # Generate type-safe API for the User type
## documentApi(User)
## # This generates: createUser, readUser, updateUser, replaceUser,
## #   removeUser, userExists, allUsers, batchCreateUsers
##
## # Use with any Collection:
## let meta = users.createUser(User(name: "Alice", age: 30))
## let doc = users.readUser(meta.key)
## ```

import std/[macros, strutils, json]
import collection, document, types, options as opts

macro documentApi*(T: typedesc): untyped =
  ## Generate type-safe CRUD procs for a given type.
  ##
  ## Given `documentApi(User)`, generates procs that take `col: Collection`
  ## as first parameter. Use with method-call syntax:
  ##   `users.createUser(doc)` instead of `createDocument[User](users, doc)`

  let typeName = T.repr

  # Strip "type " prefix if present (Nim sometimes includes it)
  let cleanName = if typeName.startsWith("type "): typeName[5..^1] else: typeName
  let typeLower = cleanName.toLowerAscii()
  let capName = cleanName[0].toUpperAscii() & cleanName[1..^1]

  let colIdent = ident("col")
  let createName = ident("create" & capName)
  let readName = ident("read" & capName)
  let updateName = ident("update" & capName)
  let replaceName = ident("replace" & capName)
  let removeName = ident("remove" & capName)
  let existsName = ident(typeLower & "Exists")
  let allName = ident("all" & capName & "s")
  let batchName = ident("batchCreate" & capName & "s")
  let typeNameSym = ident(cleanName)

  result = quote do:
    proc `createName`(`colIdent`: Collection, doc: `typeNameSym`, optsArgs: varargs[WriteOpt]): DocumentMeta =
      createDocument[`typeNameSym`](`colIdent`, doc, optsArgs)

    proc `readName`(`colIdent`: Collection, key: string, optsArgs: varargs[WriteOpt]): Document[`typeNameSym`] =
      readDocument[`typeNameSym`](`colIdent`, key, optsArgs)

    proc `updateName`(`colIdent`: Collection, key: string, patch: `typeNameSym`, optsArgs: varargs[WriteOpt]): DocumentMeta =
      updateDocument[`typeNameSym`](`colIdent`, key, patch, optsArgs)

    proc `replaceName`(`colIdent`: Collection, key: string, doc: `typeNameSym`, optsArgs: varargs[WriteOpt]): DocumentMeta =
      replaceDocument[`typeNameSym`](`colIdent`, key, doc, optsArgs)

    proc `removeName`(`colIdent`: Collection, key: string, optsArgs: varargs[WriteOpt]): DocumentMeta =
      removeDocument(`colIdent`, key, optsArgs)

    proc `existsName`(`colIdent`: Collection, key: string): bool =
      documentExists(`colIdent`, key)

    proc `allName`(`colIdent`: Collection, optsArgs: varargs[WriteOpt]): seq[Document[`typeNameSym`]] =
      let cfg = buildWriteConfig(optsArgs)
      let qs = buildWriteQueryString(cfg)
      let j = `colIdent`.db.client.doRequestJson("GET", "_api/document/" & `colIdent`.name & qs)
      result = @[]
      for node in j.getElems():
        var dataNode = node
        dataNode.delete("_key")
        dataNode.delete("_id")
        dataNode.delete("_rev")
        dataNode.delete("_oldRev")
        result.add(Document[`typeNameSym`](
          meta: parseDocumentMeta(node),
          data: fromJson[`typeNameSym`](dataNode),
        ))

    proc `batchName`(`colIdent`: Collection, docs: seq[`typeNameSym`], optsArgs: varargs[WriteOpt]): seq[DocumentMeta] =
      createDocuments[`typeNameSym`](`colIdent`, docs, optsArgs)
