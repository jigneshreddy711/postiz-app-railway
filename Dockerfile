# # ================================
# # Base
# # ================================
# FROM node:22-alpine AS base
# RUN apk add --no-cache libc6-compat python3 make g++

# # ================================
# # Dependencies
# # ================================
# FROM base AS deps
# WORKDIR /app

# RUN npm install -g pnpm@10.6.1

# COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# COPY apps/backend/package.json apps/backend/
# COPY apps/orchestrator/package.json apps/orchestrator/
# COPY libraries/ libraries/

# # Disable lifecycle scripts (Prisma later)
# RUN pnpm install --no-frozen-lockfile --ignore-scripts

# # ================================
# # Build
# # ================================
# FROM base AS builder
# WORKDIR /app

# RUN npm install -g pnpm@10.6.1

# COPY . .
# COPY --from=deps /app/node_modules ./node_modules
# COPY --from=deps /app/apps/backend/node_modules ./apps/backend/node_modules
# COPY --from=deps /app/libraries ./libraries

# # Prisma AFTER files exist
# RUN pnpm run prisma-generate

# # Build backend + orchestrator only
# RUN pnpm -r \
#   --workspace-concurrency=1 \
#   --filter ./apps/backend \
#   --filter ./apps/orchestrator \
#   run build

# # ================================
# # Runtime
# # ================================
# FROM node:22-alpine AS runner
# RUN apk add --no-cache libc6-compat

# RUN npm install -g pnpm@10.6.1

# WORKDIR /app

# RUN addgroup -g 1001 -S nodejs && \
#     adduser -S postiz -u 1001

# COPY --from=builder --chown=postiz:nodejs /app /app

# USER postiz

# ENV NODE_ENV=production \
#     ENABLE_ES=false \
#     RUN_CRON=false \
#     STORAGE_PROVIDER=local \
#     NX_DAEMON=false

# EXPOSE 5000
# CMD ["pnpm", "start"]





# ================================
# Base
# ================================
FROM node:22-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

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
RUN pnpm install --no-frozen-lockfile  # Remove --ignore-scripts unless Prisma needs it

# ================================
# Build
# ================================
FROM base AS builder
WORKDIR /app
RUN npm install -g pnpm@10.6.1
COPY . .
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/backend/node_modules ./apps/backend/node_modules
COPY --from=deps /app/libraries ./libraries

RUN pnpm run prisma-generate

# Build only what Railway needs
RUN pnpm -r \
  --workspace-concurrency=1 \
  --filter ./apps/backend \
  --filter ./apps/orchestrator \
  run build

# ================================
# Runtime
# ================================
FROM node:22-slim AS runner
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN npm install -g pnpm@10.6.1

RUN addgroup --gid 1001 nodejs && \
    adduser --system --uid 1001 --ingroup nodejs postiz

COPY --from=builder --chown=postiz:nodejs /app /app

USER postiz

ENV NODE_ENV=production \
    ENABLE_ES=false \
    RUN_CRON=false \
    STORAGE_PROVIDER=local \
    NX_DAEMON=false

EXPOSE 5000

CMD ["pnpm", "start"]