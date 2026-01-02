export function initSqlite(path = './dev.sqlite') {
  let Database
  try {
    // lazy-require optional native dependency
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    Database = require('better-sqlite3')
  } catch (e) {
    throw new Error('better-sqlite3 is not installed. Install optional dependency `better-sqlite3` to use local SQLite.')
  }

  const db = new Database(path)
  return db
}

// Initialize a Drizzle client for D1 (Cloudflare). `d1Database` should be the
// D1 binding available in Worker `env.DB`.
export function initD1(d1Database: any) {
  // Return the raw D1 database for raw SQL execution
  return d1Database
}
