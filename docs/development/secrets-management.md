# Secrets Management

Where every value lives, why, and what to do when one leaks.

Authority: ADR-016, ADR-007, ADR-008, ADR-015. Follows Volume 4 Ch. 4.7/4.9, Volume 7 Ch. 7.10, Volume 8 Ch. 8.4, Volume 10.

---

## The one question to ask

**Does possessing this value let someone act as a user, or as the application?**

- **Yes** → it is a **secret**. AWS Secrets Manager. Nowhere else.
- **No, but it changes per environment** → **configuration**. A `.env` file or a Lambda environment variable.
- **No, and it is extractable from a shipped binary anyway** → **public**. Source control is fine.

Sensitivity is not the test. A Firebase API key *feels* sensitive and is not a secret — Google publishes it in every web app, and Security Rules, not concealment, are what protect the project. A database password is a secret because holding it *is* being the database user.

---

## Where each value lives

| Value | Tier | Home |
|---|---|---|
| `APP_ENV` | Configuration | `mobile/.env.*`, Lambda env var |
| API base URL | Public | `NetworkConfig` in code (ADR-007) |
| S3 bucket names | Public | `infrastructure/aws/config/environments.json` |
| AWS region | Public | Same |
| Firebase client config (API key, app ID, project ID) | Public | `firebase_options.dart`, `google-services.json` (ADR-010) |
| Secret ARNs | Configuration | Lambda env vars |
| **Firebase Admin service account key** | **Secret** | **Secrets Manager** |
| **Aurora credentials** | **Secret** | **Secrets Manager** |
| **CloudFront signing private key** | **Secret** | **Secrets Manager** (when CloudFront is enabled) |
| Android keystore, iOS signing key | Secret | CI secret store; never in the repo |
| User access / refresh tokens | Secret | Device secure storage (ADR-008) |

---

## Flutter

**The app holds no secret. Ever.** A binary on a device outside our control can be decompiled; anything compiled in is published.

`mobile/.env.dev` / `.env.staging` / `.env.prod` contain **one variable**:

```bash
APP_ENV=development
```

Everything else — base URL, bucket, timeouts — is derived in code from that single value (ADR-007, ADR-011). One input means no build can have an environment and a base URL that disagree.

```bash
cp mobile/.env.example mobile/.env.dev
flutter run --dart-define-from-file=.env.dev
flutter build appbundle --dart-define-from-file=.env.prod
```

The real files are gitignored. They hold no secret, but they are per-developer, and a committed one becomes the place someone later adds something that should not be there.

**If the app seems to need a secret, it needs a backend endpoint.** Call it with the user's Firebase ID token and let the server hold the credential. That is the same principle as presigned uploads: the device gets a scoped capability, never an identity.

---

## Backend

Runtime is AWS Lambda + Node.js + TypeScript (ADR-015). The backend does not exist yet; this is the contract it will be built against.

**In AWS** — credentials come from the Lambda execution role, resolved by the SDK's default provider chain. The `S3Client` is constructed with a region and nothing else.

**Locally** — the same provider chain resolves a named CLI profile:

```bash
cp backend/.env.example backend/.env
# then set AWS_PROFILE=vump-dev in backend/.env
```

The code path is identical in both. There is no local-mode branch, so nothing behaves differently where it is hardest to observe.

**`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` appear nowhere** — not in `.env.example`, not in CI, not in Lambda configuration. A task that appears to need them needs a profile or a role.

**Secret values are never Lambda environment variables.** V8.4 §2: they would be *"visible to anyone with read access to the function's configuration"*, which is a far wider set of principals than those permitted to read a specific secret. Lambda gets the **ARN**; the function resolves the value at runtime through its role.

Naming: `vump/{environment}/{secret-name}` — e.g. `vump/prod/firebase-service-account`.

