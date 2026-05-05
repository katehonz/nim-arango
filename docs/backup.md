# Backup & Restore

Create, list, restore, delete, and transfer ArangoDB backups.

## Create a Backup

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)

let backup = client.createBackup(
  label = "pre-upgrade",
  allowInconsistent = false,
  force = false,
  timeout = 120,          # seconds
)

echo backup.id               # "2024-01-01T00:00:00Z_abc123"
echo backup.version          # "3.11.x"
echo backup.datetime         # ISO timestamp
echo backup.sizeInBytes      # 1048576
echo backup.numberOfFiles    # 42
echo backup.available        # true
```

## List Backups

```nim
# List all backups
let backups = client.listBackups()
for b in backups:
  echo b.id, " ", b.datetime, " ", b.sizeInBytes, " bytes"

# Filter by ID
let backups = client.listBackups(id = "2024-01-01T00:00:00Z_abc123")
```

## Restore a Backup

```nim
let result = client.restoreBackup(
  id = "2024-01-01T00:00:00Z_abc123",
  force = true,
)
```

## Delete a Backup

```nim
client.deleteBackup("2024-01-01T00:00:00Z_abc123")
client.deleteBackup("2024-01-01T00:00:00Z_abc123", force = true)
```

## Backup Transfer (Enterprise)

Upload and download backups to/from remote repositories:

```nim
import std/json

let remoteConfig = %*{
  "endpoint": "s3://my-bucket/backups",
  "accessKey": "...",
  "secretKey": "...",
}

# Upload
let uploadResult = client.uploadBackup(
  id = "2024-01-01T00:00:00Z_abc123",
  remoteRepository = "s3-remote",
  config = remoteConfig,
)
echo uploadResult["uploadId"]

# Download
let downloadResult = client.downloadBackup(
  id = "2024-01-01T00:00:00Z_abc123",
  remoteRepository = "s3-remote",
  config = remoteConfig,
)

# Poll transfer progress
let progress = client.backupTransferProgress("upload-123")
echo progress["completed"], "/", progress["total"]

# Abort transfer
client.abortTransferJob("upload-123")
```

## BackupInfo Type

```nim
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
```

## Public API

```nim
# Backup CRUD
proc createBackup*(c: Client, label: string = "", allowInconsistent: bool = false,
                   force: bool = false, timeout: int = 120): BackupInfo
proc restoreBackup*(c: Client, id: string, force: bool = false): JsonNode
proc deleteBackup*(c: Client, id: string, force: bool = false)
proc listBackups*(c: Client, id: string = ""): seq[BackupInfo]

# Transfer (Enterprise)
proc uploadBackup*(c: Client, id: string, remoteRepository: string,
                    config: JsonNode = newJObject()): JsonNode
proc downloadBackup*(c: Client, id: string, remoteRepository: string,
                      config: JsonNode = newJObject()): JsonNode
proc backupTransferProgress*(c: Client, jobId: string): JsonNode
proc abortTransferJob*(c: Client, jobId: string)
```
