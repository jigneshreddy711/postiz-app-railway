# Ultra-optimized multi-stage build for Railway
FROM node:22-alpine AS base
RUN apk add --no-cache libc6-compat python3 make g++

# Dependencies stage
FROM base AS deps
WORKDIR /app
RUN npm install -g pnpm@10.6.1

# Copy only package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/backend/package.json ./apps/backend/
COPY apps/frontend/package.json ./apps/frontend/
COPY apps/orchestrator/package.json ./apps/orchestrator/
COPY libraries/*/package.json ./libraries/

# Install only production dependencies
RUN pnpm install --prod --frozen-lockfile

# Build stage
FROM base AS builder
WORKDIR /app
RUN npm install -g pnpm@10.6.1

# Copy all files
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Generate Prisma
RUN pnpm run prisma-generate

# Build with memory limit
RUN NODE_OPTIONS="--max-old-space-size=2048" pnpm -r --filter ./apps/backend --filter ./apps/frontend --filter ./apps/orchestrator run build

# Remove dev dependencies and clean up
RUN pnpm prune --prod && \
    rm -rf .nx .git apps/extension apps/sdk && \
    find . -name "*.test.ts" -delete && \
    find . -name "*.spec.ts" -delete && \
    find . -name "*.map" -delete

# Production stage - ultra minimal
FROM node:22-alpine AS runner
RUN apk add --no-cache libc6-compat
WORKDIR /app

RUN npm install -g pnpm@10.6.1 pm2 && \
    addgroup -g 1001 -S nodejs && \
    adduser -S postiz -u 1001

# Copy only what's needed
COPY --from=builder --chown=postiz:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=postiz:nodejs /app/apps/backend/dist ./apps/backend/dist
COPY --from=builder --chown=postiz:nodejs /app/apps/frontend/.next ./apps/frontend/.next
COPY --from=builder --chown=postiz:nodejs /app/apps/frontend/public ./apps/frontend/public
COPY --from=builder --chown=postiz:nodejs /app/apps/orchestrator/dist ./apps/orchestrator/dist
COPY --from=builder --chown=postiz:nodejs /app/apps/*/package.json ./apps/
COPY --from=builder --chown=postiz:nodejs /app/libraries ./libraries
COPY --from=builder --chown=postiz:nodejs /app/package.json ./package.json
COPY --from=builder --chown=postiz:nodejs /app/pnpm-workspace.yaml ./

USER postiz
ENV NODE_ENV=production

EXPOSE 3000 4200
CMD ["pnpm", "run", "pm2"]
