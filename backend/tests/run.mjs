// Runs the SQL tests against a throwaway Postgres. Start it with:  npm test
//
// What it does:
//   1. starts a temporary Postgres (nothing is installed, it is deleted afterwards)
//   2. loads a small stand-in for the Supabase parts that plain Postgres lacks (tests/support/00_*.sql)
//   3. applies every migration in supabase/migrations, then supabase/seed.sql
//   4. loads the test helpers, then runs every file in tests/sql in order
//
// A test passes when its file runs without an error. Each file prints one "PASS: name" line per test.

import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const backend = path.resolve(here, '..');

const sqlFilesIn = (dir) =>
  fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort().map((f) => path.join(dir, f));

const steps = [
  ['stand-in for Supabase', sqlFilesIn(path.join(here, 'support')).filter((f) => f.includes('00_'))],
  ['migrations', sqlFilesIn(path.join(backend, 'supabase', 'migrations'))],
  ['seed data', [path.join(backend, 'supabase', 'seed.sql')]],
  ['test helpers', sqlFilesIn(path.join(here, 'support')).filter((f) => f.includes('10_'))],
  ['tests', sqlFilesIn(path.join(here, 'sql'))],
];

const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wishywashy-pg-'));
const port = 54000 + Math.floor(Math.random() * 900);
const server = new EmbeddedPostgres({
  databaseDir: dataDir,
  user: 'postgres',
  password: 'password',
  port,
  persistent: false,
  onLog: () => {},
  onError: () => {},
});

let passed = 0;
let failed = false;
let client;

try {
  await server.initialise();
  await server.start();
  await server.createDatabase('wishywashy_test');

  client = new pg.Client({ host: 'localhost', port, user: 'postgres', password: 'password', database: 'wishywashy_test' });
  client.on('error', () => {});
  await client.connect();
  client.on('notice', (n) => {
    if (n.message.startsWith('PASS: ')) {
      passed += 1;
      console.log('  ✔ ' + n.message.slice(6));
    }
  });

  for (const [label, files] of steps) {
    console.log(label + ':');
    for (const file of files) {
      const name = path.relative(backend, file);
      try {
        await client.query(fs.readFileSync(file, 'utf8'));
        if (label !== 'tests') console.log('  · ' + name);
      } catch (error) {
        failed = true;
        console.error('\n  ✘ ' + name + ' failed: ' + error.message);
        if (error.detail) console.error('    ' + error.detail);
        if (error.where) console.error('    ' + error.where.split('\n').join('\n    '));
        throw error;
      }
    }
  }

  // The reset script must wipe everything, and the migrations must then apply cleanly again
  console.log('reset script:');
  await client.query(fs.readFileSync(path.join(backend, 'supabase', 'dev_reset.sql'), 'utf8'));
  for (const file of [...steps[1][1], ...steps[2][1]]) {
    await client.query(fs.readFileSync(file, 'utf8'));
  }
  const { rows } = await client.query('select count(*)::int as n from public.machines');
  if (rows[0].n !== 39) throw new Error('expected 39 machines after reset and re-apply, got ' + rows[0].n);
  passed += 1;
  console.log('  ✔ dev_reset.sql wipes everything and the migrations apply cleanly again');
} catch (error) {
  failed = true;
  if (!error.where) console.error('\n  ✘ ' + error.message);
} finally {
  await client?.end().catch(() => {});
  await server.stop().catch(() => {});
  fs.rmSync(dataDir, { recursive: true, force: true });
}

console.log(failed ? '\nFAILED' : `\nAll ${passed} tests passed.`);
process.exit(failed ? 1 : 0);
