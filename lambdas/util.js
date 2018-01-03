var Handlebars = require('handlebars');
var fs = require('fs')
var accepts = require('accepts');

// Common code used by multiple lambdas
exports.JSON_CONTENT_TYPE = {'Content-Type': 'application/json'};
exports.CLASSES_TABLE = process.env['CLASSES_TABLE'];
exports.HOSTS_TABLE = process.env['HOSTS_TABLE'];

// Load templates
eval(fs.readFileSync(require.resolve('./templates/results.js'), 'utf-8'));
eval(fs.readFileSync(require.resolve('./templates/added.js'), 'utf-8'));
eval(fs.readFileSync(require.resolve('./templates/error.js'), 'utf-8'));
eval(fs.readFileSync(require.resolve('./templates/partial/head.js'), 'utf-8'));
eval(fs.readFileSync(require.resolve('./templates/partial/footer.js'), 'utf-8'));
Handlebars.partials["partial/head"] = Handlebars.templates['head.html'];
Handlebars.partials["partial/footer"] = Handlebars.templates['footer.html'];

exports.err = function(statusCode, type, error_html, details) {
    return { statusCode: statusCode.toString(),
             error_html: error_html,
             type: type,
             details: details };
}

exports.checkRequiredArgs = function(args, ...keys) {
    return new Promise((resolve, reject) => {
        for (i in keys) {
            let key = keys[i];
            if(!args.hasOwnProperty(key)) {
                reject(exports.err(400, "MissingRequiredField", {field: key}));
                return;
            }
        }
        resolve();
    });
}

exports.keep = function(obj, ...keys) {
    var ret = {};
    for(i in keys) {
        let key = keys[i];
        if(obj[key]) {
            ret[key] = obj[key];
        }
    }
    return ret;
}

var json_err = function(err) {
    var body = { type: err.type,
                 details: err.details };
    return { statusCode: err.statusCode.toString(),
             headers: exports.JSON_CONTENT_TYPE,
             body: JSON.stringify(body)};
}

var html_err = function(err) {

    var ctx = {
        error_html: err.error_html,
        paths: {css: "css",
                add: "add",
                index: "index"}
    };

    var resp = {
        statusCode: err.statusCode.toString(),
        body: Handlebars.templates['error.html'].call(null, ctx),
        headers: {
            'Content-Type': 'text/html'
        }};


    return resp;
    }

exports.errorResponse = function(event, err) {

    // different ideas of expected case ¯\_(ツ)_/¯
    var req = {headers: {accept: event.headers["Accept"] || event.headers["accept"]}};
    var accept = accepts(req);

    switch (accept.type(['json', 'html'])) {
    case 'json':
        return json_err(err);
        break;
    case 'html':
        return html_err(err);
        break;
    default:
        return json_err(err);
    }
}

// Convert a DynamoDB-shaped item to a JavaScript-shaped item
exports.ddbToJs = function ddbToJs(obj) {
    if (Array.isArray(obj)) return obj.map(v => ddbToJs(v));
    if (!('object' == typeof obj)) return obj;

    let keys = Object.keys(obj);
    if (keys.length == 1) {
        if (keys[0] == 'S') return obj[keys[0]];
        if (keys[0] == 'N') return Number.parseFloat(obj[keys[0]]);
    }

    var ret = {};
    for(k in obj) {
        ret[k] = ddbToJs(obj[k]);
    }
    return ret;
}