| Secret | Rotation |
|---|---|
| Aurora credentials | Automatic, Secrets Manager native RDS rotation |
| Firebase service account key | Manual, annually or immediately on suspected compromise |

Cache a resolved secret within an invocation and across warm invocations. Never log it — not at debug level, not in an error message, not in a stack trace.

---

## Git

`.gitignore` blocks `.env` and `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.keystore`, `*.jks`, `key.properties`, `service-account*.json`, `firebase-adminsdk*.json`, and AWS credential files — while keeping `.env.example` committable. Verified against nine patterns.

**Verify before you commit**, especially the first time:

```bash
git check-ignore -v .env backend/.env mobile/.env.prod
git diff --cached                      # read it, don't skim it
```

### Recommended: enable GitHub's built-in scanning

Free on all repositories, and it catches things a grep never will:

1. **Settings → Code security → Secret scanning** — detects known credential formats across the full history.
2. **Push protection** — blocks the push rather than reporting it afterwards. This is the one that matters, because it acts before disclosure rather than after.

### Recommended: a deeper local scan

CI runs a pattern scan on every push (below), but it is deliberately narrow to avoid false positives. For history and entropy analysis:

```bash
gitleaks detect --source . --verbose      # full history
gitleaks protect --staged                 # pre-commit
```

Worth wiring into a pre-commit hook once the team grows past one person.

---

## CI/CD — what belongs in GitHub Secrets

Nothing today. The current pipeline runs analyze, test, format and boundary checks, and needs no credential — a property worth preserving as long as possible.

When deployment lands (Volume 10), these will be required:

| Secret | Purpose | Notes |
|---|---|---|
| `AWS_ROLE_TO_ASSUME` | Deployment role ARN | **Prefer OIDC.** GitHub federates with AWS and receives short-lived credentials per run. An ARN is not a secret; it is listed here because it belongs with the deploy configuration |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Deployment credentials | **Only if OIDC is not used.** Long-lived keys in CI are the single most commonly leaked AWS credential |
| `ANDROID_KEYSTORE_BASE64` | Signing keystore | Volume 10 |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Signing | Volume 10 |
| `APP_STORE_CONNECT_API_KEY` (+ key id, issuer id) | iOS signing and upload | Volume 10 Ch. 10.4 |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Store upload | Volume 10 |
| `FIREBASE_TOKEN` | Firebase CLI, if used in CI | |

**Use GitHub Environments** for `staging` and `production`, with required reviewers on production — that is where ADR-014's human approval gate is actually enforced. A repository-level secret is available to every workflow on every branch; an environment secret is not.

**Never** put in GitHub Secrets: anything already in Secrets Manager, Firebase client config, bucket names, or base URLs. CI has no reason to hold what production resolves at runtime.

---

## If a secret is committed

**Rotate first. Always.**

1. **Rotate or revoke the credential.** Assume it is compromised the moment it lands in a remote branch — it is in the reflog, in forks, in CI caches, and in anyone's clone.
2. **Confirm the new value works**, in Secrets Manager or the relevant provider.
3. **Then** clean history, with `git filter-repo` or BFG, and force-push. Everyone re-clones.
4. **Check for use** — CloudTrail for AWS credentials, provider audit logs otherwise.
5. **Record it** as an incident, and add the pattern to the CI scan so the same shape cannot recur.

Rewriting history without rotating is the common mistake. It hides the evidence and leaves the credential valid.

---

## Verifying this document is still true

```bash
# no AWS credential anywhere in the mobile app
grep -rnE '\b(AKIA|ASIA)[0-9A-Z]{16}\b' mobile/lib mobile/test

# secret files are ignored, examples are not
git check-ignore -v .env backend/.env mobile/.env.prod
git check-ignore .env.example || echo "example is committable — correct"

# nothing tracked that should not be
git ls-files | grep -Ei '\.(env|pem|key|p12|pfx|keystore|jks)$|service-account'
```

CI runs equivalents of the first and last on every push.
