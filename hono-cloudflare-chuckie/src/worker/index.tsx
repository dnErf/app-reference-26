import { Hono } from 'hono'
import type { FC } from 'hono/jsx'
import type { ScheduledEvent, ExecutionContext } from '@cloudflare/workers-types'
import { compileModel } from './compiler'
import { getDefaultModel } from '../lib/default-model'
import { getVariables } from '../lib/variables'
import { getDb } from '../db'

const app = new Hono()

const Layout: FC<{ title: string; children: any }> = ({ title, children }) => (
  <html>
    <head>
      <title>{title}</title>
      <style>{`
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #333; }
        pre { background: #f4f4f4; padding: 10px; border: 1px solid #ddd; }
        ul { list-style-type: none; }
        li { margin: 5px 0; }
        a { color: #007bff; text-decoration: none; }
        a:hover { text-decoration: underline; }
      `}</style>
    </head>
    <body>
      <h1>Mini-DBT Viewer</h1>
      <nav>
        <a href="/">Home</a> | <a href="/models">Models</a> | <a href="/schedule">Schedule</a>
      </nav>
      {children}
    </body>
  </html>
)

const HomePage: FC = () => (
  <Layout title="Mini-DBT Home">
    <p>Welcome to the Mini-DBT viewer. Use the links above to explore models and schedules.</p>
  </Layout>
)

const ModelsPage: FC<{ models: string[] }> = ({ models }) => (
  <Layout title="Models">
    <h2>Available Models</h2>
    <ul>
      {models.map(model => (
        <li>
          <a href={`/models/${model}/view`}>{model}</a> | <a href={`/models/${model}/compile`}>Compile</a> | <a href={`/models/${model}/execute`}>Execute</a>
        </li>
      ))}
    </ul>
  </Layout>
)

const ModelViewPage: FC<{ name: string; content: string }> = ({ name, content }) => (
  <Layout title={`View ${name}`}>
    <h2>Model: {name}</h2>
    <h3>NJK Source</h3>
    <pre>{content}</pre>
    <a href={`/models/${name}/compile`}>View Compiled SQL</a> | <a href={`/models/${name}/execute`}>Execute</a>
  </Layout>
)

const SchedulePage: FC = () => (
  <Layout title="Schedule">
    <h2>Cron Schedule</h2>
    <p>The default model is materialized daily at midnight UTC.</p>
    <p>Cron expression: <code>0 0 * * *</code></p>
  </Layout>
)

app.get('/', (c) => {
  return c.html(<HomePage />)
})

app.get('/schedule', (c) => {
  return c.html(<SchedulePage />)
})

app.get('/models', async (c) => {
  console.log('Listing available models')
  // For dev/prod compatibility, use static list since fs not available in Workers runtime
  const models = ['example', 'raw_users', 'products']
  console.log(`Found ${models.length} models: ${models.join(', ')}`)
  const accept = c.req.header('Accept')
  if (accept?.includes('text/html')) {
    return c.html(<ModelsPage models={models} />)
  }
  return c.json({ models })
})

app.get('/models/:name/compile', async (c) => {
  const name = c.req.param('name')
  console.log(`Compiling model '${name}'`)
  try {
    const variables = getVariables((c as any).env)
    const compiledSql = await compileModel(name, new Set(), variables)
    console.log('Compiled SQL:', compiledSql)
    const accept = c.req.header('Accept')
    if (accept?.includes('text/html')) {
      return c.html(
        <Layout title={`Compile ${name}`}>
          <h2>Compiled SQL for {name}</h2>
          <h3>Compiled SQL</h3>
          <pre>{compiledSql}</pre>
          <a href={`/models/${name}/view`}>View NJK Source</a> | <a href={`/models/${name}/execute`}>Execute</a>
        </Layout>
      )
    }
    return c.json({ compiledSql })
  } catch (e: any) {
    return c.html(
      <Layout title={`Compile ${name}`}>
        <h2>Error compiling {name}</h2>
        <p>{e.message || String(e)}</p>
        <a href={`/models/${name}/view`}>View NJK Source</a>
      </Layout>, 500
    )
  }
})

