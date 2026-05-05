## Graph Example

import nim_arango
import std/[json, strformat]

type Person = object
  name: string

type Follows = object
  since: string

proc main() =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  let db = client.database("social")

  # Create graph
  let g = db.createGraph("social", @[
    EdgeDefinition(
      collection: "follows",
      fromCollections: @["people"],
      toCollections: @["people"]
    )
  ])

  let people = db.collection("people")
  let follows = db.collection("follows")

  # Insert people
  let alice = people.createDocument(Person(name: "Alice"))
  let bob = people.createDocument(Person(name: "Bob"))
  let charlie = people.createDocument(Person(name: "Charlie"))

  # Insert edges
  discard follows.createDocument(Follows(since: "2024-01-01"))

  # Traversal
  let cursor = g.traversal[Person]("people/" & alice.key,
    withDirection("outbound"),
    withMaxDepth(2)
  )

  echo "People Alice follows:"
  while cursor.next():
    let (person, meta) = cursor.read()
    echo "  ", person.name

  cursor.close()
  client.close()

when isMainModule:
  main()
