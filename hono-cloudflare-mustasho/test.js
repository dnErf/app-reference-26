import { Runner } from './lib/index.js';

async function test() {
  const runner = new Runner({});
  await runner.run('models/', {
    columns: 'id, name',
    database: 'test_db',
    schema: 'public',
    START_DATE: '2023-01-01'
  });
  console.log('Test run complete');
  console.log('Results:', runner.getResults());
  console.log('Errors:', runner.getErrors());
}

test();