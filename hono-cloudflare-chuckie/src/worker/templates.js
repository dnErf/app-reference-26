// Auto-generated precompiled templates
const nunjucks = require('nunjucks')
nunjucks.configure({ autoescape: false })

const env = new nunjucks.Environment()

(function() {(window.nunjucksPrecompiled = window.nunjucksPrecompiled || {})["example"] = (function() {
function root(env, context, frame, runtime, cb) {
var lineno = 0;
var colno = 0;
var output = "";
try {
var parentTemplate = null;
output += "-- models/example.sql.njk\n-- name: example\n\nSELECT\n  id,\n  name,\n  created_at\nFROM (\n  ";
output += runtime.suppressValue((lineno = 8, colno = 8, runtime.callWrap(runtime.contextOrFrameLookup(context, frame, "ref"), "ref", context, ["raw_users"])), env.opts.autoescape);
output += "\n) as users\nWHERE created_at >= '";
output += runtime.suppressValue((lineno = 10, colno = 27, runtime.callWrap(runtime.contextOrFrameLookup(context, frame, "var"), "var", context, ["start_date","2020-01-01"])), env.opts.autoescape);
output += "';\n";
if(parentTemplate) {
parentTemplate.rootRenderFunc(env, context, frame, runtime, cb);
} else {
cb(null, output);
}
;
} catch (e) {
  cb(runtime.handleError(e, lineno, colno));
}
}
return {
root: root
};

})();
})();


(function() {(window.nunjucksPrecompiled = window.nunjucksPrecompiled || {})["products"] = (function() {
function root(env, context, frame, runtime, cb) {
var lineno = 0;
var colno = 0;
var output = "";
try {
var parentTemplate = null;
output += "-- models/products.sql.njk\n-- name: products\n\nSELECT id, name, price, category, created_at FROM products_table WHERE price >= ";
output += runtime.suppressValue((lineno = 3, colno = 86, runtime.callWrap(runtime.contextOrFrameLookup(context, frame, "var"), "var", context, ["min_price",0])), env.opts.autoescape);
output += ";";
if(parentTemplate) {
parentTemplate.rootRenderFunc(env, context, frame, runtime, cb);
} else {
cb(null, output);
}
;
} catch (e) {
  cb(runtime.handleError(e, lineno, colno));
}
}
return {
root: root
};

})();
})();


(function() {(window.nunjucksPrecompiled = window.nunjucksPrecompiled || {})["raw_users"] = (function() {
function root(env, context, frame, runtime, cb) {
var lineno = 0;
var colno = 0;
var output = "";
try {
var parentTemplate = null;
output += "-- models/raw_users.sql.njk\n-- name: raw_users\n\nSELECT id, name, created_at FROM raw_users_table\n";
if(parentTemplate) {
parentTemplate.rootRenderFunc(env, context, frame, runtime, cb);
} else {
cb(null, output);
}
;
} catch (e) {
  cb(runtime.handleError(e, lineno, colno));
}
}
return {
root: root
};

})();
})();


export const templates = {
  "example": env.getTemplate("example", true),
  "products": env.getTemplate("products", true),
  "raw_users": env.getTemplate("raw_users", true)
}
