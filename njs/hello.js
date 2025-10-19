/// <reference path="../node_modules/njs-types/ngx_http_js_module.d.ts" />

/**
 * 
 * @param {NginxHTTPRequest} r 
 */
function hello(r) {
    r.headersOut['Content-Type'] = 'text/plain';
    r.return(200, "Hello world!\n");
}

export default { hello }