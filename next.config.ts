import withBundleAnalyzer from "@next/bundle-analyzer"
import { type NextConfig } from "next"

import { env } from "./env.mjs"

const config: NextConfig = {
  reactStrictMode: true,
  // Required for the Docker image: emits a self-contained
  // `.next/standalone` server (see Dockerfile).
  output: "standalone",
  // Drop the glibc platform duplicates from the traced output. The runner
  // stage is Alpine/musl and pnpm ships both variants; the musl copies stay.
  // Saves ~45 MB in the final image.
  outputFileTracingExcludes: {
    "*": [
      "./node_modules/.pnpm/@swc+core-linux-x64-gnu@*/**",
      "./node_modules/.pnpm/@img+sharp-linux-x64@*/**",
      "./node_modules/.pnpm/@img+sharp-libvips-linux-x64@*/**",
    ],
  },
  logging: {
    fetches: {
      fullUrl: true,
    },
  },
  rewrites: async () => [
    { source: "/healthz", destination: "/api/health" },
    { source: "/api/healthz", destination: "/api/health" },
    { source: "/health", destination: "/api/health" },
    { source: "/ping", destination: "/api/health" },
  ],
}

export default env.ANALYZE ? withBundleAnalyzer({ enabled: env.ANALYZE })(config) : config
