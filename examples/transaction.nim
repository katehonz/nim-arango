## Transaction Example for nim-arango
##
## Run this against a local ArangoDB instance:
##   docker run -d -p 8529:8529 -e ARANGO_ROOT_PASSWORD=password arangodb

import nim_arango

type
  Account = object
    name: string
    balance: float

proc main() =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  let db = client.createDatabase("transaction_demo")
  let accounts = db.createCollection("accounts")

  # Create initial accounts
  discard accounts.createDocument(Account(name: "Alice", balance: 1000.0))
  discard accounts.createDocument(Account(name: "Bob", balance: 500.0))

  echo "Initial balances:"
  echo "  Alice: 1000.0"
  echo "  Bob: 500.0"

  # Start a transaction to transfer money
  let tx = db.beginTransaction(
    readCollections = @["accounts"],
    writeCollections = @["accounts"]
  )

  echo "\nTransaction started: ", tx.id()

  # Perform operations within transaction
  # In a real app, you'd query and update within the transaction
  let alice = readDocument[Account](accounts, "1")
  let bob = readDocument[Account](accounts, "2")

  echo "Transfer: Alice -> Bob (100.0)"

  # Commit the transaction
  tx.commit()
  echo "Transaction committed"

  # Verify balances (simplified - real app would use AQL)
  let aliceAfter = readDocument[Account](accounts, "1")
  let bobAfter = readDocument[Account](accounts, "2")
  echo "\nFinal balances:"
  echo "  Alice: ", aliceAfter.data.balance
  echo "  Bob: ", bobAfter.data.balance

  # Cleanup
  db.dropCollection("accounts")
  client.dropDatabase("transaction_demo")
  client.close()

when isMainModule:
  main()
