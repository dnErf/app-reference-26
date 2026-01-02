import { initSqlite, initD1 } from './db'

export type DBHandle = { type: 'sqlite' | 'd1'; client: any }

export async function getDb(env?: any): Promise<DBHandle> {
  // Prefer Cloudflare D1 binding when available (production / wrangler)
  try {
    if (env && env.DB) {
      const client = initD1(env.DB)
      return { type: 'd1', client }
    }
  } catch (e) {
    // ignore and fall through to sqlite for local dev
  }

  // Local development: use sqlite file
  if (process.env.NODE_ENV !== 'production') {
    const client = initSqlite(process.env.DRIZZLE_DEV_SQLITE || './dev.sqlite')
    return { type: 'sqlite', client }
  }

  // Production without a D1 binding is an error
  throw new Error('No D1 binding available; in production set a `DB` binding')
}
