## AQL Query Example

import nim_arango
import std/[json, strformat]

type Product = object
  name: string
  price: float
  category: string

proc main() =
  let client = newClient(
    withEndpoint("http://localhost:8529"),
    withBasicAuth("root", "password")
  )

  let db = client.database("shop")
  let products = db.collection("products")

  # Insert sample data
  discard products.createDocument(Product(name: "Laptop", price: 999.99, category: "Electronics"))
  discard products.createDocument(Product(name: "Mouse", price: 29.99, category: "Electronics"))
  discard products.createDocument(Product(name: "Desk", price: 199.99, category: "Furniture"))

  # Query with parameters
  let cursor = db.query("""
    FOR p IN products
      FILTER p.category == @cat AND p.price > @minPrice
      SORT p.price DESC
      RETURN p
  """)
    .bindParam("cat", "Electronics")
    .bindParam("minPrice", 10.0)
    .batchSize(10)
    .exec[Product]()

  echo "Products found:"
  while cursor.next():
    let (product, meta) = cursor.read()
    echo &"  {product.name}: ${product.price}"

  cursor.close()
  client.close()

when isMainModule:
  main()
