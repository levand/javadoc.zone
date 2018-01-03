var request = require('request');
var cheerio = require('cheerio');
var AWS = require('aws-sdk');
var util = require('./util.js');
var accepts = require('accepts');
var queryString = require('querystring');
var Handlebars = require('handlebars');

AWS.config.update({region: process.env['AWS_REGION']});
var DDB= new AWS.DynamoDB();

// Convert a href relative URL to it's corresponding class name
let hrefToClass = function(href) {
    return href
        .replace(/\./g, '$')
        .replace(/\//g, '.')
        .replace(/\$html$/, "");
}

// Given the HTML str of an /allclasses-frame.html page, return an array of Java class names.
let parseClasses = function(html) {
    var $ = cheerio.load(html);

    var result = [];

    $('a').each((i, el) => {
        var href = $(el).attr('href');
         result.push(hrefToClass(href));
    });

    return result;
}

var unreachable_documentation_error = function(url, error) {
    return new Handlebars.SafeString(`Could not reach the specified Javadoc URL, <code>${url}</code>. The response was: <pre>${error}</pre><div>Depending on the error type, you may wish to try a differnt Javadoc URL, or try again later. If you believe this to be an error on the parsing code, please file an issue on the <a href="http://github.com/levand/javadoc.zone">Github repository</a>.</div>`);
}


// Given a Javadoc root URL, resolve the page that lists all classes
// and return a Promise of an  array of covered class names.
let scrape = function(url) {
    return new Promise((resolve, reject) => {

        let indexUrl = url + "/allclasses-frame.html"

        request(indexUrl, (error, response, html) => {

            if (error || !(response.statusCode === 200)) {
                if (response) response.body = `<${response.body.length} characters>`;
                if (!response) response = "<no response>";
                reject(util.err(500, "UnreachableDocumentation",
                                unreachable_documentation_error(indexUrl, JSON.stringify(response, null, 2)),
                                {url: indexUrl,
                                 error: error,
                                 response: response}));
            } else {
                resolve(parseClasses(html))
            }
        });
    });
}

var already_registered_error = function(repo) {
    return new Handlebars.SafeString(`The Javadoc repository <code>${repo}</code> is already present in the database. All of the classes that it documents should already be present in search results. If this isn't true, or if something else seems to be wrong, please file an issue on the <a href="http://github.com/levand/javadoc.zone">Github repository</a>.`)
}

// Check that a host isn't already written, returning an empty promise on success
// empty promise on completion
let checkHost = function(host) {
    return new Promise((resolve, reject) => {
        let tx = {
            "TableName": util.HOSTS_TABLE,
            "Key": {"host": {S: host}}
        };
        DDB.getItem(tx, (error, data) => {
            if (error) reject(error)
            else if (data.Item) reject(util.err(409, "AlreadyRegistered",
                                                already_registered_error(host),
                                                {url: host}));
            else resolve();
        });
    });
}

// Write the host, along with the number of parsed classes, to the
// hosts table. This will *not* overwrite any other entry in the hosts
// table; it is theoretically possible for there to be a race
// condition between the checkHost and writeHost functions. In this
// case, data will remain valid, and the loser will get an
// unexplained 500 error. This is acceptable, given how improbable
// this is likely to be.
let writeHost = function(args, classCount) {
    return new Promise((resolve, reject) => {

        let tx = {"TableName": util.HOSTS_TABLE,
                  "ConditionExpression": "attribute_not_exists(host)",
                  "Item": {"classCount": {N: classCount.toString()}}};

        for (key in args) {
            tx["Item"][key] = {S: args[key]};
        }

        DDB.putItem(tx, (err, data) => {
            if (err) reject(err);
            else resolve(classCount);
        });

    });
}

// Persist a single class entry to the Classes table, returning an
// empty promise on completion
let persistClass = function(className, host) {
    return new Promise((resolve, reject) => {
        let tx = {
            "TableName": util.CLASSES_TABLE,
            "Item": {
                "name": {S: className},
                "host": {S: host}
            }};
        DDB.putItem(tx, (err, data) => {
            if (err) reject(err);
            else resolve();
        });
    });
}

// Given an array of classnames and a host, persist them all and
// return a single promise.
let persistClasses = function(classes, host) {
    return Promise.all(classes.map(className => persistClass(className, host)));
}

let respond_json = function(callback, numClasses) {
    callback(null, {statusCode: '200',
                    body: JSON.stringify({classes: numClasses}),
                    headers: util.JSON_CONTENT_TYPE})
}

let respond_html = function(callback, ctx) {

    callback(null, {
        statusCode: '200',
        body: Handlebars.templates['added.html'].call(null, ctx),
        headers: {
            'Content-Type': 'text/html'
        }});
}

let respond = function(callback, event, numClasses) {

    // different ideas of expected case ¯\_(ツ)_/¯
    var req = {headers: {accept: event.headers["Accept"] || event.headers["accept"]}};
    var accept = accepts(req);

    switch (accept.type(['json', 'html'])) {
    case 'json':
        respond_json(callback, numClasses);
        break;
    case 'html':
        respond_html(callback, {classes: numClasses,
                                paths: {css: "css",
                                        add: "add",
                                        index: "index"}});
        break;
    default:
        respond_json(callback, numClasses);
    }
}

exports.handler = function(event, context, callback) {

    var args = null;
    if(event.headers['content-type'] == 'application/json' ||
       event.headers['Content-Type'] == 'application/json') {
        args = JSON.parse(event.body);
    } else {
        args = queryString.parse(event.body);
    }

    args = util.keep(args, "host", "version", "artifact");

    args.host = args.host.trim();
    args.host = args.host.replace("/index.html", "");
    args.host = args.host.replace(/[\/\\]+$/, "");
    args.host = args.host.replace(/\?.*$/, "");

    util.checkRequiredArgs(args, "host")
        .then(() => checkHost(args.host))
        .then(() => scrape(args.host))
        .then(classes => persistClasses(classes, args.host))
        .then(persisted => writeHost(args, persisted.length))
        .then(numClasses => respond(callback, event, numClasses))
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
            }});
}
