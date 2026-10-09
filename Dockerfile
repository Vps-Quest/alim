```dockerfile
# syntax=docker/dockerfile:1

# ─── Base ────────────────────────────────────────────────────────────────────
FROM node:20-bookworm-slim AS base

ENV NEXT_TELEMETRY_DISABLED=1

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ─── Dependencies ───────────────────────────────────────────────────────────
FROM base AS deps

COPY package.json package-lock.json* ./
COPY prisma ./prisma

RUN npm ci

# ─── Builder ─────────────────────────────────────────────────────────────────
FROM base AS builder

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# ─── Runner ──────────────────────────────────────────────────────────────────
FROM base AS runner

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN groupadd --system --gid 1001 nodejs \
    && useradd --system --uid 1001 --gid nodejs nextjs

# Next.js standalone application
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy the complete dependency tree for Prisma and the application
COPY --from=builder /app/node_modules ./node_modules

# Prisma schema and migrations
COPY --from=builder /app/prisma ./prisma

# Startup script
COPY --chmod=755 docker-entrypoint.sh ./docker-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["node", "server.js"]
```
