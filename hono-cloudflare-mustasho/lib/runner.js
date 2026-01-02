import fs from 'fs';
import path from 'path';
import { renderSQL } from './template-engine.js';

/**
 * Runner class for executing CDT models.
 */
class Runner {
  /**
   * @param {object} config - Configuration object (e.g., { d1, database, schema }).
   */
  constructor(config = {}) {
    this.config = config;
    this.mockDB = {};
    this.errors = [];
  }

  /**
   * Runs models in the specified directory.
   * @param {string} modelsDir - Path to models directory.
   * @param {object} context - Context for templating.
   */
  async run(modelsDir, context = {}) {
    try {
      const models = fs.readdirSync(modelsDir).filter(f => f.endsWith('.sql')).sort();
      for (const model of models) {
        const template = fs.readFileSync(path.join(modelsDir, model), 'utf8');
        const sql = renderSQL(template, { ...this.config, ...context });
        console.log(`Executing ${model}: ${sql}`);
        this.mockDB[model] = { sql, executed: true };
        // Simulate D1 execution
        if (this.config.d1) {
          await this.config.d1.prepare(sql).run();
        }
      }
    } catch (error) {
      this.errors.push(error.message);
      console.error('Runner error:', error.message);
      throw error;
    }
  }

  /**
   * Performs backfill for a model.
   * @param {string} model - Model name.
   * @param {string} startDate - Start date.
   * @param {string} endDate - End date.
   * @returns {object} Backfill result.
   */
  async backfill(model, startDate, endDate) {
    try {
      const sql = `SELECT * FROM ${model} WHERE date BETWEEN '${startDate}' AND '${endDate}'`;
      console.log(`Backfilling ${model}: ${sql}`);
      if (this.config.d1) {
        return await this.config.d1.prepare(sql).all();
      }
      return this.mockDB[model] || { data: [] };
    } catch (error) {
      this.errors.push(error.message);
      throw error;
    }
  }

  /**
   * Validates model dependencies.
   * @param {string[]} models - List of model files.
   */
  validateDependencies(models) {
    // Simple check: ensure refs exist
    const defined = models.map(m => m.replace('.sql', ''));
    for (const model of models) {
      const content = fs.readFileSync(path.join('models', model), 'utf8');
      const refs = content.match(/\{\{\s*ref\s+'([^']+)'\s*\}\}/g) || [];
      for (const ref of refs) {
        const table = ref.match(/ref\s+'([^']+)'/)[1];
        if (!defined.includes(table)) {
          throw new Error(`Dependency ${table} not found for ${model}`);
        }
      }
    }
  }

  /**
   * Gets execution results.
   * @returns {object} Mock DB results.
   */
  getResults() {
    return this.mockDB;
  }

  /**
   * Gets errors.
   * @returns {string[]} List of errors.
   */
  getErrors() {
    return this.errors;
  }
}

export default Runner;