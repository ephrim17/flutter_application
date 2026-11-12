// Read-only: evaluates a ruleset against a simulated request using the
// Firebase Rules API. Nothing is written anywhere.
import { GoogleAuth } from 'google-auth-library';
import { readFileSync } from 'node:fs';

const keyPath = process.argv[process.argv.indexOf('--key') + 1];
const rulesFile = process.argv[process.argv.indexOf('--rules') + 1];
const auth = new GoogleAuth({
  credentials: JSON.parse(readFileSync(keyPath, 'utf8')),
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});
const client = await auth.getClient();

const EMAIL = 'ephrimdaniel17@outlook.com';
const UID = 'hepQVL9Eu6VxCk05OU5IvsbNlAs2';
const NEW = 'zz_rules_probe';

const mock = (fn, path, result) => ({
  function: fn,
  args: [{ exact_value: path }],
  result,
});
const EXISTS = { value: true };
const MISSING = { value: false };

// What Firestore really holds: the new church and its config/app do not
// exist; the super-admin record and the user document do.
const functionMocks = [
  mock('firestore.exists', `/databases/(default)/documents/churches/${NEW}`, MISSING),
  mock('firestore.exists', `/databases/(default)/documents/churches/${NEW}/config/app`, MISSING),
  mock('firestore.get', `/databases/(default)/documents/churches/${NEW}/config/app`, { undefined: {} }),
  mock('firestore.exists', `/databases/(default)/documents/superAdmins/${EMAIL}`, EXISTS),
  mock('firestore.get', `/databases/(default)/documents/superAdmins/${EMAIL}`, { value: { data: { enabled: true } } }),
  mock('firestore.exists', `/databases/(default)/documents/users/${UID}`, EXISTS),
  mock('firestore.get', `/databases/(default)/documents/users/${UID}`, { value: { data: { emailVerified: true } } }),
];

const testCase = {
  expectation: 'ALLOW',
  expressionReportLevel: 'VISITED',
  functionMocks,
  request: {
    auth: { uid: UID, token: { email: EMAIL, email_verified: true } },
    path: `/b/flutterlearning-c9f6c.firebasestorage.app/o/churches/${NEW}/logo`,
    method: 'create',
    time: new Date().toISOString(),
    resource: { size: 8, contentType: 'image/png' },
  },
};

const response = await client.request({
  url: 'https://firebaserules.googleapis.com/v1/projects/flutterlearning-c9f6c:test',
  method: 'POST',
  data: {
    source: { files: [{ name: 'storage.rules', content: readFileSync(rulesFile, 'utf8') }] },
    testSuite: { testCases: [testCase] },
  },
});

for (const result of response.data.testResults || []) {
  console.log('state:', result.state);
  for (const error of result.errorPosition ? [result] : []) console.log('  error at', JSON.stringify(error.errorPosition));
  for (const message of result.debugMessages || []) console.log('  debug:', message);
  for (const report of result.expressionReports || []) {
    const value = JSON.stringify(report.value);
    if (value === undefined || value === 'null') {
      console.log(`  line ${report.sourcePosition?.line}: ERROR / no value`);
    }
  }
}
