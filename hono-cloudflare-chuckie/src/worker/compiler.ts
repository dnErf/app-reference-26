import { templates } from './templates'

function parseDefaultValue(defaultStr: string): any {
  const trimmed = defaultStr.trim()
  if (trimmed === 'true') return true
  if (trimmed === 'false') return false
  if (trimmed === 'null') return null
  if (trimmed === 'undefined') return undefined
  if (/^['"`].*['"`]$/.test(trimmed)) return trimmed.slice(1, -1) // string
  if (/^\d+(\.\d+)?$/.test(trimmed)) return parseFloat(trimmed) // number
  throw new Error(`Unsupported default value: ${trimmed}`)
}

export async function compileModel(name: string, seen = new Set<string>(), variables: Record<string, any> = {}): Promise<string> {
  if (seen.has(name)) throw new Error(`Cycle detected when resolving model '${name}'`)
  seen.add(name)

  const content = templates[name]
  if (!content) throw new Error(`Model '${name}' not found`)

  // Find all refs like {{ ref('name') }} and recursively inline them
  const refPattern = /\{\{\s*ref\(['"]([a-zA-Z0-9_-]+)['"]\)\s*\}\}/g
  const refs = new Set<string>()
  let m
  while ((m = refPattern.exec(content)) !== null) {
    refs.add(m[1])
  }

  let resolved = content
  for (const refName of refs) {
    if (seen.has(refName)) throw new Error(`Cycle detected when resolving model '${refName}'`)
    const compiledRef = await compileModel(refName, seen, variables)
    const escaped = refName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
    const r = new RegExp(`\\{\\{\\s*ref\\(['\"]${escaped}['\"]\\)\\s*\\}\\}`, 'g')
    resolved = resolved.replace(r, `(${compiledRef})`)
  }

  // Replace variables: {{ var('key', default) }}
  resolved = resolved.replace(/\{\{\s*var\('([^']+)',\s*([^}]+)\)\s*\}\}/g, (match, key, defaultVal) => {
    const val = variables[key] !== undefined ? variables[key] : parseDefaultValue(defaultVal.trim())
    return typeof val === 'string' ? `'${val}'` : val.toString()
  })

  return resolved
}
