import { sqliteTable, integer, text, real } from 'drizzle-orm/sqlite-core'

export const raw_users_table = sqliteTable('raw_users_table', {
  id: integer('id').primaryKey(),
  name: text('name').notNull(),
  created_at: text('created_at').notNull()
})

export const products_table = sqliteTable('products_table', {
  id: integer('id').primaryKey(),
  name: text('name').notNull(),
  price: real('price').notNull(),
  category: text('category').notNull(),
  created_at: text('created_at').notNull()
})
