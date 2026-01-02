const path = require('path')

let Database
try {
  Database = require('better-sqlite3')
} catch (e) {
  console.error('better-sqlite3 is not installed. Run `pnpm add --save-optional better-sqlite3` to enable local SQLite init.')
  process.exit(1)
}

const dbPath = path.resolve(process.cwd(), 'dev.sqlite')
const db = new Database(dbPath)

db.exec(`
CREATE TABLE IF NOT EXISTS raw_users_table (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);
`)

db.exec(`INSERT INTO raw_users_table (name, created_at) VALUES ('Alice','2023-01-01'),('Bob','2023-06-15');`)

console.log('Initialized', dbPath)
