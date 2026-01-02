// Auto-generated template store
export const templates = {
  "example": "-- models/example.sql.njk\n-- name: example\n\nSELECT\n  id,\n  name,\n  created_at\nFROM (\n  {{ ref('raw_users') }}\n) as users\nWHERE created_at >= '{{ var('start_date', '2020-01-01') }}';\n",
  "products": "-- models/products.sql.njk\n-- name: products\n\nSELECT id, name, price, category, created_at FROM products_table WHERE price >= {{ var('min_price', 0) }};",
  "raw_users": "-- models/raw_users.sql.njk\n-- name: raw_users\n\nSELECT id, name, created_at FROM raw_users_table\n"
}
