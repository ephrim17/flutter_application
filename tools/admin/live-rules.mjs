// Read-only: fetches the live Firestore/Storage rulesets via the Rules API.
import { GoogleAuth } from 'google-auth-library';
import { readFileSync, writeFileSync } from 'node:fs';

const keyPath = process.argv[process.argv.indexOf('--key') + 1];
const auth = new GoogleAuth({
  credentials: JSON.parse(readFileSync(keyPath, 'utf8')),
  scopes: ['https://www.googleapis.com/auth/firebase.readonly',
           'https://www.googleapis.com/auth/cloud-platform'],
});
const client = await auth.getClient();
const project = 'flutterlearning-c9f6c';
const base = `https://firebaserules.googleapis.com/v1/projects/${project}`;

const releases = await client.request({ url: `${base}/releases` });
for (const release of releases.data.releases || []) {
  console.log(release.name.split('/').pop(), '->', release.rulesetName.split('/').pop(),
    'updated', release.updateTime);
}

for (const release of releases.data.releases || []) {
  const id = release.rulesetName.split('/').pop();
  const ruleset = await client.request({ url: `${base}/rulesets/${id}` });
  const files = ruleset.data.source?.files || [];
  for (const file of files) {
    const out = `/private/tmp/claude-501/-Users-ephrim-daniel-Documents-Flutter-Projects-flutter-application/ac80d630-8416-4975-b67e-d5b1a9b32ac3/scratchpad/live_${release.name.split('/').pop().replace(/[^a-z0-9]/gi,'_')}_${file.name}`;
    writeFileSync(out, file.content);
    console.log('  wrote', out, `(${file.content.length} bytes, created ${ruleset.data.createTime})`);
  }
}
