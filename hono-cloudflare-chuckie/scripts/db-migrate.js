const fs = require('fs')
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

const migrationsDir = path.resolve(process.cwd(), 'drizzle')
const files = fs.readdirSync(migrationsDir).sort()

for (const file of files) {
  if (file.endsWith('.sql')) {
    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8')
    console.log(`Running migration: ${file}`)
    db.exec(sql)
  }
}

console.log('Migrations applied to', dbPath)