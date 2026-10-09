# Paperclip on Deklo — deploy runbook (dashboard + git push)

> Scope: author the tenant-ready repo so deploying is dashboard/API + `git push`.
> No deploys, no secrets, no network provisioning in this repo. Pinned: `paperclipai 2026.1005.0`, Node 24.
> Policy source: `/home/bhavya/EXAFLAIR-PAPERCLIP-PLAN.md` (VPS plan) + laptop instance policy for companies/workers/invites.

## 0. Prereqs

- This repo pushed to git (Deklo builds server-side via kaniko; never `docker build` locally).
- Deklo dashboard access + permission to create apps, set env, provision a CNPG database.
- Fresh secrets ready to generate (do NOT copy laptop values): `openssl rand -hex 32` × 3.

## 1. Create app from repo (dashboard)

1. Deklo dashboard → Create app → From repo → select this repo/branch.
2. Build: Dockerfile at repo root (kaniko, server-side). No custom build command.
3. Expected port: `3100` (Dockerfile `EXPOSE 3100`, `ENV PORT=3100 HOST=0.0.0.0`).
   Tenant platform sets its own `PORT` at runtime — app listens on `$PORT` (override contract, see Dockerfile `ENV` comment + `paperclip.env.example`).

## 2. Env (dashboard → app → env)

Copy keys from `paperclip.env.example` (placeholders only — no real values in repo):

- `PAPERCLIP_DEPLOYMENT_MODE=authenticated`
- `PAPERCLIP_DEPLOYMENT_EXPOSURE=public`
- `PAPERCLIP_AUTH_PUBLIC_BASE_URL=` → set to wildcard URL after first deploy (step 5), then redeploy.
  Bootstrapping order: first deploy with provisional/empty value only if platform allows; otherwise deploy once to learn the wildcard URL, set it, redeploy.
  Resolve naming conflicts with `paperclipai doctor` on 2026.1005.0 (`auth.publicBaseUrl is required` means the strict name won — plan §2).
- `PAPERCLIP_ALLOWED_HOSTNAMES=` → wildcard hostname (no scheme/port), comma-separated if more.
- Secrets trio (generate fresh, 3× `openssl rand -hex 32`, never reuse laptop):
  `PAPERCLIP_AGENT_JWT_SECRET`, `BETTER_AUTH_SECRET` (keep stable across restarts/URL changes), `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET`.
- Hardening: `PAPERCLIP_SECRETS_STRICT_MODE=true`, `PAPERCLIP_SECRETS_PROVIDER=local_encrypted`,
  `PAPERCLIP_SECRETS_MASTER_KEY_FILE=/home/paperclip/.paperclip/instances/default/secrets/master.key`,
  `PAPERCLIP_ENABLE_COMPANY_DELETION=false`.
- `HOST=0.0.0.0` (tenant; VPS plan used `127.0.0.1` behind Nginx — wrong here). `PORT=3100` default; platform override wins.
- Never set `PAPERCLIP_AUTH_DISABLE_SIGN_UP=true` — kills invite flow (plan §4).

## 3. CNPG database (dashboard → database)

1. Provision one CNPG Postgres (17 if offered) for this app; bind/link to app.
2. Set `DATABASE_URL` from the CNPG connection string (pooled `:6543` + `prepare:false` pattern per plan §5.8 if Supabase-style pooling applies; migrations on direct `:5432` if the operator exposes both — [needs-verify] on Deklo CNPG).
3. Keep embedded-PG + local-disk as fallback only if CNPG is unavailable; hosted PG is the first scale lever (plan §5.8).

## 4. Deploy

1. `git push` (or dashboard Redeploy) → kaniko builds `Dockerfile` server-side.
2. Watch build logs: `node:24-slim` base, `paperclipai@2026.1005.0` global install, opencode/claude CLI lines (marked `# verify` — confirm versions in log), `playwright install chromium`.
3. Expect listen on `$PORT`; `HEALTHCHECK` hits `/api/health`.

## 5. Always-on toggle + wildcard URL health

1. Dashboard → app → Always-on (or equivalent keep-warm) → ON. Paperclip heartbeats/routines assume the process stays up; scale-to-zero will stall timers and websocket presence.
2. Get the wildcard URL from the dashboard (pattern `https://<app>-<hash>.<wildcard>`).
3. Set `PAPERCLIP_AUTH_PUBLIC_BASE_URL` + `PAPERCLIP_ALLOWED_HOSTNAMES` to it (step 2), redeploy.
4. Health: `curl https://<wildcard>/api/health` → `{"status":"ok",…}` (same gate as VPS plan §3.7/§9).
5. Open `https://<wildcard>` → login screen expected.

## 6. Onboard (first owner)

