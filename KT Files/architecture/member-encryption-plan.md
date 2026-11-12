# Encrypting member records

Status: **plan, not built.** Decision taken 2026-11-12: server-side
encryption with Cloud KMS, no key on any device.

## What this is for, and what it is not

Firestore and Cloud Storage are already encrypted at rest with AES-256 by
Google. So "encrypt the member records" cannot mean at-rest encryption —
that exists. It means **application-level encryption**: the bytes in the
document are ciphertext that only the Cloud Functions service account can
turn back into a phone number.

That buys protection against:

- a mistake in `firestore.rules` exposing a collection (the known open item
  in this project),
- a leaked service-account key or console access — the current purge key
  included,
- anyone who can read the database but cannot call KMS,
- a stolen device: the app never holds a key, so the ciphertext it caches
  is worthless.

It does **not** protect against: a compromised Cloud Function, an attacker
who obtains the functions' identity (they can call KMS by definition), or a
church admin who is legitimately allowed to read the member they are
looking at. Encryption narrows who can read the data; it does not change
who is *allowed* to.

**The reason it is server-side.** A key shipped inside the Flutter app —
in Dart source, in an asset, in the keystore of an app anyone can download
— can be extracted from the bundle. Client-side encryption would look
identical in the console and stop nothing. Only a key the device never
holds is worth the work.

## Design

**Envelope encryption.** One Cloud KMS key (`projects/flutterlearning-c9f6c/
locations/asia-south1/keyRings/church-tree/cryptoKeys/members`) wraps a
per-church 256-bit data key. The wrapped DEK is stored at
`churches/{cid}/config/encryption`; the plaintext DEK exists only in a
function's memory, cached with a short TTL. Per church, so one church's
data cannot be read with another's key, and a single church can be
re-keyed without touching the rest.

**Per field: AES-256-GCM**, 96-bit random IV per write, and the
authenticated data bound to `churchId|docId|fieldName|keyVersion` — so a
ciphertext cannot be lifted from one member's phone field into another's
and still decrypt. Stored as `{ v, iv, ct, tag }`, base64.

**Where the ciphertext lives.** Sensitive fields move off the member
document into `churches/{cid}/members/{docId}/private/data`, which the
security rules deny to every client. Rules cannot hide one field of a
document, so the only way for "no client reads this, ever" to be
enforceable is for it to be its own document. Ciphertext on an unreadable
document is defence in depth: the rules stop the read, and the encryption
means a rules mistake still yields nothing.

**Field tiers.** Encrypting everything would cost the members list its
ability to sort and page in the client, for little gain on a field like a
display name that every approved member can already see in the directory.

| Tier | Fields | Treatment |
|---|---|---|
| Sensitive | phone, email, address, date of birth, baptism certificate number / church / pastor, marriage solemnization details, financial stability rating, financial support required, membership notes, additional notes | Encrypted, in `private/data`, never sent to a client that is not staff |
| Indexed | phone, email | Also stored as a blind index (below) so lookup and duplicate detection still work |
| Plain | display name, photo, gender, marital status, approved, role, group ids, joinedAt | Left as they are — the directory already shows them to members, and the list needs them to sort and page |

**Blind indexes.** `idx_phone = HMAC-SHA256(indexKey, normalizedPhone)`,
stored alongside the ciphertext. Equality lookups (the duplicate-phone
check, "who is this number?") keep working without decryption. It leaks
equality — two members with the same number produce the same index — which
is exactly the property the duplicate check needs. No ranges, no prefixes,
no sorting.

**Access path.** Clients stop reading `members` directly for the sensitive
tier and call `getMemberPrivate`, `saveMemberPrivate`, `findMemberByPhone`.
Each callable checks church-admin authority server-side — this is the first
time that check stops being advisory, since the rules can no longer be the
only thing standing in front of the data.

## What it costs

Worth stating plainly before it is built:

- **Members, Attendance, Messages and Dashboard all touch these fields.**
  Messages reads phone numbers for the whole congregation; that becomes a
  server call that returns numbers only to a verified admin.
- **No offline access** to the sensitive tier, and a round trip where there
  was a cached read.
- **No client-side query** on an encrypted field — no "sort by date of
  birth", no range filters. Birthday prompts move to a scheduled function
  that works from the blind-indexed month/day, or stays plaintext by
  decision.
- **Cost and latency**: one KMS unwrap per cold function instance, then
  in-memory. Negligible in money, real in cold-start time.
- **Key loss is data loss.** KMS keys cannot be deleted by accident easily,
  but IAM can be. The DEK is backed up with the project's backups and the
  KMS key must never be scheduled for destruction.

## Phases

1. **Key material.** KMS key ring and key, IAM for the functions service
   account (`cloudkms.cryptoKeyEncrypterDecrypter`, nothing wider), DEK
   generation and the `config/encryption` document. Nothing reads it yet.
2. **Crypto module in `functions/src/crypto/`**, with its own tests:
   encrypt/decrypt round trip, AAD mismatch rejected, tampered ciphertext
   rejected, blind index stability, key-version handling.
3. **Callables** (`getMemberPrivate`, `saveMemberPrivate`,
   `findMemberByPhone`) with server-side admin authority checks and App
   Check enforced.
4. **Dual write.** Writes go to both plaintext and ciphertext; reads still
   use plaintext. Reversible at any point.
5. **Backfill** every existing member, then verify: every document has a
   `private/data`, every ciphertext decrypts, every blind index matches.
6. **Flip reads** to the callables, screen by screen — Members, then
   Attendance, Messages, Dashboard, Studio.
7. **Strip the plaintext** fields and tighten the rules to deny
   `members/{id}/private/**` to all clients. This is the irreversible step;
   it happens after a backup and after a week on dual write.
8. **Rotation drill.** Re-wrap the DEK under a new key version, confirm old
   ciphertext still decrypts by its recorded version.

## Open questions for the owner

- Is the **display name** sensitive? Encrypting it costs the members list
  its client-side sort and search; leaving it plain means a leak exposes who
  belongs to the church, but not how to contact them.
- **Birthdays**: the Home prompt needs a date comparison. Keep the day and
  month plain and encrypt only the year, or move the prompt server-side?
- Should **Storage** objects (member photos) be encrypted too, or is a
  tightened rules file enough for images?
