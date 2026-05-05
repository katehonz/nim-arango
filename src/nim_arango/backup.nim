## Backup and Restore API.

import std/[json]
import client, types

type
  BackupInfo* = object
    id*: string
    version*: string
    datetime*: string
    sizeInBytes*: int64
    numberOfFiles*: int
    numberOfDBServers*: int
    available*: bool
    potentiallyInconsistent*: bool

proc createBackup*(c: Client, label: string = "", allowInconsistent: bool = false, force: bool = false, timeout: int = 120): BackupInfo =
  var body = %*{
    "label": label,
    "allowInconsistent": allowInconsistent,
    "force": force,
    "timeout": timeout,
  }
  let j = c.doRequestJson("POST", "_admin/backup/create", $body)
  let resultNode = j["result"]
  result = BackupInfo(
    id: resultNode{"id"}.getStr(""),
    version: resultNode{"version"}.getStr(""),
    datetime: resultNode{"datetime"}.getStr(""),
    sizeInBytes: resultNode{"sizeInBytes"}.getInt(0).int64,
    numberOfFiles: resultNode{"numberOfFiles"}.getInt(0),
    numberOfDBServers: resultNode{"numberOfDBServers"}.getInt(0),
    available: resultNode{"available"}.getBool(true),
    potentiallyInconsistent: resultNode{"potentiallyInconsistent"}.getBool(false),
  )

proc restoreBackup*(c: Client, id: string, force: bool = false): JsonNode =
  let body = %*{
    "id": id,
    "force": force,
  }
  result = c.doRequestJson("POST", "_admin/backup/restore", $body)

proc deleteBackup*(c: Client, id: string, force: bool = false) =
  let body = %*{
    "id": id,
    "force": force,
  }
  discard c.doRequestJson("POST", "_admin/backup/delete", $body)

proc listBackups*(c: Client, id: string = ""): seq[BackupInfo] =
  ## List all backups, optionally filtered by backup ID.
  var body = newJObject()
  if id.len > 0:
    body["id"] = %id
  let j = c.doRequestJson("POST", "_admin/backup/list", $body)
  result = @[]
  if j.hasKey("result") and j["result"].hasKey("list"):
    for k, v in j["result"]["list"]:
      result.add(BackupInfo(
        id: v{"id"}.getStr(""),
        version: v{"version"}.getStr(""),
        datetime: v{"datetime"}.getStr(""),
        sizeInBytes: v{"sizeInBytes"}.getInt(0).int64,
        numberOfFiles: v{"numberOfFiles"}.getInt(0),
        numberOfDBServers: v{"numberOfDBServers"}.getInt(0),
        available: v{"available"}.getBool(true),
        potentiallyInconsistent: v{"potentiallyInconsistent"}.getBool(false),
      ))

# --- Backup Transfer API (Enterprise) ---

proc uploadBackup*(c: Client, id: string, remoteRepository: string,
                    config: JsonNode = newJObject()): JsonNode =
  ## Upload a backup to a remote repository.
  var body = %*{
    "id": id,
    "remoteRepository": remoteRepository,
    "config": config,
  }
  result = c.doRequestJson("POST", "_admin/backup/upload", $body)

proc downloadBackup*(c: Client, id: string, remoteRepository: string,
                      config: JsonNode = newJObject()): JsonNode =
  ## Download a backup from a remote repository.
  var body = %*{
    "id": id,
    "remoteRepository": remoteRepository,
    "config": config,
  }
  result = c.doRequestJson("POST", "_admin/backup/download", $body)

proc backupTransferProgress*(c: Client, jobId: string): JsonNode =
  ## Poll progress of a backup upload/download transfer job.
  result = c.doRequestJson("GET", "_admin/backup/transfer/" & jobId)

proc abortTransferJob*(c: Client, jobId: string) =
  ## Abort an in-progress backup transfer job.
  discard c.doRequestJson("DELETE", "_admin/backup/transfer/" & jobId)
