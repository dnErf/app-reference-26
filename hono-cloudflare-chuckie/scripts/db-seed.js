const path = require('path')

let Database
try {
  Database = require('better-sqlite3')
} catch (e) {
  console.error('better-sqlite3 is not installed.')
  process.exit(1)
}

const dbPath = path.resolve(process.cwd(), process.env.DRIZZLE_DEV_SQLITE || './dev.sqlite')
const db = new Database(dbPath)

db.exec(`INSERT OR IGNORE INTO raw_users_table (name, created_at) VALUES 
  ('Alice','2023-01-01'),
  ('Bob','2023-06-15'),
  ('Charlie','2023-03-20'),
  ('Diana','2023-09-10'),
  ('Eve','2023-12-05'),
  ('Frank','2024-02-14'),
  ('Grace','2024-05-22'),
  ('Henry','2024-08-30'),
  ('Ivy','2024-11-11'),
  ('Jack','2025-01-01');`)

db.exec(`INSERT OR IGNORE INTO products_table (name, price, category, created_at) VALUES 
  ('Laptop', 999.99, 'Electronics', '2023-01-15'),
  ('Book', 19.99, 'Books', '2023-02-01'),
  ('Phone', 699.99, 'Electronics', '2023-03-10'),
  ('Chair', 149.99, 'Furniture', '2023-04-05'),
  ('Shoes', 89.99, 'Clothing', '2023-05-20'),
  ('Headphones', 199.99, 'Electronics', '2023-06-15'),
  ('Tablet', 399.99, 'Electronics', '2023-07-01'),
  ('Watch', 299.99, 'Accessories', '2023-08-12'),
  ('Backpack', 49.99, 'Accessories', '2023-09-25'),
  ('Monitor', 249.99, 'Electronics', '2023-10-30');`)

console.log('Seeded', dbPath)