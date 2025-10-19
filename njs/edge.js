/// <reference path="../node_modules/njs-types/ngx_http_js_module.d.ts" />

// njs helpers for signing, bucketing, access gate, and feature flags

// lightweight base64url
function b64url(input) {
  return Buffer.from(input).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// FNV-1a hashing for consistent bucketing (no crypto dependency)
function fnv1a(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) >>> 0;
  }
  return h >>> 0;
}

// sign_req: HMAC-SHA256 of method+uri+msec, base64url
/**
 * 
 * @param {NginxHTTPRequest} r 
 * @returns 
 */
function sign_req(r) {
  const secret = (ngx.env.HMAC_SECRET || 'dev-secret');
  const msg = r.variables.request_method + "\n" + r.uri + "\n" + r.variables.msec;
  // try crypto hmac; fallback to dummy signature
  try {
    const crypto = require('crypto');
    const h = crypto.createHmac('sha256', secret).update(msg).digest('base64');
    return h.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  } catch (e) {
    // fallback: not secure, demo only
    return 'demo-' + b64url(msg + '|' + secret);
  }
}

// bucket_by_cookie: 5% canary based on user cookie or remote addr
function bucket_by_cookie(r) {
  const ck = r.headersIn['Cookie'] || '';
  const m = ck.match(/(?:^|;\s*)user=([^;]+)/);
  const key = m ? m[1] : r.variables.remote_addr;
  const pct = fnv1a(key) % 100;
  return (pct < 5) ? 'canary' : 'stable';
}

// feature flag snapshot var (string '0'/'1') for access_log/metrics
function ff_snapshot(r) {
  const percent = parseInt(ngx.env.FF_PERCENT || '0', 10);
  const ck = r.headersIn['Cookie'] || '';
  const m = ck.match(/(?:^|;\s*)user=([^;]+)/);
  const key = m ? m[1] : r.variables.remote_addr;
  const pct = fnv1a(key) % 100;
  return (pct < percent) ? '1' : '0';
}

// internal feature flag logic endpoint: returns 'on' or 'off'
function flags_logic(r) {
  const percent = parseInt(ngx.env.FF_PERCENT || '50', 10); // default 50% for demo
  const ck = r.headersIn['Cookie'] || '';
  const m = ck.match(/(?:^|;\s*)user=([^;]+)/);
  const key = m ? m[1] : r.variables.remote_addr;
  const pct = fnv1a(key) % 100;
  const on = (pct < percent);
  r.return(200, on ? 'on' : 'off');
}

// access gate: require x-api-key & route based on flags
function gate(r) {
  if (!r.headersIn['x-api-key']) {
    return r.return(401, 'missing x-api-key');
  }
  r.subrequest('/_int/flags', { method: 'GET' }, (res) => {
    if (res.status !== 200) return r.return(503, 'flag svc error');
    const on = /on/.test(res.responseText);
    if (on) {
      return r.internalRedirect('/v2/hello');
    } else {
      return r.internalRedirect('/v1/hello');
    }
  });
}

export default { sign_req, bucket_by_cookie, ff_snapshot, flags_logic, gate };
