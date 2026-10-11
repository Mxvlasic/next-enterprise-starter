# Cloning & visibility — public vs private

This is a **GitHub template**. You can generate a **public** repo or a **private**
repo from it, and **the CI adapts automatically** to whichever you choose. No
manual edits are needed to make a private clone build.

## How it adapts (the mechanism)

- **`.github/actions/detect-visibility`** — a reusable composite action that
  resolves the repository visibility (`public` / `private` / `internal`) from the
  event payload, with an API fallback for events that omit it (e.g. `schedule`).
  It outputs `visibility`, `is_public`, `is_private`, and `ghas`.
- **`.github/workflows/security.yml`** consumes those outputs:
  - **GHAS-gated jobs** (`CodeQL`, `dependency review`, SARIF upload) run **only**
    when `ghas == true` — i.e. on **public** repos, or on a **private** repo you
    have explicitly opted in (see below).
  - **Always-on jobs** (secret scanning) run regardless of visibility.

This means a **private clone never fails for lack of GitHub Advanced Security**,
while a **public clone automatically gets the full free security suite**.

---

## Path A — Public repo (recommended for the generic template)

1. On the template page, click **Use this template → Create a new repository**.
2. Set visibility to **Public**.
3. Done. You get, for free:
   - **Unlimited** GitHub Actions minutes (private is 2,000/mo, then billed).
   - **CodeQL / code scanning**, **secret scanning + push protection**, and
     **dependency review** — all GHAS-gated and **paid** on private repos.
4. Build locally:
   ```bash
   pnpm install
   pnpm build
   docker build -t my-app .        # after Phase 1 lands the Dockerfile
   ```

## Path B — Private repo (for client / company / proprietary work)

1. **Use this template → Create a new repository**.
2. Set visibility to **Private**.
3. That's it — the same clone builds. CI auto-detects `private` and:
   - **skips** the GHAS-gated jobs (CodeQL, dependency review, SARIF upload),
   - **still runs** the always-on scanners (secret scanning).
4. Build locally: identical commands to Path A.

### Optional: full suite on a private repo (only if you have GHAS)

GitHub **Code Security** (GHAS) requires a **GitHub Team or Enterprise** plan.
If you have it and want the full suite on a private repo:

1. Settings → Secrets and variables → Actions → **Variables** → new variable
   **`ENABLE_GHAS`** = `true`.
2. The pipeline then treats the repo as GHAS-capable and runs CodeQL,
   dependency review, and SARIF uploads.

Without GHAS, leave it unset — the free scanners still protect you.

---

## The hybrid strategy (recommended overall)

Keep the **generic template public** (free CI + free security + portfolio
reach), and spawn **private repos** from it for real/proprietary work via
**Use this template**. Same code, correct behaviour per privacy — no forks, no
maintenance drift.

| Use case | Repo | Why |
|---|---|---|
| The reusable starter itself | **Public** | free unlimited CI, free GHAS features, discoverable |
| Company BI work | **Private** | confidentiality |
| Client deliverables | **Private** | IP protection, secrets |
| Open-source experiments | **Public** | free + visible |

---

## What changes between the two paths

| | Public | Private (no GHAS) | Private + `ENABLE_GHAS=true` |
|---|---|---|---|
| Actions minutes | unlimited free | 2,000/mo, then billed | 2,000/mo, then billed |
| CodeQL / code scanning | ✅ | ⏭️ skipped | ✅ |
| Dependency review | ✅ | ⏭️ skipped | ✅ |
| SARIF → Security tab | ✅ | ⏭️ skipped | ✅ |
| Secret scanning (Gitleaks) | ✅ | ✅ | ✅ |
| Builds the app | ✅ | ✅ | ✅ |

The key guarantee: **visibility never breaks the build** — it only decides how
much of the optional security suite runs.
