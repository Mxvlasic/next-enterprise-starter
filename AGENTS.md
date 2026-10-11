# AGENTS.md

Operating context for agents working in this repo. Auto-loaded each session by OpenCode V2.
Keep this file lean and point to versioned docs; do not duplicate them here.

## What this repo is

`next-enterprise-starter` — a reusable, **containerized**, **security-scanned**, **Kubernetes-deployable** application starter, generated from the `Blazity/next-enterprise` template. Goal: a low-cost, portable template for internal BI work and (potentially) client/freelance projects.

## Read these first

- `docs/PLAN.md` — full roadmap (phases, tasks, acceptance criteria).
- `docs/DEPLOYMENT-OPTIONS.md` — deployment targets analysis and locked decision.
- `docs/CLONING.md` — public vs private cloning; how CI adapts to repo visibility.

## Current state

- Base generated from `Blazity/next-enterprise`. **P1 (Dockerize) done and verified** —
  multi-stage Dockerfile (Debian build, Alpine runner, 283 MB, non-root, healthcheck).
- Repo is **public** and marked as a GitHub **template**.
- Phases: **P1 Dockerize ✅** → P2 Deploy to Cloud Run (live URL) → P3 CI/CD → P4 security scanning → P5 optional K8s manifests → P6 strip/template-ize.
- Next action: start **P2** (see `docs/PLAN.md` §4). P2 needs a GCP project + domain.

## Project facts

- Next.js 15 (App Router), React 19, TypeScript strict, Tailwind v4, Radix UI.
- Package manager: **pnpm@10** (frozen lockfile in CI). Node `>=20`; CI reads `.github/nodejs.version`.
- Health endpoint: `GET /api/health` → `{"status":"ok"}` (rewrites: `/healthz`, `/api/healthz`, `/health`, `/ping`). Use for container/K8s probes.
- Existing CI: `check.yml` (lint, prettier, vitest, storybook smoke), `playwright.yml`, bundle analysis.

## Working agreements

- Use **pnpm**; keep the lockfile frozen in CI.
- Any container must run **non-root** with a healthcheck on `/api/health`.
- Keep deployment manifests **provider-neutral** (Kustomize; standard Deploy/Service/Ingress) so k3s → managed K8s → client cluster needs only a kubeconfig change.
- Never commit plaintext secrets (Sealed Secrets / External Secrets).
- CI must stay **visibility-aware**: GHAS-only jobs run only on public repos (or private with repo variable `ENABLE_GHAS=true`). Use `.github/actions/detect-visibility`; see `docs/CLONING.md`. A private clone must always build without GHAS.
- Git identity is set to `Mxvlasic` with a GitHub noreply email — do not change it to a personal address.

## Decisions (locked — see docs/PLAN.md §0)

- Repo: **public**, marked as a **template**.
- First deploy target: **Cloud Run** (serverless container). Listen on `$PORT`; build linux/amd64.
- Kubernetes: **optional / portability-only** — manifests kept, not deployed.
- Registry: **GHCR**. Manifests: **Kustomize**. Image: Debian build stages, **Alpine runner**.
- Security tooling may use free GHAS features (CodeQL, secret scanning, dependency review) now that the repo is public.

## Tooling available

- `gh` (GitHub CLI) authenticated as `Mxvlasic` (installed at `~/.local/bin/gh`).
