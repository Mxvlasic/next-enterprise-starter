# Project Plan — `next-enterprise-starter`

Turning the generated `next-enterprise` base into a reusable, **containerized**, **secured**, **deployable** application starter.

> Status: Phase 1 (containerize) complete and verified. Phases 2+ not started.
> Repo: `Mxvlasic/next-enterprise-starter` — **public**, marked as a GitHub **template**.

---

## 0. Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Repo visibility | **Public** | Unlocks free CodeQL, secret scanning, dependency review, and unlimited Actions minutes (all GHAS-gated/paid on private). Fits an open starter/portfolio piece. |
| First deploy target | **Cloud Run** (serverless container) | Runs the exact image, scales to ~$0 idle, real HTTPS URL fast. Cheapest path to a live result. |
| Kubernetes | **Optional / portability-only** | Manifests kept in the template for portability, but **not** a deployment target for this app. Revisit later if a use case demands it. |
| Registry | GHCR (public images) | Provider-neutral, free, pullable by Cloud Run. |
| Package manager | pnpm@10 (frozen lockfile) | already the base's choice |

> The plan was re-evaluated from a "build everything then integrate" shape to a **walking-skeleton-first** shape: prove the end-to-end path (a live URL) before hardening.

---

## 1. Objective

A public template repo you can clone and immediately get:

1. **Containerized** — a portable production Docker image (the single universal artifact).
2. **Deployed for real** — runs on a cheap serverless target with HTTPS and a live URL.
3. **Secured & verified in CI** — vulnerability, secret, and dependency scanning on every PR.
4. **Portable** — runs on anything that speaks Docker; optional K8s manifests included for future hosts.

Long-term intent: an asset for internal BI work and, potentially, client/freelance work.

---

## 2. Base repo facts (confirmed at clone time)

| Item | Value |
|---|---|
| Framework | Next.js `15.5.18` (App Router), React `19` |
| Language | TypeScript (strict) |
| Styling / UI | Tailwind v4, Radix UI, CVA |
| Package manager | `pnpm@10.0.0` (frozen lockfile in CI) |
| Node | `>=20`; CI reads `.github/nodejs.version` |
| Health endpoint | `GET /api/health` → `{ "status": "ok" }`; rewrites `/healthz`, `/api/healthz`, `/health`, `/ping` |
| Existing CI | `check.yml` (lint, prettier, vitest, storybook smoke), `playwright.yml`, bundle analysis |
| Env validation | `@t3-oss/env-nextjs` (`env.mjs`) |
| Missing (what we add) | Dockerfile, deploy pipeline, security scanning, optional K8s manifests |

---

## 3. Phase 1 — Containerize

**Goal:** `docker build` yields a small, secure, non-root image that runs Next.js in standalone mode.

### Tasks
1. Add `output: "standalone"` to `next.config.ts`.
2. Multi-stage `Dockerfile`:
   - `deps`: `node:22-bookworm-slim`, corepack + `pnpm install --frozen-lockfile`.
   - `build`: copy source, `pnpm build`; `ARG`/`ENV` for `NEXT_PUBLIC_*`; `NEXT_TELEMETRY_DISABLED=1`.
   - `runner`: copy `.next/standalone`, `.next/static`, `public`; **non-root** user; `EXPOSE 8080`; `HEALTHCHECK` → `/api/health`; entrypoint `node server.js`.
   - **Listen on `$PORT`** (Cloud Run injects `PORT`, default 8080) — the standalone server honors `process.env.PORT`.
   - Build for **linux/amd64** (Cloud Run requirement).
3. `.dockerignore` (node_modules, .next, .git, coverage, storybook-static, playwright-report).
4. `docker-compose.yml` for local runs.
5. Verify locally: build, run, `curl /api/health`, Playwright against the container.

### Acceptance
- Image builds reproducibly; size `< ~300 MB`; runs **non-root**; healthcheck healthy; `docker run -p 8080:8080` serves the app.

**Done (verified):** image `next-enterprise-starter:p1` — **283 MB**, runs as `nextjs`
(non-root), `HEALTHCHECK` reports `healthy`, `/api/health` → `{"status":"ok"}`,
homepage 200. Runner stage is Alpine/musl; glibc duplicates excluded via
`outputFileTracingExcludes` in `next.config.ts`. Verified with a local rootless
Docker daemon (no Docker Desktop needed).

---

## 4. Phase 2 — Deploy for real (the "prove it out" moment)

**Goal:** a **live HTTPS URL** running the container on Cloud Run. This is the point of the project — do it early.

