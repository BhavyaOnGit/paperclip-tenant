# Deklo tenant-ready Paperclip image.
# Pinned: paperclipai 2026.1005.0, Node 24 (per /home/bhavya/EXAFLAIR-PAPERCLIP-PLAN.md).
# Tenant builds server-side via kaniko — do NOT `docker build` locally per task.
FROM node:24-slim

# PORT OVERRIDE CONTRACT: tenant platform sets its own PORT at runtime.
# App MUST listen on $PORT (never hardcode 3100 in code/CMD).
# HOST must be 0.0.0.0 in tenant (VPS plan used 127.0.0.1 behind Nginx — NOT valid here).
ENV NODE_ENV=production \
    PORT=3100 \
    HOST=0.0.0.0

# Minimal apt set: base tools + chromium/playwright system deps.
# Playwright's canonical `install-deps chromium` set, trimmed for node:24-slim (Debian bookworm).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    libexpat1 \
    libx11-6 \
    libxcb1 \
    fonts-liberation \
  && rm -rf /var/lib/apt/lists/*

# Paperclip CLI — pinned reference version.
RUN npm install -g paperclipai@2026.1005.0

# opencode CLI — exact install line uncertain, verify against current opencode docs.
# Option A (npm): npm install -g opencode-ai  # verify: package name + version pin
# Option B (script): curl -fsSL https://opencode.ai/install | bash  # verify: URL + flags
RUN npm install -g opencode-ai # verify

# claude CLI — exact install line uncertain, verify against current Anthropic docs.
# Canonical guess: npm install -g @anthropic-ai/claude-code  # verify: package name + version pin
RUN npm install -g @anthropic-ai/claude-code # verify

# Playwright chromium browser (bundled, version follows installed playwright).
# If paperclip pins its own playwright version, prefer: npx -y playwright@<pinned> install chromium
# verify: whether paperclip bundles playwright or needs top-level install.
RUN npx -y playwright install chromium # verify: pin + --with-deps equivalence (deps already apt-installed above)

# Non-root runtime user.
RUN useradd --system --create-home --shell /bin/bash --home-dir /home/paperclip paperclip \
  && mkdir -p /app /home/paperclip/.paperclip \
  && chown -R paperclip:paperclip /app /home/paperclip/.paperclip

WORKDIR /app
USER paperclip

EXPOSE 3100

# Paperclip serves /api/health -> {"status":"ok",...}. Respect runtime $PORT.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD sh -c 'curl -fsS http://localhost:${PORT:-3100}/api/health || exit 1'

# Paperclip reads PORT/HOST from env; do not hardcode --port/--host here.
CMD ["paperclipai", "run"]
