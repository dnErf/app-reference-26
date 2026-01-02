import type { Context } from 'hono'

export function getDefaultModel(env?: any, c?: Context<any>): string {
  // Priority: env binding -> Cloudflare binding via c.env -> process.env -> fallback
  try {
    const binding = env?.DEFAULT_MODEL || (c as any)?.env?.DEFAULT_MODEL
    if (binding) return binding
  } catch (e) {
    // ignore
  }
  if (process.env.DEFAULT_MODEL) return process.env.DEFAULT_MODEL
  return 'raptor-mini-preview'
}
