# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Yes    |

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Email: security@playify.app

Include: description, reproduction steps, potential impact. We aim to respond within 48 hours.

## Security practices

- Secrets are compiled in via `--dart-define` (never bundled as assets)
- Auth tokens stored in `flutter_secure_storage` (Keystore / Secure Enclave)
- Supabase Row Level Security (RLS) enforced on all tables
- PKCE auth flow used for Supabase OAuth
- Logger silenced in release builds (`Logger.level = Level.off`)
- `.env` files are gitignored and never committed
