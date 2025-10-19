# nginx-njs-kit

Minimal Dockerized NGINX + njs playground with **4 production-ish use cases**:

1) **HMAC request signing** (`/sign`) – issues `X-Sign` based on method+uri+msec using env `HMAC_SECRET`.
2) **Access gate + canary/feature flag routing** (`/api/hello`) – requires `x-api-key`, calls `/_int/flags` and internally redirects to `/v1/hello` or `/v2/hello`. Control population with env `FF_PERCENT` (0-100). Sticky per `Cookie: user=...`.
3) **Response redaction** (`/report-filtered`) – masks long digit sequences from `/report` using an njs body filter.
4) **Computed variables** – `js_set` populates `$hmac`, `$bucket`, `$ff` for logs/headers.

> This is **not** Node.js; njs is a tiny embeddable JS engine for request-time glue logic. Keep logic fast (<1ms).

## Quickstart

```bash
docker build -t nginx-njs-kit .
docker run --name nginx-njs-kit --restart=unless-stopped -d   -e HMAC_SECRET=change-me   -e FF_PERCENT=50   -p 8080:8080 nginx-njs-kit

# smoke
curl http://localhost:8080/
```

## Endpoints

- `GET /sign` → 204 + headers `X-Time`, `X-Sign`
- `GET /api/hello` (needs `x-api-key`) → internally serves `/v1/hello` or `/v2/hello`
  - add `Cookie: user=alice` to get consistent bucketing
  - tune `FF_PERCENT` to control v2 exposure
- `GET /report` → raw JSON with PII-ish digits
- `GET /report-filtered` → redacted JSON via njs header/body filters

## Dev scripts

```bash
make build
make start
make stop
make logs
make reload
make ssl
make ssh
```

Windows PowerShell test:

```powershell
.\scripts\test.ps1 -HostName localhost
```

## Notes

- The HMAC uses Node-like `crypto` if the distro's njs module provides it; otherwise it falls back to a demo base64url (do not use in prod). On Debian/Ubuntu `libnginx-mod-http-njs` typically includes crypto.
- All demos are same-process (no real upstream). In a real reverse-proxy, replace internal redirects with `proxy_pass` and forward headers (e.g., `proxy_set_header X-Sign $hmac;`).
- Body filtering deletes `Content-Length` to force chunked encoding, as required when body size changes.
