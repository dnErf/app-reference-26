#!/usr/bin/env node
import minimist from 'minimist';
import { Runner, Orchestrator } from '../lib/index.js';

const args = minimist(process.argv.slice(2));
const command = args._[0];

if (command === 'run') {
  const runner = new Runner({});
  await runner.run(args.models || 'models/', {
    database: args.database || 'test_db',
    schema: args.schema || 'public',
    columns: args.columns || 'id, name',
    START_DATE: args.startDate || '2023-01-01',
    incremental: args.incremental || false,
    filter_active: args.filterActive || false
  });
} else if (command === 'plan') {
  const orch = new Orchestrator();
  await orch.plan(args.env || 'dev');
} else if (command === 'test') {
  const orch = new Orchestrator();
  await orch.test(args.models || 'models/');
} else {
  console.log('Usage: cdt run --models=models/ --database=my_db | cdt plan --env=prod | cdt test');
}