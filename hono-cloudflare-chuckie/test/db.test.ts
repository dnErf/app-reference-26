import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

// Mock the low-level DB initializers so tests don't require native sqlite
vi.mock('../src/db/db', () => {
  return {
    initSqlite: vi.fn((p) => ({ client: 'sqlite-client', path: p })),
    initD1: vi.fn((db) => ({ client: 'd1-client', db }))
  }
})

import { getDb } from '../src/db'
import * as dbHelpers from '../src/db/db'

describe('getDb', () => {
  const OLD_NODE_ENV = process.env.NODE_ENV

  beforeEach(() => {
    delete process.env.DRIZZLE_DEV_SQLITE
  })

  afterEach(() => {
    process.env.NODE_ENV = OLD_NODE_ENV
    vi.resetAllMocks()
  })

  it('selects D1 when env.DB is present', async () => {
    const env = { DB: { some: 'binding' } }
    const res = await getDb(env as any)
    expect(res.type).toBe('d1')
    expect(dbHelpers.initD1).toHaveBeenCalledWith(env.DB)
  })

  it('falls back to sqlite in non-production when no env.DB', async () => {
    process.env.NODE_ENV = 'development'
    const res = await getDb(undefined)
    expect(res.type).toBe('sqlite')
    expect(dbHelpers.initSqlite).toHaveBeenCalled()
  })
})
