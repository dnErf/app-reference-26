import { describe, it, expect } from 'vitest'
import { getVariables } from '../src/lib/variables'

describe('getVariables', () => {
  it('returns process.env value if set as JSON', () => {
    process.env.VARIABLES = '{"start_date": "2021-01-01"}'
    const vars = getVariables()
    expect(vars).toEqual({ start_date: '2021-01-01' })
    delete process.env.VARIABLES
  })

  it('returns empty object if no variables', () => {
    const vars = getVariables()
    expect(vars).toEqual({})
  })
})