import type { Context } from 'hono'

export function getVariables(env?: any, c?: Context<any>): Record<string, string> {
  // Priority: env binding -> Cloudflare binding via c.env -> process.env (JSON) -> empty object
  try {
    const binding = env?.VARIABLES || (c as any)?.env?.VARIABLES
    if (binding && typeof binding === 'object') return binding as Record<string, string>
  } catch (e) {
    // ignore
  }
  if (process.env.VARIABLES) {
    try {
      return JSON.parse(process.env.VARIABLES)
    } catch (e) {
      // ignore
    }
  }
  return {}
}