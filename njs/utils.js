/// <reference path="../node_modules/njs-types/ngx_http_js_module.d.ts" />

/**
 * 
 * @param {NginxHTTPRequest} r 
 */
function version(r) {
    r.headersOut['Content-Type'] = 'text/plain';
    r.return(200, njs.version);
}

export default { version }