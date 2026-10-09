# Deklo tenant Paperclip (v3: prebuilt base — kaniko OOM fix).
# Builds 54/55 OOMKilled snapshotting npm-installed paperclipai (384 pkgs).
# Use Paperclip's own production image; this layer only sets tenant contract.
FROM ghcr.io/paperclipai/paperclip:2026.1005.0

# PORT OVERRIDE CONTRACT: tenant platform sets its own PORT at runtime.
ENV PORT=3100 \
    HOST=0.0.0.0

EXPOSE 3100

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD sh -c 'curl -fsS http://localhost:${PORT:-3100}/api/health || exit 1'
