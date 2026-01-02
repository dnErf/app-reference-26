import { describe, it, expect } from 'vitest'
import { getDefaultModel } from '../src/lib/default-model'

describe('getDefaultModel', () => {
  it('returns process.env value if set', () => {
    process.env.DEFAULT_MODEL = 'test-model'
    const val = getDefaultModel()
    expect(val).toBe('test-model')
    delete process.env.DEFAULT_MODEL
  })

  it('falls back to raptor-mini-preview', () => {
    const val = getDefaultModel()
    expect(val).toBe('raptor-mini-preview')
  })
})