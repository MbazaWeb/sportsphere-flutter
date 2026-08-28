// vps/api/src/lib/db.ts
// Direct PostgreSQL connection — replaces supabase-js for all data queries.
// Supabase JS is kept ONLY for auth.getUser() JWT verification.

import { Pool, type PoolClient } from 'pg'

const pool = new Pool({
  connectionString: Bun.env.DATABASE_URL,
  max:              20,   // max connections in pool
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 10_000,
  ssl: Bun.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
})

pool.on('error', (err) => {
  console.error('[DB] Unexpected pool error', err)
})

// ── Query helpers ─────────────────────────────────────────────────────────────

/** Run a single query and return all rows */
export async function query<T = Record<string, unknown>>(
  sql: string,
  params: unknown[] = []
): Promise<T[]> {
  const client = await pool.connect()
  try {
    const res = await client.query(sql, params)
    return res.rows as T[]
  } finally {
    client.release()
  }
}

/** Run a query and return exactly one row or null */
export async function queryOne<T = Record<string, unknown>>(
  sql: string,
  params: unknown[] = []
): Promise<T | null> {
  const rows = await query<T>(sql, params)
  return rows[0] ?? null
}

/** Run a query and return the row count */
export async function execute(sql: string, params: unknown[] = []): Promise<number> {
  const client = await pool.connect()
  try {
    const res = await client.query(sql, params)
    return res.rowCount ?? 0
  } finally {
    client.release()
  }
}

/** Run multiple queries in a transaction */
export async function transaction<T>(
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    const result = await fn(client)
    await client.query('COMMIT')
    return result
  } catch (err) {
    await client.query('ROLLBACK')
    throw err
  } finally {
    client.release()
  }
}

/** Health check */
export async function dbHealthCheck(): Promise<boolean> {
  try {
    await query('SELECT 1')
    return true
  } catch {
    return false
  }
}

export { pool }
