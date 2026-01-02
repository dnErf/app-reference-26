import Handlebars from 'handlebars';

/**
 * Registers dbt-like helpers for SQL templating.
 */
function registerHelpers() {
  Handlebars.registerHelper('ref', function(table) {
    const database = this.database || 'default_db';
    const schema = this.schema || 'public';
    return `${database}.${schema}.${table}`;
  });

  Handlebars.registerHelper('var', function(key) {
    return this[key] || process.env[key] || `{{${key}}}`;
  });

  Handlebars.registerHelper('source', function(source) {
    return `source.${source}`;
  });

  Handlebars.registerHelper('config', function(key) {
    return this[key] || false;
  });
}

/**
 * Renders SQL template with context.
 * @param {string} template - The SQL template string.
 * @param {object} context - Context object for variables.
 * @returns {string} Rendered SQL.
 */
function renderSQL(template, context) {
  registerHelpers(); // Ensure helpers are registered
  const compiled = Handlebars.compile(template);
  return compiled(context);
}

export { renderSQL };