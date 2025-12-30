import eslintPluginAstro from "eslint-plugin-astro"
import stylistic from "@stylistic/eslint-plugin"

export default [
    ...eslintPluginAstro.configs.recommended,
    {
        files: ["*.astro", "*.ts", "*.tsx"],
        plugins: {
            "@stylistic": stylistic
        },
        processor: "astro/client-side-ts",
        rules: {
            "@stylistic/quotes": ["error", "single", { "avoidEscape": true }]
        }
    }
]
