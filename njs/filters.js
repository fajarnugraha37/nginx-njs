// header/body filters for response manipulation

function json_hdr(r) {
  // ensure chunked by removing Content-Length
  delete r.headersOut['Content-Length'];
  // normalize content-type
  r.headersOut['Content-Type'] = 'application/json';
}

function redact_pii(r, data, flags) {
  if (!data) { if (flags.last) r.send(null); return; }
  // mask long digit sequences (cards/phones): keep first 4 and last 2
  const masked = data.toString()
    .replace(/\b(\d{4})(\d{6,})(\d{2})\b/g, '$1******$3')
    .replace(/(\+?\d{2})(\d{6,})(\d{2})\b/g, '$1******$3');
  r.send(masked);
  if (flags.last) r.done();
}

export default { json_hdr, redact_pii };
