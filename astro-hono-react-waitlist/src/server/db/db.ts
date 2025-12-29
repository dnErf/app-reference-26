import { drizzle } from "drizzle-orm/d1"
import * as schema from "./schema"
import type { D1Database } from "@cloudflare/workers-types"

export const getDb = (binding: D1Database) => drizzle(binding, { schema })

export type DrizzleDb = ReturnType<typeof getDb>
