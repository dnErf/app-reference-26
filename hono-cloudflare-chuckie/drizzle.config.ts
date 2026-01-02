import { defineConfig } from 'drizzle-kit'

// For local dev, use d1-http with local D1 URL
// For production, use d1-http with remote URL
const d1Url = process.env.D1_HTTP_URL || 'http://127.0.0.1:8788/d1/db/mini-dbt-db'

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  driver: 'd1-http',
  dialect: 'sqlite',
  dbCredentials: { url: d1Url }
})
