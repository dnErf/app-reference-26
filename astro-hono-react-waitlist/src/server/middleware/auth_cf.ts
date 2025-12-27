import { createMiddleware } from "hono/factory"
import { createRemoteJWKSet, jwtVerify } from "jose"

export const  authCf = createMiddleware(async (c, next) => {
    if (c.env.ENVIRONMENT === "development") { return await next() }
    if (!c.env.CF_POLICY_AUD) { return c.json({ msg: "required an audience" }, 403) }

    const token = c.req.header("cf-access-jwt-assertion")
    if (!token) { return c.json({ msg: "missing cf access"}, 403) }

    const JWKS = createRemoteJWKSet(new URL(`${c.env.CF_ACCESS_DOMAIN}/cdn-cgi/access/certs`))

    try {
        await jwtVerify(token, JWKS, {
            issuer: c.env.CF_ACCESS_DOMAIN,
            audience: c.env.CF_POLICY_AUD
        })
        return await next()
    }
    catch (err) {
        let e = err as Error
        return c.json({ msg: `invalid token: ${e.message}` }, 403)
    }
})