app.get('/models/:name/execute', async (c) => {
  const name = c.req.param('name')
  console.log(`Executing model '${name}'`)
  try {
    const dbHandle = await getDb((c as any).env)
    const variables = getVariables((c as any).env)
    const compiledSql = await compileModel(name, new Set(), variables)
    console.log('Compiled SQL:', compiledSql)
    // Execute the SQL
    const isSelect = compiledSql.trim().toUpperCase().startsWith('SELECT')
    let result
    if (isSelect) {
      const queryResult = await dbHandle.client.prepare(compiledSql).all()
      result = queryResult.results || []
    } else {
      result = await dbHandle.client.prepare(compiledSql).run()
    }
    // Format result
    let resultDisplay
    if (Array.isArray(result) && result.length > 0) {
      // Display as table
      const headers = Object.keys(result[0])
      resultDisplay = (
        <table style={{ borderCollapse: 'collapse', width: '100%' }}>
          <thead>
            <tr>
              {headers.map(h => <th style={{ border: '1px solid #ddd', padding: '8px' }}>{h}</th>)}
            </tr>
          </thead>
          <tbody>
            {result.map((row: any) => (
              <tr>
                {headers.map(h => <td style={{ border: '1px solid #ddd', padding: '8px' }}>{String(row[h])}</td>)}
              </tr>
            ))}
          </tbody>
        </table>
      )
    } else {
      resultDisplay = <pre>{JSON.stringify(result, null, 2)}</pre>
    }
    return c.html(
      <Layout title={`Execute ${name}`}>
        <h2>Executed SQL for {name}</h2>
        <h3>Compiled SQL</h3>
        <pre>{compiledSql}</pre>
        <h3>Result</h3>
        {resultDisplay}
        <a href={`/models/${name}/view`}>View NJK Source</a> | <a href={`/models/${name}/compile`}>View Compiled SQL</a>
      </Layout>
    )
  } catch (e: any) {
    return c.html(
      <Layout title={`Execute ${name}`}>
        <h2>Error executing {name}</h2>
        <p>{e.message || String(e)}</p>
        <a href={`/models/${name}/view`}>View NJK Source</a>
      </Layout>, 500
    )
  }
})

// Placeholder in-memory job queue (MVP)
const jobs: Record<string, any> = {}
let jobCounter = 1

app.get('/models/:name/view', async (c) => {
  const name = c.req.param('name')
  // Use precompiled templates
  const { templates } = await import('./templates')
  const content = templates[name] || null
  if (!content) {
    return c.html(<Layout title="Error"><p>Model '{name}' not found.</p></Layout>, 404)
  }
  return c.html(<ModelViewPage name={name} content={content} />)
})

app.post('/jobs/materialize', async (c) => {
  const body = await c.req.json().catch(() => ({}))
  const model = body.model
  if (!model) return c.json({ error: 'model is required' }, 400)
  try {
    const dbHandle = await getDb((c as any).env)
    console.log('Materialize using backend:', dbHandle.type)
    const variables = getVariables((c as any).env)
    const compiledSql = await compileModel(model, new Set(), variables)
    console.log('Compiled SQL:', compiledSql)
    // Execute the SQL
    const isSelect = compiledSql.trim().toUpperCase().startsWith('SELECT')
    let result
    if (isSelect) {
      const queryResult = await dbHandle.client.prepare(compiledSql).all()
      result = queryResult.results || []
    } else {
      result = await dbHandle.client.prepare(compiledSql).run()
    }
    return c.json({ status: 'ok', backend: dbHandle.type, result })
  } catch (e: any) {
    return c.json({ error: e.message || String(e) }, 503)
  }
})

export default {
  fetch: app.fetch,
  scheduled: async (event: ScheduledEvent, env: any, ctx: ExecutionContext) => {
    console.log('Scheduled cron trigger: materializing default model')
    try {
      const dbHandle = await getDb(env)
      console.log('Scheduled materialize using backend:', dbHandle.type)
      const defaultModel = getDefaultModel(env)
      const variables = getVariables(env)
      const compiledSql = await compileModel(defaultModel, new Set(), variables)
      console.log('Compiled SQL for default model:', compiledSql)
      // Execute the SQL
      const isSelect = compiledSql.trim().toUpperCase().startsWith('SELECT')
      let result
      if (isSelect) {
        const queryResult = await dbHandle.client.prepare(compiledSql).all()
        result = queryResult.results || []
      } else {
        result = await dbHandle.client.prepare(compiledSql).run()
      }
      console.log('Materialization result:', result)
    } catch (e: any) {
      console.error('Scheduled materialization failed:', e.message || e)
    }
  }
}
