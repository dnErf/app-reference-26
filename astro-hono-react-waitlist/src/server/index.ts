import { Hono } from "hono"
import { authCf } from "./middleware/auth_cf"

const app = new Hono()

app
.use(authCf)
.get("/api/health", (c) => {
    return c.json({ ok: true })
})

export default app