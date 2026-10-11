# ---- deps: install dependencies (cached unless lockfile changes) ----
FROM node:24-bookworm-slim AS deps
WORKDIR /app

ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN corepack enable && corepack prepare pnpm@10.0.0 --activate

COPY package.json pnpm-lock.yaml ./
# postinstall runs patch-package; --frozen-lockfile keeps CI reproducible
RUN pnpm install --frozen-lockfile

# ---- build: compile the Next.js app ----
FROM node:24-bookworm-slim AS build
WORKDIR /app

ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN corepack enable && corepack prepare pnpm@10.0.0 --activate

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# If you add NEXT_PUBLIC_* variables, bake them here, e.g.:
#   ARG NEXT_PUBLIC_SITE_URL
#   ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
# and pass them with: docker build --build-arg NEXT_PUBLIC_SITE_URL=... .

ENV NEXT_TELEMETRY_DISABLED=1
# Guarantee ./public exists so the runner-stage COPY never fails on clones
# without a public/ directory.
RUN mkdir -p public && pnpm build

# ---- runner: minimal production image, non-root ----
# Alpine keeps the final image small. The build stage (Debian) already compiled
# everything; pnpm ships both glibc and musl optional binaries (sharp, swc),
# so the traced standalone output runs on musl too.
FROM node:24-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=8080 \
    HOSTNAME="0.0.0.0"

RUN addgroup -S -g 1001 nodejs \
  && adduser -S -u 1001 -G nodejs nextjs

# Standalone server + static assets. --chown so the non-root user can read them.
COPY --from=build --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=build --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=build --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 8080

# Cloud Run injects $PORT; default 8080 matches ENV above.
# Uses node (already present) so no curl/wget layer is needed.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:'+(process.env.PORT||'8080')+'/api/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
