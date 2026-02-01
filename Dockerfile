# ================================
# Base
# ================================
FROM node:22-alpine AS base
RUN apk add --no-cache libc6-compat python3 make g++

# ================================
# Dependencies
# ================================
FROM base AS deps
WORKDIR /app

RUN npm install -g pnpm@10.6.1

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/backend/package.json apps/backend/
COPY apps/orchestrator/package.json apps/orchestrator/
COPY libraries/ libraries/

# Disable lifecycle scripts (Prisma later)
RUN pnpm install --no-frozen-lockfile --ignore-scripts

# ================================
# Build
# ================================
FROM base AS builder
WORKDIR /app

RUN npm install -g pnpm@10.6.1

COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Prisma AFTER files exist
RUN pnpm run prisma-generate

# Build backend + orchestrator only
RUN pnpm -r \
  --workspace-concurrency=1 \
  --filter ./apps/backend \
  --filter ./apps/orchestrator \
  run build

# ================================
# Runtime
# ================================
FROM node:22-alpine AS runner
RUN apk add --no-cache libc6-compat

WORKDIR /app

RUN addgroup -g 1001 -S nodejs && \
    adduser -S postiz -u 1001

COPY --from=builder --chown=postiz:nodejs /app /app

USER postiz

ENV NODE_ENV=production \
    ENABLE_ES=false \
    RUN_CRON=false \
    STORAGE_PROVIDER=local \
    NX_DAEMON=false

EXPOSE 5000
CMD ["pnpm", "start"]
