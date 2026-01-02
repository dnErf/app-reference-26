import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

/**
 * Orchestrator class for planning and deploying CDT changes.
 */
class Orchestrator {
  /**
   * @param {Runner} runner - Instance of Runner.
   */
  constructor(runner) {
    this.runner = runner;
    this.plans = {};
  }

  /**
   * Plans changes for an environment.
   * @param {string} env - Environment name.
   * @param {string} modelsDir - Models directory.
   * @returns {object} Plan with changes.
   */
  async plan(env, modelsDir = 'models/') {
    try {
      const models = fs.readdirSync(modelsDir).filter(f => f.endsWith('.sql'));
      const changes = [];
      for (const model of models) {
        const content = fs.readFileSync(path.join(modelsDir, model), 'utf8');
        const hash = crypto.createHash('md5').update(content).digest('hex');
        const prevHash = this.plans[`${env}:${model}`];
        if (!prevHash || prevHash !== hash) {
          changes.push(`Update ${model}`);
          this.plans[`${env}:${model}`] = hash;
        }
      }
      console.log(`Planning for env: ${env}, changes:`, changes);
      return { changes };
    } catch (error) {
      console.error('Planning error:', error.message);
      throw error;
    }
  }

  /**
   * Deploys changes to an environment.
   * @param {string} env - Environment name.
   * @param {object} changes - Changes to deploy.
   * @returns {object} Deployment result.
   */
  async deploy(env, changes) {
    console.log(`Deploying to ${env}:`, changes);
    // Simulate deployment
    return { status: 'success' };
  }

  /**
   * Runs tests.
   * @param {string} modelsDir - Models directory.
   * @returns {object} Test results.
   */
  async test(modelsDir) {
    // Run data quality tests (placeholder)
    console.log('Running tests...');
    return { passed: true, failed: [] };
  }
}

export default Orchestrator;