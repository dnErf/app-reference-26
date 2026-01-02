const fs = require('fs')
const path = require('path')
const nunjucks = require('nunjucks')

const MODELS_DIR = path.resolve(process.cwd(), 'models')
const OUT_FILE = path.resolve(process.cwd(), 'src/worker/templates.js')

nunjucks.configure({ autoescape: false })

async function build() {
  const files = await fs.promises.readdir(MODELS_DIR)
  const templates = {}
  for (const f of files) {
    if (!f.endsWith('.sql.njk')) continue
    const name = f.replace(/\.sql\.njk$/, '')
    const content = await fs.promises.readFile(path.join(MODELS_DIR, f), 'utf8')
    templates[name] = content
  }

  const out = `// Auto-generated template store
export const templates = ${JSON.stringify(templates, null, 2)}
`

  await fs.promises.mkdir(path.dirname(OUT_FILE), { recursive: true })
  await fs.promises.writeFile(OUT_FILE.replace('.js', '.ts'), out, 'utf8')
  console.log('Wrote', OUT_FILE.replace('.js', '.ts'))
}

build().catch((err) => {
  console.error(err)
  process.exit(1)
})
