# Deployment Options Assessment

For `next-enterprise-starter`: **where do we actually run this container?**

## 0. Decision (locked)

> **First deploy target: Cloud Run (serverless container).**
> Runs the exact Docker image, scales to ~$0 idle, gives a real HTTPS URL quickly.
>
> **Kubernetes: deferred / optional.** Manifests are kept in the template for portability, but Kubernetes is **not** the deployment target for this app. The reasoning below (k3s = max learning; managed K8s = less ops) stays on record for a future phase if a use case demands it.
>
> **Repo is public**, which unlocks free CodeQL / secret scanning / dependency review / unlimited Actions minutes.

## 1. Requirements & constraints

- **Workload:** Next.js 15 SSR app (Node server, not just static) in a Docker image.
- **Cost:** low — this is a prove-it-out / learning project, not a funded product yet.
- **Learning value:** want real container/Kubernetes experience.
- **Portability:** no lock-in; must be re-hostable for future internal or client work.
- **Ops appetite:** solo (product-manager-turned-builder), so operational burden matters.
- **No cluster today:** nothing is set up yet.
- **Real results:** must actually be reachable on the internet with TLS.

---

## 2. Options compared

| Option | What it is | Idle cost | K8s learning | Ops burden | Next.js fit | Lock-in |
|---|---|---|---|---|---|---|
| **A. Vercel / Next.js PaaS** | Native Next.js hosting | ~$0–20/mo | ❌ none | None | ★★★★★ | High |
| **B. Serverless containers** (Cloud Run, App Runner, Azure Container Apps) | Run the Docker image, scale-to-zero | ~$0 idle | ⚠️ low (containers, no K8s API) | Low | ★★★★ | Medium |
| **C. Managed Kubernetes** (DOKS, LKE, GKE Autopilot, EKS, AKS) | Provider-run control plane; you run workloads | DOKS/LKE: ~$0 + node; **EKS: ~$73/mo control plane** | ★★★★★ | Medium | ★★★★ | Medium |
| **D. Self-managed k3s on a cheap VPS** (Hetzner, DigitalOcean, Linode) | Single-node lightweight K8s on a ~$5–8/mo box | ~$5–8/mo | ★★★★★ | Med-High (patches, backups) | ★★★★ | Low |
| **E. Local only** (kind/k3d) | Cluster on your machine | $0 | ★★★ (no real networking/TLS) | Low | ★★★ | None |

*E is a stepping stone, not a destination.*

---

## 3. Analysis for this use case

- **Vercel (A)** is the fastest path to a Next.js app and is genuinely cheap to start, but it **bypasses the entire container/K8s learning goal** and is the wrong shape if the long-term aim is portable, containerized client work. Keep it as a fallback for a client who just wants hosting.
- **Serverless containers (B)** are the best "cheap + real + low-ops" option if you drop the K8s requirement: Cloud Run scales to zero (~$0 idle) and runs your exact image. Great production default, modest learning.
- **Managed K8s (C)** is the real thing with the least cluster-plumbing. **DOKS and LKE have free/no-cost control planes**, so you pay only for a small node (~$6–12/mo). **Avoid EKS for learning — the ~$73/mo control plane is pure overhead.**
- **k3s on a VPS (D)** is the **cheapest route to a real cluster** and the **highest learning value**: you own ingress, TLS (cert-manager), storage, and upgrades. Cost ≈ a coffee a month. The cost is operational — you patch and back it up yourself.

---

## 4. Recommendation

**Use the Docker image as the single portable artifact, and take a staged approach:**

```
Artifact:  Docker image  ──►  GHCR (registry)
                                 │
Phase 0  Local parity        docker compose  +  kind/k3s on your machine
Phase 1  Real, cheap, high-learning   k3s on a single Hetzner/DO VPS  (~$5–8/mo)
Phase 2  Scale / less ops (optional)  managed K8s — DOKS or LKE (free control plane)
Phase 3  No-K8s fallback              Cloud Run (scale-to-zero) or Vercel
```

**Start with Phase 1 (k3s on a cheap VPS)** because it uniquely satisfies *all* constraints at once: real Kubernetes, real ingress + TLS, lowest sustainable cost, maximum learning, zero lock-in. Everything learned transfers directly to managed K8s and to client environments.

**Keep the manifests provider-neutral** (Kustomize, `ClusterIP` service, cert-manager) so moving from k3s → DOKS/LKE → a client's cluster is a kubeconfig change, not a rewrite.

### Why not just start managed (C)?
Free control planes (DOKS/LKE) make it tempting, but a **single-node k3s teaches the moving parts** (ingress controller, cert-manager, storage class, NetworkPolicy) that managed clusters hide — and that knowledge is exactly what makes the eventual freelancing/consulting angle valuable. Add managed K8s only when ops burden or scale justifies it.

### Concrete Phase-1 stack (proposed)
- **VPS:** Hetzner CX22 (2 vCPU / 4 GB, ~€4–5/mo) or DigitalOcean 2 GB ($12/mo).
- **Cluster:** k3s (single node to start).
- **Ingress:** Traefik (bundled with k3s) or ingress-nginx.
- **TLS:** cert-manager + Let's Encrypt.
- **Registry:** GitHub Container Registry (GHCR) — free for private images, tight GitHub Actions integration.
- **CD:** GitHub Actions builds → pushes to GHCR → applies Kustomize overlay. (Argo CD later if we want GitOps.)

---

## 5. Decision checklist (when you're ready to pick)

1. Is Kubernetes a **hard requirement** or just desirable?
   - Hard yes → **k3s on a VPS** (Phase 1).
   - Nice-to-have → **Cloud Run** (Phase 3) is cheaper and less work.
2. Budget ceiling per month? (`<$10` → k3s/VPS or Cloud Run; `<$30` → DOKS/LKE.)
3. Willing to patch/back up a server yourself? (No → managed cluster.)
4. Domain name available for ingress + TLS? (Needed for a "real result".)
