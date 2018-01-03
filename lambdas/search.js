var util = require('./util.js');
var AWS = require('aws-sdk');
var accepts = require('accepts');
var Handlebars = require('handlebars');

AWS.config.update({region: process.env['AWS_REGION']});
var DDB= new AWS.DynamoDB();

var findHost = function(host) {
    return new Promise((resolve, reject) => {
        let tx = {
            "TableName": util.HOSTS_TABLE,
            "Key": {"host": {S: host}}
        };
        DDB.getItem(tx, (error, data) => {
            if (error) reject(error)
            else resolve(util.ddbToJs(data.Item));
        });
    });
}

var findClass = function(q) {
    return new Promise((resolve, reject) => {
        let tx = {
            "TableName": util.CLASSES_TABLE,
            "KeyConditions": {
                "name": {
                    "ComparisonOperator": "EQ",
                    "AttributeValueList": [{S: q}]
                }
            }};
        DDB.query(tx, (error, data) => {
            if (error) reject(error)
            else resolve(data["Items"].map(item => item.host.S));
        });
    });
}

// Convert a class name to a relative URL in a standard Javadoc layout
var classToURL = function(className) {
    return className
        .replace(/\./g, '/')
        .replace(/\$/g, '.') + ".html";
}

var addUrl = function(q, result) {
    result.url = result.host + "/" + classToURL(q);
    return result;
}

exports.search = function(q) {
    return findClass(q)
        .then(classes => {
            var classPromises = classes.map(c => findHost(c))
            return Promise.all(classPromises);})
        .then(results => {
            return results.map(result => addUrl(q, result));
        })
}

exports.respond_html = function(callback, ctx) {

    if(ctx.results && ctx.results.length == 0) {
        ctx.results = null;
    }

    console.log("ctx", ctx);

    callback(null, {
        statusCode: '200',
        body: Handlebars.templates['results.html'].call(null, ctx),
        headers: {
            'Content-Type': 'text/html'
        }});
}

var respond_json = function(callback, results) {
    callback(null, {
        statusCode: '200',
        body: JSON.stringify(results),
        headers: {
            'Content-Type': 'application/json'
        }});
}


var respond = function(callback, event, results) {

    // different ideas of expected case ¯\_(ツ)_/¯
    var req = {headers: {accept: event.headers["Accept"] || event.headers["accept"]}};
    var accept = accepts(req);

    switch (accept.type(['json', 'html'])) {
    case 'json':
        respond_json(callback, results);
        break;
    case 'html':
        exports.respond_html(callback, {results: results,
                                        missing: event.queryStringParameters["q"],
                                        paths: {css: "css",
                                                add: "add",
                                                index: "index"}});
        break;
    default:
        respond_json(callback, results);
    }
}

exports.handler = function(event, context, callback) {

    var args = event.queryStringParameters;
    args = util.keep(args, "q", "version");

    util.checkRequiredArgs(args, "q")
        .then(() => exports.search(args.q))
        .then(results => respond(callback, event, results))
        .catch(e => {
            if (e.type) {
                callback(null, util.errorResponse(event, e));
            } else {
                console.log("Unexpected Error", e)
                callback(null, util.errorResponse(event,
                                                  util.err(500,
                                                           "InternalServerError",
                                                           "Internal Server Error",
                                                           {cause: e})));
            }
        });

}
