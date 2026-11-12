# Admin scripts

One-off maintenance against the live project, run from a laptop with a
service-account key. They bypass the security rules, so they are deliberately
awkward: read-only by default, destructive only with `--apply`, a matching
`--confirm`, and a backup manifest on disk.

## Credentials

Firebase Console → Project settings → Service accounts → **Generate new
private key**. Save it **outside the repository** (it is a root key for the
project — anyone holding it can read and delete everything):

```
export GOOGLE_APPLICATION_CREDENTIALS=~/church-tree-admin-key.json
export NODE_PATH=../../functions/node_modules   # firebase-admin lives there
```

Delete the key in the Console when the work is finished.

## Order

```bash
cd tools/admin

# 1. What is actually there (read-only)
node inventory.mjs tnbm

# 2. Backup — Firestore, Auth and Storage to local files
node backup.mjs --out ~/church-tree-backup

# 3. Churches and their Storage objects (dry run first, no flags)
node purge-firestore.mjs --keep tnbm
node purge-firestore.mjs --keep tnbm --backup ~/church-tree-backup --apply --confirm tnbm

# 4. Auth accounts (dry run first)
node purge-auth.mjs --keep-email ephrimdaniel17@outlook.com --keep-email arulvivek@gmail.com
node purge-auth.mjs --keep-email ephrimdaniel17@outlook.com --keep-email arulvivek@gmail.com \
  --backup ~/church-tree-backup --apply --confirm DELETE-ACCOUNTS
```

`--delete-user-docs` additionally removes `users/{uid}` and its
subcollections for each deleted account. `--keep-church-members <churchId>`
spares that church's members, for the softer version of step 4.

## What is not touched

`churches/global` in Storage (the global feed's images), `bible_versions`,
`learning_modules` and the other root collections. A church's membership
documents under the church that is kept survive step 4 even when the
account behind them does not — they will point at uids that no longer
exist, which is what "delete every account but two" means.