Mirror VPS plan §3.8 against the wildcard URL:

1. `npx paperclipai onboard --yes` semantics apply on first boot (fresh `master.key` — back it up off-host immediately).
2. First owner: `paperclipai auth bootstrap-ceo` (prints invite URL) or `board-claim` (`/board-claim/<token>?code=<code>` → Claim ownership → instance admin + owner on every company).
3. Run `paperclipai doctor`, record warnings; resolve every `[needs-verify]` (plan §2 conflicts, `TRUST_PROXY`, heartbeat keys) with doctor as arbiter.

## 7. Companies / workers / invites (mirror laptop policy)

Source of truth: plan §4–§7 + laptop instance. Do NOT invent a new policy here:

1. **Company base:** import GStack as `Exaflair Eng` (`company import … --dry-run` then `--yes`, plan §6), merge Aeon research pack + MiniMax doc pack skills (`--target existing --include skills`, collision `rename`).
2. **Model policy:** default everything to `opencode-go/muse-spark-1.3-contributor` (economy); Claude Sonnet 5.5 only on CEO + orchestrator-equivalent; audit `agents.defaults.model` for dead routes (plan §7). Re-Test every worker + one smoke issue per worker.
3. **Budgets:** company + per-agent `budgetMonthlyCents` (CEO $30–50, manager $20–40, worker $10–25), `warnPercent:80`, `hardStopEnabled:true`; prove with $0.50 test cap first (plan §5.7).
4. **Routines over heartbeats:** timer heartbeats OFF by default, wake-on-demand ON; scheduled work as Routines (`coalesce_if_active`, `skip_missed`, Asia/Kolkata cron where relevant); nightly export Routine (CEO-safe) + PG backups (plan §5.1/§5.2/§5.8).
5. **Invites:** Settings → Members → Invites → role default Operator → private link → signup → `joins:approve` → adjust role (Viewer/Operator/Admin/Owner semantics, single-use 72h links, `disableSignUp=false`, plan §4). CLI: `invite create / join list / join approve / member list / invite revoke <id>`.
6. **Secrets:** per-teammate scopes (Company vs Each user, fail-closed), `STRICT_MODE=true`, humans fill Company Settings → Secrets → My secrets (plan §5.5).

## Quota caveat

- Max class observed: **2 CPU / 1 Gi**. If the tenant enforces that ceiling, Paperclip + co-located runners + chromium + embedded PG will contend (plan §8 sizing honesty: only documented anchor is 1 vCPU/2 GB to start; per-user sizing NOT documented).
- If throttled/OOM: request a class bump before promising headroom; meanwhile apply first scale levers: hosted PG (§3 above), S3 file offload (below), split runner pool, keep timer heartbeats OFF.
- Load checkpoint at ~5 concurrent teammates (heartbeat contention + PG latency) before declaring headroom (plan §8).

## No-PVC note (files)

- No PersistentVolumeClaims in tenant. Local disk (`local_disk` storage, `master.key`, uploads, `<instance>/companies/<companyId>/agents/<agentId>/instructions/`) is ephemeral.
- Persist via S3/Garage: set `PAPERCLIP_STORAGE_PROVIDER=s3` + `_S3_BUCKET/_REGION/_PREFIX/_ENDPOINT` (keys in `paperclip.env.example`, commented until needed); agent files stay local per plan §5.8 — back up `master.key` + nightly company exports off-host regardless.
- Treat every redeploy/reschedule as wiping local disk; restore path is nightly export → `company import` into scratch/new company (plan §5.8), not a volume reattach.

## Rollback

- Traffic split to prior revision (dashboard → Revisions/Deployments → route 100% to previous healthy revision). `paperclipai update --rollback` flips code only, NOT the DB — if a migration ran, restore the pre-update DB backup (plan §8).
- Team rule: announce in-channel, freeze Routines during the window (`skip_if_active` already coalesces), keep the prior nightly export until green; verify `doctor` + `/api/health` + one worker Test before closing.

## Open risks / [needs-verify] (resolve with doctor on 2026.1005.0)

- opencode/claude CLI install lines + playwright browser pin (marked `# verify` in Dockerfile).
- `DATABASE_URL` pooling/migration split on Deklo CNPG; `DATABASE_MIGRATION_URL` separate DDL role.
- `PAPERCLIP_AUTH_PUBLIC_BASE_URL` vs `PAPERCLIP_PUBLIC_URL` + `AUTH_BASE_URL_MODE`; `BETTER_AUTH_URL` vs `BETTER_AUTH_BASE_URL`.
- Heartbeat scheduler exact key names; `TRUST_PROXY` value behind tenant proxy.
- Wildcard-URL bootstrapping (base URL needed before first healthy boot).
