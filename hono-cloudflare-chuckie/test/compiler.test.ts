import { describe, it, expect } from 'vitest'
import { compileModel } from '../src/worker/compiler'

describe('compileModel', () => {
  it('compiles a model and inlines refs and vars', async () => {
    const sql = await compileModel('example')
    expect(sql).toMatch(/SELECT\s+id,\s+name,\s+created_at/i)
    expect(sql).toMatch(/FROM\s+\(/i)
    expect(sql).toMatch(/WHERE\s+created_at\s+>=\s+'2020-01-01'/)
  })

  it('resolves variables from provided object', async () => {
    const variables = { start_date: '2021-01-01' }
    const sql = await compileModel('example', new Set(), variables)
    expect(sql).toMatch(/WHERE\s+created_at\s+>=\s+'2021-01-01'/)
  })
})