### Tasks
1. Create/confirm a GCP project with billing enabled (Cloud Run free tier is generous; ~$0 idle).
2. Push the image to **GHCR** (`ghcr.io/mxvlasic/next-enterprise-starter`).
3. `gcloud run deploy` from that image; set `PORT`, memory/CPU, min instances `0` (scale to zero).
4. **Custom domain + TLS** — map a domain (Cloud Run gives an HTTPS URL by default; custom domain mapping for a nicer host).
5. Smoke test: hit the live URL + `/api/health`.

### Acceptance
- Public HTTPS URL serves the app.
- `/api/health` returns `{"status":"ok"}` on the live URL.
- Idle cost ≈ $0.

---

## 5. Phase 3 — CI/CD

**Goal:** every push builds, checks, and deploys automatically.

### Tasks
1. `docker.yml`: build image on PR; on `main`, push to GHCR.
2. Reuse existing `check.yml` (lint/prettier/vitest/storybook) + `playwright.yml`.
3. `deploy.yml`: on `main`, deploy the new image to Cloud Run (dev). Prod on tag/manual approval.
4. Auth to GCP via **Workload Identity Federation** (no long-lived keys) — or a documented service-account key as a stopgap.

### Acceptance
- Push to `main` → image built, checks pass, Cloud Run updated automatically.

---

## 6. Phase 4 — Security & supply-chain scanning

**Goal:** every PR is scanned; findings surface in the Security tab (now free, repo is public).

> **Visibility-aware by design (already scaffolded).** The pipeline detects the derived repo's visibility at runtime via `.github/actions/detect-visibility` and runs GHAS-only jobs (CodeQL, dependency review, SARIF upload) **only where they exist** — public repos, or a private repo with Code Security plus repo variable `ENABLE_GHAS=true`. Always-on scanners run regardless. A private clone must never fail for lack of GHAS. See `docs/CLONING.md`.

### Tasks
1. **CodeQL** (`javascript-typescript`) — free on public repos.
2. **Dependency review** action on PRs; **Dependabot** alerts + updates.
3. **Secret scanning** + push protection (free on public repos).
4. **Trivy** image scan in CI (OS + libraries) → SARIF; fail on HIGH/CRITICAL.
5. **SBOM** (Syft/anchore) per build; optional **cosign** keyless signing via OIDC.
6. **Hadolint** on the Dockerfile.
7. **Branch protection / rulesets** requiring the check + security workflows.

### Acceptance
- PRs trigger scans; findings in the Security tab; build fails on threshold; SBOM produced.

---

## 7. Phase 5 — Kubernetes manifests (optional, portability-only)

**Goal:** ship standard manifests so the image can move to any cluster later — **not deployed now.**

### Tasks
1. Kustomize base + `overlays/dev`, `overlays/prod`.
2. Deployment (probes → `/api/health`, resources, hardened `securityContext`, ≥2 replicas), Service, Ingress (cert-manager TLS), HPA, ConfigMap/Secret, PDB, NetworkPolicy.
3. Validate locally with **kind/k3d** + `kubeconform`; scan with Checkov.
4. Document as "how to deploy elsewhere", not part of the default path.

### Acceptance
- `kubectl apply -k overlays/dev` succeeds on a local cluster; manifests are documented and optional.

---

## 8. Phase 6 — Harden & template-ize

**Goal:** a lean, documented, reusable template.

### Tasks
1. **Strip cruft** — remove demo/showcase content not wanted in a starter (Storybook demo, semantic-release, all-contributors, bundle-analyzer demo, OTel if unused). *(Deliberate pass — the base is heavy.)*
2. Rename app/package; write a README covering local dev, Docker, deploy, and the optional K8s path.
3. Add a "Use this template" walkthrough + env var docs.
4. Confirm the template flag, license/attribution (MIT, Blazity).

### Acceptance
- A fresh clone from "Use this template" runs locally and deploys to Cloud Run following the README only.

---

## 9. Phase order

| Phase | Scope | Depends on |
|---|---|---|
| **P1** | Dockerfile + compose, verified locally | — |
| **P2** | Deploy to Cloud Run + domain/TLS (**live URL**) | P1 |
| **P3** | CI/CD: build/push + checks + auto-deploy | P2 |
| **P4** | Security & supply-chain scanning | P3 |
| **P5** | Optional K8s manifests (not deployed) | P1 |
| **P6** | Strip + README + template-ize | P1–P4 |

---

## 10. Remaining open decisions

1. **Domain** — which domain to map to the Cloud Run service (needed for P2's "real result").
2. **GCP auth in CI** — Workload Identity Federation (preferred) vs service-account key.
3. **Registry** — GHCR (proposed) vs Artifact Registry.
4. **Image base** — Debian slim (proposed) vs Alpine.
5. **Trim list** — exactly what to strip from the base in P6.
