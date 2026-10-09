# Deklo tenant-ready Paperclip image (v2 slim: kaniko OOM fix).
# Build 54 OOMKilled snapshotting chromium + unpinned CLIs. Browser/CLI provisioning
# moves to runtime init; image holds node + paperclipai only.
FROM node:24-slim

ENV NODE_ENV=production \
    PORT=3100 \
    HOST=0.0.0.0

# Minimal apt set (no chromium libs — browser provisions at runtime, see README).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
  && rm -rf /var/lib/apt/lists/*

# Paperclip CLI — pinned reference version.
RUN npm install -g paperclipai@2026.1005.0

# Non-root runtime user.
RUN useradd --system --create-home --shell /bin/bash --home-dir /home/paperclip paperclip \
  && mkdir -p /app /home/paperclip/.paperclip \
  && chown -R paperclip:paperclip /app /home/paperclip/.paperclip

WORKDIR /app
USER paperclip

EXPOSE 3100

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD sh -c 'curl -fsS http://localhost:${PORT:-3100}/api/health || exit 1'

CMD ["paperclipai", "run"]
